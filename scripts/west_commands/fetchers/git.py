# Copyright 2025-2026 NXP
#
# SPDX-License-Identifier: Apache-2.0
#
# A git fetcher for the MCUXpresso SDK west blobs command. It retrieves files
# out of a git repository using whatever transport git itself resolves for the
# repo URL. This has no Zephyr equivalent; it exists so that blob delivery
# reuses the SAME internal/external redirection that 'west update' relies on.
#
# Why git instead of a raw HTTP GET:
#   The workspace setup (bifrost: init_env.py / 'west sdk_init') registers a
#   global 'includeif.gitdir:<topdir>/' that pulls in bifrost/.gitconfig, whose
#   'insteadOf' rules rewrite public github.com URLs to the internal,
#   authenticated ssh://git@bitbucket.sw.nxp.com remotes. Because git applies
#   those rules itself during clone/fetch, a blob fetched through git inherits:
#     - internal developers  -> repo URL rewritten to Bitbucket over ssh (auth);
#     - external users        -> repo URL stays on public github.com (anonymous).
#   No raw-file URL template, no Bitbucket project-key casing, no separate auth
#   handling is needed in this command - git does all of it.
#
# IMPORTANT: git only loads bifrost/.gitconfig for repositories whose gitdir is
# under <topdir>/ (that is what the includeif.gitdir condition matches). So the
# temporary clone MUST be created under west_command.topdir, otherwise the
# 'insteadOf' rewrite is not applied and internal fetches would try public
# github.com. We honor that here.
#
# Manifest fields consumed (with fetcher: git):
#   url        : the (public) git repository URL; git rewrites it via insteadOf.
#                A list enables fallback repositories (handled by blobs.py).
#   repo-path  : path of the wanted file INSIDE the repository.
#   revision   : branch, tag or commit to fetch (default: the remote HEAD).
#
# Performance note -- fetch_many (batched clone):
#   When multiple blobs share the same repo + revision, fetch_many() performs a
#   SINGLE partial clone (--filter=blob:none) and a SINGLE sparse-checkout that
#   lists all wanted paths at once. Git then downloads all blob objects in one
#   packfile round-trip instead of one round-trip per blob.
#
#   Measured gain (Bitbucket SSH, ControlMaster active):
#     Before (one clone per blob): ~0.9s/blob
#     After  (one clone per group): first-blob overhead amortised; subsequent
#             blobs cost only a file-copy (~0ms) -- total dominated by the
#             single packfile download.

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from fetchers.core import McuxBlobException, McuxBlobFetcher


class GitFetcher(McuxBlobFetcher):

    @classmethod
    def schemes(cls):
        return ['git']

    @staticmethod
    def _git(*args):
        '''Build a git argv with core.longpaths=true prepended.

        core.longpaths=true is a no-op on Linux/macOS and is the standard
        git-on-Windows remedy for MAX_PATH (260-char) failures. It must be
        injected at the command-line level (not via repo config) so that it is
        active even before the clone destination exists.
        '''
        return ['git', '-c', 'core.longpaths=true'] + list(args)

    def _run(self, west_command, argv, cwd=None, input=None):
        '''Run a git command, raising McuxBlobException on failure.

        input, if given, is a string piped to the process on stdin (e.g. for
        'git sparse-checkout set --stdin' which reads patterns from stdin to
        avoid hitting the Windows CreateProcess command-line length limit).
        '''
        west_command.dbg(f'GitFetcher: {" ".join(argv)} (cwd={cwd})')
        try:
            proc = subprocess.run(
                argv,
                cwd=cwd,
                input=input,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
                text=True,
            )
        except OSError as e:
            raise McuxBlobException(f'Failed to run {argv[0]}: {e}') from e
        if proc.returncode != 0:
            raise McuxBlobException(
                f'git command failed ({proc.returncode}): {" ".join(argv)}\n'
                f'{proc.stderr.strip()}'
            )
        return proc

    def _clone(self, west_command, repo, revision, dest):
        '''Shallow, file-less clone of repo into dest.

        Tries the cheapest form first (depth 1 + blob:none partial clone, with
        --branch when a revision is given) and progressively falls back to forms
        that more servers accept. Returns the revision that still needs an
        explicit checkout (a commit SHA), or None if the working ref is ready.
        '''
        base = self._git('clone', '--no-checkout', '--depth', '1')

        # 1. partial clone + branch/tag (cheapest; one named ref, no blobs yet).
        if revision:
            try:
                self._run(west_command,
                          base + ['--filter=blob:none', '--branch', revision,
                                  repo, str(dest)])
                return None
            except McuxBlobException as e:
                west_command.dbg(f'GitFetcher: branch partial clone failed: {e}')

        # 2. partial clone of the default ref (revision may be a SHA, or unset).
        try:
            self._run(west_command,
                      base + ['--filter=blob:none', repo, str(dest)])
            return revision
        except McuxBlobException as e:
            west_command.dbg(f'GitFetcher: default partial clone failed: {e}')

        # 3. plain shallow clone (server refused partial clone / blob:none).
        if revision:
            try:
                self._run(west_command,
                          self._git('clone', '--no-checkout', '--depth', '1',
                                    '--branch', revision, repo, str(dest)))
                return None
            except McuxBlobException as e:
                west_command.dbg(f'GitFetcher: branch shallow clone failed: {e}')

        self._run(west_command,
                  self._git('clone', '--no-checkout', repo, str(dest)))
        return revision

    def _checkout_paths(self, west_command, dest, revision, repo_paths):
        '''Sparse-checkout one or more repo_paths at revision inside dest.

        repo_paths is a list of paths relative to the repo root. All are set
        in one git sparse-checkout call so that the subsequent git checkout
        downloads all blob objects in a single packfile.
        '''
        # Pass paths via stdin rather than argv to avoid the Windows
        # CreateProcess command-line length limit (~32 KB). With 1000+ blobs
        # averaging ~100 chars each, the argv form exceeds the limit and
        # subprocess.run raises [WinError 206]. --stdin is supported by git
        # sparse-checkout since git 2.25 (released 2020-01-13).
        self._run(west_command,
                  self._git('sparse-checkout', 'set', '--no-cone', '--stdin'),
                  cwd=dest,
                  input='\n'.join(repo_paths) + '\n')

        if revision:
            try:
                self._run(west_command, self._git('checkout', revision), cwd=dest)
            except McuxBlobException:
                # revision may be a commit not reachable from the shallow tip;
                # fetch it explicitly then retry.
                self._run(west_command,
                          self._git('fetch', '--depth', '1', 'origin', revision),
                          cwd=dest)
                self._run(west_command, self._git('checkout', revision), cwd=dest)
        else:
            self._run(west_command, self._git('checkout'), cwd=dest)

    def _checkout_file(self, west_command, dest, revision, repo_path):
        '''Sparse-checkout only repo_path at revision inside dest (single-file path).'''
        self._checkout_paths(west_command, dest, revision, [repo_path])

    def _tmp_parent(self, west_command):
        topdir = Path(west_command.topdir)
        tmp_parent = topdir / '.west_blobs_tmp'
        tmp_parent.mkdir(parents=True, exist_ok=True)
        return tmp_parent

    def fetch(self, west_command, blob, path):
        repo = blob['url']
        repo_path = blob.get('repo-path')
        revision = blob.get('revision')
        if not repo_path:
            raise McuxBlobException(
                "git fetcher requires a 'repo-path' field (path of the file "
                "inside the repository)")

        # The temporary clone MUST live under topdir so that the workspace's
        # includeif.gitdir bifrost/.gitconfig (with the insteadOf rewrites) is
        # applied by git; see the module docstring.
        tmp_parent = self._tmp_parent(west_command)
        tmpdir = None
        try:
            tmpdir = Path(tempfile.mkdtemp(prefix='b-', dir=str(tmp_parent)))
            west_command.dbg(
                f'GitFetcher fetching {repo_path}@{revision or "HEAD"} '
                f'from {repo} into {tmpdir}')

            pending_rev = self._clone(west_command, repo, revision, tmpdir)
            self._checkout_file(west_command, tmpdir, pending_rev, repo_path)

            src = tmpdir / repo_path
            if not src.is_file():
                raise McuxBlobException(
                    f"'{repo_path}' not found in {repo} at "
                    f"{revision or 'HEAD'}")
            try:
                shutil.copy(src, path)
            except OSError as e:
                raise McuxBlobException(f'Failed to copy {src}: {e}') from e
        finally:
            if tmpdir is not None:
                shutil.rmtree(tmpdir, ignore_errors=True)
            # Remove the parent holder if it is now empty (best effort).
            try:
                os.rmdir(tmp_parent)
            except OSError:
                pass

    def fetch_many(self, west_command, blobs_and_paths):
        '''Fetch all blobs in blobs_and_paths with a single clone.

        All blobs_and_paths entries must share the same repo URL and revision
        (enforced by blobs.py before calling here). The batched strategy:
          1. One partial clone (--filter=blob:none, --depth 1).
          2. One sparse-checkout that sets ALL wanted repo-paths at once.
          3. One git checkout -- git downloads all blob objects in one packfile.
          4. Copy each file out to its dest_path.

        A per-blob failure (missing after checkout, or the individual-fetch
        fallback itself failing, or a copy error) does NOT abort the rest of
        the batch: each blob is handled in its own try/except inside the loop,
        and failures are collected and returned (see McuxBlobFetcher.fetch_many
        docstring) rather than raised, so blobs.py only retries the blobs that
        actually failed -- not every blob in the group.

        Raising out of this method is reserved for failures that invalidate
        the whole batch before any per-blob work happens (the shared clone or
        sparse-checkout itself failing); in that case nothing was fetched, so
        the caller falling back to the whole group is correct.
        '''
        if not blobs_and_paths:
            return []

        # All entries share the same url/revision by contract.
        first_blob = blobs_and_paths[0][0]
        repo = first_blob['url']
        revision = first_blob.get('revision')

        # Collect all repo-paths; validate they are all present.
        repo_paths = []
        for blob, _ in blobs_and_paths:
            rp = blob.get('repo-path')
            if not rp:
                raise McuxBlobException(
                    "git fetcher requires a 'repo-path' field")
            repo_paths.append(rp)

        tmp_parent = self._tmp_parent(west_command)
        tmpdir = None
        failed = []
        try:
            tmpdir = Path(tempfile.mkdtemp(prefix='bb-', dir=str(tmp_parent)))
            west_command.dbg(
                f'GitFetcher batch-fetching {len(repo_paths)} paths '
                f'@{revision or "HEAD"} from {repo} into {tmpdir}')

            # A failure here (clone / sparse-checkout) invalidates the whole
            # batch -- nothing has been fetched yet, so let it propagate.
            pending_rev = self._clone(west_command, repo, revision, tmpdir)
            self._checkout_paths(west_command, tmpdir, pending_rev, repo_paths)

            # Copy each file out; fall back to individual fetch for any
            # missing. Each blob is isolated so one bad path can't stop the
            # rest of the batch from being copied.
            for blob, dest_path in blobs_and_paths:
                rp = blob['repo-path']
                src = tmpdir / rp
                try:
                    if src.is_file():
                        dest_path.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy(src, dest_path)
                    else:
                        west_command.dbg(
                            f'GitFetcher batch: {rp} missing after checkout, '
                            f'falling back to individual fetch')
                        self.fetch(west_command, blob, dest_path)
                except (McuxBlobException, OSError) as e:
                    west_command.dbg(f'GitFetcher batch: {rp} failed: {e}')
                    failed.append((blob, dest_path))
        finally:
            if tmpdir is not None:
                shutil.rmtree(tmpdir, ignore_errors=True)
            try:
                os.rmdir(tmp_parent)
            except OSError:
                pass

        return failed
