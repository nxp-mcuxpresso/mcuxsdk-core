# Copyright (c) 2022 Nordic Semiconductor ASA
# Copyright 2025-2026 NXP
#
# SPDX-License-Identifier: Apache-2.0
#
# Adapted for the MCUXpresso SDK from Zephyr's
# zephyr/scripts/west_commands/blobs.py (Nordic, Apache-2.0).
#
# The download / verify / license-gate / cache machinery is kept as-is; only the
# blob DISCOVERY layer is replaced. Zephyr discovers blobs by walking west
# projects for `zephyr/module.yml` and lands them under `<module>/zephyr/blobs/`.
# Here we discover `mcux_blobs.yml` (Option A) and land blobs under
# MCUX_PREBUILT_ROOT, so `west blobs fetch` and the CMake seam meet at one dir.

import argparse
import contextlib
import csv
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
import time
from pathlib import Path
from urllib.parse import urlparse

import yaml
from west.commands import WestCommand

from fetchers.core import McuxBlobException

# Blob presence states, mirroring Zephyr's zephyr_module constants.
BLOB_PRESENT = 'A'      # present and hash matches
BLOB_NOT_PRESENT = 'D'  # not on disk
BLOB_OUTDATED = 'M'     # present but hash mismatch

# Name of the per-repo blob manifest discovered in each west project.
MCUX_BLOBS_MANIFEST = 'mcux_blobs.yml'

# ext -> blob `type` field (informational, mirrors gen_mcux_blobs.py's split).
LIB_EXTS = {'a', 'lib', 'o', 'obj', 'so', 'dll'}

# ------------------------------------------------------------------
# Constants for 'west blobs scan' (mirrors repo_blob_impact.py / binary_inventory.py)
# ------------------------------------------------------------------

# Build-artifact extensions that count as committed binaries needing migration.
SCAN_BINARY_EXTS = {
    '.a', '.lib', '.o', '.obj', '.bin', '.so', '.dll',
    '.hex', '.axf', '.elf', '.out', '.srec',
}

# Directories that are build outputs / generated -- skip entirely when scanning.
SCAN_EXCLUDE_DIR_PARTS = {
    'build', 'builds', 'out_dir2', 'out_dir3', 'out_dir4', 'out3',
    'gcov_output', 'test_output', '.git', '__pycache__',
    'node_modules', 'site-packages',
}
SCAN_EXCLUDE_DIR_PATTERNS = (
    re.compile(r'docs-backup'),
    re.compile(r'docs\.bak'),
    re.compile(r'out_dir\d*'),
    re.compile(r'\.venv'),
)

# Migration states reported by 'west blobs scan'.
SCAN_STATE_NOT_STARTED = 'not-started'  # has binaries, no mcux_blobs.yml
SCAN_STATE_IN_PROGRESS = 'in-progress'  # has mcux_blobs.yml AND committed binaries
SCAN_STATE_PORTED      = 'ported'       # has mcux_blobs.yml, no committed binaries left


def sha256_of_file(path):
    m = hashlib.sha256()
    with Path(path).open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            m.update(chunk)
    return m.hexdigest()


def yaml_quote(value):
    '''Quote a scalar for YAML if it could be misparsed; keep it minimal.

    Mirrors gen_mcux_blobs.py's yaml_quote() so both tools agree on formatting.
    '''
    if value == '' or re.search(r'[:#\'"\n]|^\s|\s$', value):
        escaped = value.replace('\\', '\\\\').replace('"', '\\"')
        return f'"{escaped}"'
    return value


def emit_mcux_blobs_yaml(blobs):
    '''Serialize a blobs list back to mcux_blobs.yml text.

    Field order/formatting matches gen_mcux_blobs.py's emit_yaml() exactly, so
    a bulk `gen_mcux_blobs.py` regenerate and an incremental `west blobs update`
    never disagree on how an untouched entry should look.
    '''
    fetchers = {b.get('fetcher') for b in blobs if b.get('fetcher')}
    revisions = {b.get('revision') for b in blobs if b.get('revision')}
    fetcher_note = fetchers.pop() if len(fetchers) == 1 else 'mixed'
    revision_note = revisions.pop() if len(revisions) == 1 else 'mixed'

    lines = [
        '# mcux_blobs.yml. DO NOT hand-edit sha256 values directly.',
        '# Bulk-regenerate a filtered slice with gen_mcux_blobs.py; for a single',
        '# new/changed blob use `west blobs update <file>` (see -h for both).',
        f'# fetcher: {fetcher_note}   revision: {revision_note}',
        f'# entries: {len(blobs)}',
        'blobs:',
    ]
    for blob in sorted(blobs, key=lambda b: b['path']):
        lines.append(f"  - path: {blob['path']}")
        lines.append(f"    sha256: {blob['sha256']}")
        lines.append(f"    type: {blob.get('type', 'img')}")
        lines.append(f"    version: {yaml_quote(str(blob.get('version', '1.0')))}")
        lines.append(f"    license-path: {blob.get('license-path', '')}")
        if blob.get('fetcher'):
            lines.append(f"    fetcher: {blob['fetcher']}")
        lines.append(f"    url: {blob.get('url', '')}")
        if blob.get('repo-path'):
            lines.append(f"    repo-path: {blob['repo-path']}")
        if blob.get('revision'):
            lines.append(f"    revision: {blob['revision']}")
        if blob.get('click-through'):
            lines.append('    click-through: true')
        lines.append(f"    description: {yaml_quote(blob.get('description', ''))}")
    return '\n'.join(lines) + '\n'


def get_blob_status(path, sha256):
    '''Return BLOB_PRESENT / BLOB_OUTDATED / BLOB_NOT_PRESENT for path.'''
    path = Path(path)
    if not path.is_file():
        return BLOB_NOT_PRESENT
    if sha256.lower() == sha256_of_file(path):
        return BLOB_PRESENT
    return BLOB_OUTDATED


class Blobs(WestCommand):
    DEFAULT_LIST_FMT = '{module} {status} {path} {type} {abspath}'

    def __init__(self):
        super().__init__(
            'blobs',
            'work with binary blobs declared in mcux_blobs.yml manifests',
            description='Work with MCUXpresso SDK binary blobs',
            accepts_unknown_args=True,
        )

    def do_add_parser(self, parser_adder):
        parser = parser_adder.add_parser(
            self.name,
            formatter_class=argparse.RawDescriptionHelpFormatter,
            description=self.description,
            epilog=textwrap.dedent(f'''\
            FORMAT STRINGS
            --------------

            Blobs are listed using a Python 3 format string. Arguments
            to the format string are accessed by name.

            The default format string is:

            "{self.DEFAULT_LIST_FMT}"

            The following arguments are available:

            - module: name of the repo/manifest that declares this blob
            - abspath: blob absolute path (under MCUX_PREBUILT_ROOT)
            - status: short status (A: present, M: hash failure, D: not present)
            - path: blob local path (relative to MCUX_PREBUILT_ROOT)
            - sha256: blob SHA256 hash in hex
            - type: type of blob
            - version: version string
            - license_path: path to the license file for the blob
            - license-abspath: absolute path to the license file for the blob
            - click-through: need license click-through or not
            - url: URI(s) to the remote location(s) of the blob
            - fetcher: method to use to fetch the blob
            - description: blob text description
            - doc-url: URL to the documentation for this blob

            DISCOVERY
            ---------

            Blobs are declared in '{MCUX_BLOBS_MANIFEST}' files. By default every
            west project root is searched for one. Use --manifest-file to point
            at additional manifests (repeatable), or set the west config option
            'blobs.manifest-files' (semicolon-separated).

            LANDING DIRECTORY
            -----------------

            Fetched blobs land under MCUX_PREBUILT_ROOT (the same root the CMake
            seam reads), resolved in this order:
              1. --prebuilt-root
              2. $MCUX_PREBUILT_ROOT
              3. west config 'blobs.prebuilt-root'
              4. <workspace>/mcuxsdk if present, else <workspace>

            DAY-TO-DAY: ADDING OR CHANGING A BLOB
            --------------------------------------

            'west blobs update <file> [<file> ...]' is for a developer who just
            built or vendored a new/updated prebuilt binary and wants it added to
            (or refreshed in) the manifest -- WITHOUT committing the binary itself
            to the source repo. Each <file> must sit at its normal in-tree path
            under MCUX_PREBUILT_ROOT (build/test locally exactly as before; this
            step only runs when you are ready to submit).

              west blobs update examples/_boards/myboard/demo_apps/foo/foo.bin

            This hashes the file, finds the mcux_blobs.yml that owns its path,
            and either updates the matching entry's sha256 (existing blob changed)
            or appends a new entry (new blob), reusing that manifest's existing
            fetcher/url/revision/license-path. It prints the exact next steps:
            push the file's bytes to the matching blob repo, then commit the
            (minimally-diffed) mcux_blobs.yml as part of your normal source PR.

            gen_mcux_blobs.py remains the tool for
            bulk-regenerating a whole filtered slice from a fully-populated
            source tree (e.g. the original migration); it cannot help with a
            single new blob once the source tree no longer carries the binary.

            'west blobs check [MODULE ...]' verifies every declared blob's
            on-disk hash against its manifest entry (read-only; never fetches
            or writes anything). Run it after 'west blobs fetch' and before
            removing any binary from the SDK source tree.

            'west blobs regen MODULE --init --url URL --blob-repo MODULE=DIR'
            onboards a whole new blob repo for a west project in one pass
            (bootstrap + optional --stage copy); see ONBOARD_BLOB_REPO_GUIDE.md
            for the full walkthrough.

            MIGRATION DASHBOARD
            -------------------

            'west blobs scan' reports which west projects still contain
            committed build-artifact binaries and their current migration state:

              not-started  - has committed binaries, no mcux_blobs.yml yet
              in-progress  - has BOTH a mcux_blobs.yml AND committed binaries
                             (manifest created, blobs not yet git-rm'd)
              ported       - has a mcux_blobs.yml, no committed binaries left

            Default (summary mode): one line per affected project, ranked by
            size, with blob count / MB / state.

              west blobs scan                          # all not-started + in-progress
              west blobs scan --state not-started      # only un-started projects
              west blobs scan --state all              # all three states
              west blobs scan mcu-sdk-examples         # specific project
              west blobs scan -l '.*\\.a$'             # filter by file extension

            Add --files (-v) to list every individual binary path + size:

              west blobs scan --files
              west blobs scan middleware/emwin --files
              west blobs scan -l '^middleware/' --files
            '''),
        )

        parser.add_argument(
            'subcmd', nargs=1,
            choices=['list', 'fetch', 'clean', 'check', 'update', 'regen', 'scan'],
            help='sub-command to execute',
        )

        parser.add_argument(
            'modules',
            metavar='MODULE',
            nargs='*',
            help='''blob modules (mcux_blobs.yml manifest names) to operate on;
                    all modules will be used if not given. For 'update', this is
                    instead the list of local FILE paths to add/refresh (see
                    DAY-TO-DAY below).''',
        )

        group = parser.add_argument_group('blob discovery / landing options')
        group.add_argument(
            '--manifest-file',
            action='append',
            default=[],
            help=f'''path to an additional {MCUX_BLOBS_MANIFEST} to read;
                     may be given multiple times''',
        )
        group.add_argument(
            '--prebuilt-root',
            help='''landing root for fetched blobs (overrides $MCUX_PREBUILT_ROOT
                    and west config blobs.prebuilt-root)''',
        )

        group = parser.add_argument_group('west blobs list options')
        group.add_argument(
            '-f',
            '--format',
            help='''format string to use to list each blob;
                    see FORMAT STRINGS below''',
        )

        group = parser.add_argument_group('west blobs fetch/clean options')
        group.add_argument(
            '-l',
            '--allow-regex',
            help='''Regex pattern applied (re.match, i.e. anchored at the start
                    of the blob local path) to filter which blobs the command
                    acts on. For 'fetch' only matching blobs are fetched; for
                    'clean' only matching blobs are deleted. Use a leading '.*'
                    for a suffix/substring match.''',
        )

        group.add_argument(
            '-a',
            '--auto-accept',
            action='store_true',
            help='''auto accept license if the fetching needs click-through''',
        )
        group.add_argument(
            '--cache-dirs',
            help='''Semicolon-separated list of directories to search for cached
                    blobs before downloading. Cache files may use the original
                    filename or be suffixed with `.<sha256>`.''',
        )
        group.add_argument(
            '--auto-cache',
            help='''Path to a directory that is automatically populated when a blob
                    is downloaded. Cached blobs are stored using the original
                    filename suffixed with `.<sha256>`.''',
        )

        group = parser.add_argument_group('west blobs update options')
        group.add_argument(
            '--version',
            help='''version string to set on the added/updated entry (default:
                    keep existing value, or "1.0" for a brand-new entry)''',
        )
        group.add_argument(
            '--description',
            help='''description text to set (default: keep existing value, or an
                    auto-generated one for a brand-new entry)''',
        )
        group.add_argument(
            '--click-through',
            action='store_true',
            help='''mark the added/updated entry as requiring interactive license
                    click-through (only ever turns this ON; use a manual
                    mcux_blobs.yml edit-free re-run to turn it off)''',
        )
        group.add_argument(
            '--type',
            choices=['img', 'lib'],
            help='''override the inferred blob type (default: "lib" for
                    a/lib/o/obj/so/dll extensions, "img" otherwise)''',
        )

        group = parser.add_argument_group('west blobs regen options')
        group.add_argument(
            '--blob-repo',
            action='append',
            default=[],
            metavar='MODULE=DIR',
            help='''Map a manifest module to a local blob-repo checkout.
                    Format: MODULE=<path> (repeatable). If not given the tool
                    auto-detects the checkout by matching the manifest url to a
                    git remote of sibling directories under the workspace root.''',
        )
        group.add_argument(
            '--source',
            choices=['auto', 'blob-repo', 'sdk-tree'],
            default='auto',
            help='''Where to hash blob bytes from (default: auto).
                    auto: prefer the blob-repo copy; fall back to the SDK tree.
                    blob-repo: only use the blob-repo checkout (error if absent).
                    sdk-tree: only use the SDK working tree (pre-migration).''',
        )
        group.add_argument(
            '--stage',
            action='store_true',
            help='''Before reconciling, copy any blob that exists in the SDK tree
                    but is not yet present in the blob-repo checkout to its
                    mirrored repo-path. Useful during migration: run with --stage
                    to populate the blob repo, commit+push the blob repo, then
                    git-rm the binaries from the SDK repo. The tool never runs
                    git rm / commit / push itself.''',
        )
        group.add_argument(
            '--no-prune',
            action='store_true',
            help='''Keep manifest entries whose blob is absent from both the
                    blob-repo checkout and the SDK tree (warn but do not remove).
                    Default: prune such entries.''',
        )
        group.add_argument(
            '--dry-run',
            action='store_true',
            help='''Print added / changed / removed entries per manifest without
                    writing any file. Also prints staged copies when --stage is
                    used together with --dry-run.''',
        )
        group.add_argument(
            '--init',
            action='store_true',
            help='''Bootstrap a new mcux_blobs.yml for a west project that has
                    no manifest yet. Requires a MODULE name and --url. Scans the
                    project directory for binary candidates (extensions: a lib o
                    obj so dll, extended by --init-suffix) and emits a fresh
                    mcux_blobs.yml alongside them. Combine with --stage to also
                    populate the blob-repo checkout at the same time.''',
        )
        group.add_argument(
            '--url',
            default=None,
            metavar='URL',
            help='''Blob-repo URL recorded in every entry generated by --init
                    (e.g. ssh://git@<host>/<group>/<repo>-blobs.git).
                    Required when --init is used.''',
        )
        group.add_argument(
            '--blob-revision',
            default='main',
            dest='blob_revision',
            metavar='REF',
            help='''Git revision recorded in entries generated by --init
                    (default: main).''',
        )
        group.add_argument(
            '--init-license-path',
            default='../COPYING-BSD-3',
            dest='init_license_path',
            metavar='PATH',
            help='''Relative license-path embedded in entries generated by
                    --init (default: ../COPYING-BSD-3).''',
        )
        group.add_argument(
            '--init-fetcher',
            default='git',
            dest='init_fetcher',
            metavar='FETCHER',
            help='''Fetcher embedded in entries generated by --init
                    (default: git).''',
        )
        group.add_argument(
            '--init-suffix',
            action='append',
            default=[],
            dest='init_suffix',
            metavar='EXT',
            help='''Extra file extension (without leading dot) to include when
                    scanning for binary candidates during --init (repeatable).
                    Built-in set: a lib o obj so dll.''',
        )

        group = parser.add_argument_group('west blobs scan options')
        group.add_argument(
            '--files',
            action='store_true',
            help='''List every individual binary file found under each project
                    directory instead of the per-project summary. Combined with
                    -l/--allow-regex to drill into a specific subtree.''',
        )
        group.add_argument(
            '--state',
            choices=[SCAN_STATE_NOT_STARTED, SCAN_STATE_IN_PROGRESS,
                     SCAN_STATE_PORTED, 'all'],
            default=None,
            metavar='STATE',
            help='''Filter results to repos in a specific migration state:
                    not-started (binaries present, no mcux_blobs.yml),
                    in-progress (both present), ported (manifest only,
                    no committed binaries), all (show all three states).
                    Default: show all three states.''',
        )
        group.add_argument(
            '--by-owner',
            action='store_true',
            dest='by_owner',
            help='''Group and sort results by owner (from west project userdata).
                    Shows a per-owner aggregate line followed by the individual
                    project rows. Useful for tracking who owns the remaining
                    migration work.''',
        )
        group.add_argument(
            '--json',
            default=None,
            metavar='PATH',
            dest='scan_json',
            help='''Write scan results to a JSON file at PATH (in addition to
                    printing the summary table). Snapshots can be diffed over
                    time to track migration progress.''',
        )
        group.add_argument(
            '--csv',
            default=None,
            metavar='PATH',
            dest='scan_csv',
            help='''Write scan results to a CSV file at PATH (one row per
                    project, in addition to printing the summary table).''',
        )

        return parser

    # ------------------------------------------------------------------
    # Discovery (the MCUX-specific replacement for zephyr_module)
    # ------------------------------------------------------------------

    def prebuilt_root(self, args) -> Path:
        '''Resolve the MCUX_PREBUILT_ROOT landing directory.'''
        root = args.prebuilt_root
        if root is None:
            root = os.environ.get('MCUX_PREBUILT_ROOT')
        if root is None and self.has_config:
            root = self.config.get('blobs.prebuilt-root')
        if root is None:
            topdir = Path(self.topdir)
            sdk = topdir / 'mcuxsdk'
            root = sdk if sdk.is_dir() else topdir
        return Path(root).expanduser().resolve()

    def discover_manifests(self, args):
        '''Return a list of (module_name, manifest_dir, manifest_path).

        Every west project root is searched for an mcux_blobs.yml; extra
        manifests may be added via --manifest-file or west config.
        '''
        found = []
        seen = set()

        def add(path: Path, name: str):
            path = path.resolve()
            if path in seen or not path.is_file():
                return
            seen.add(path)
            found.append((name, path.parent, path))

        # 1. west projects
        try:
            for project in self.manifest.projects:
                abspath = getattr(project, 'abspath', None)
                if not abspath:
                    continue
                add(Path(abspath) / MCUX_BLOBS_MANIFEST,
                    getattr(project, 'name', None) or Path(abspath).name)
        except Exception as e:  # noqa: BLE001 - discovery must be best-effort
            self.dbg(f'west project discovery skipped: {e}')

        # 2. explicit --manifest-file
        for mf in args.manifest_file:
            p = Path(mf).expanduser()
            add(p, p.parent.name)

        # 3. west config blobs.manifest-files
        if self.has_config:
            cfg = self.config.get('blobs.manifest-files')
            if cfg:
                for mf in cfg.split(';'):
                    if mf:
                        p = Path(mf).expanduser()
                        add(p, p.parent.name)

        return found

    def get_blobs(self, args):
        prebuilt_root = self.prebuilt_root(args)
        self.dbg(f'MCUX_PREBUILT_ROOT: {prebuilt_root}')

        manifests = self.discover_manifests(args)
        all_names = [name for name, _, _ in manifests]
        unknown = set(args.modules) - set(all_names)
        if unknown:
            self.die(
                f'Unknown module(s): {", ".join(sorted(unknown))}\n'
                f'Available modules: {", ".join(sorted(all_names))}')

        blobs = []
        for name, manifest_dir, manifest_path in manifests:
            if args.modules and name not in args.modules:
                continue
            try:
                with manifest_path.open(encoding='utf-8') as f:
                    meta = yaml.safe_load(f) or {}
            except (OSError, yaml.YAMLError) as e:
                self.err(f'Failed to read {manifest_path}: {e}')
                continue

            for blob in meta.get('blobs', None) or []:
                blob = dict(blob)
                blob['module'] = name
                blob['abspath'] = prebuilt_root / Path(blob['path'])
                lic = blob.get('license-path')
                blob['license-abspath'] = (manifest_dir / Path(lic)) if lic else None
                blob['status'] = get_blob_status(blob['abspath'], blob['sha256'])
                blob['click-through'] = blob.get('click-through', False)
                blob.setdefault('type', '')
                blob.setdefault('version', '')
                blob.setdefault('description', '')
                blobs.append(blob)

        return blobs

    # ------------------------------------------------------------------
    # Subcommands
    # ------------------------------------------------------------------

    def list(self, args):
        blobs = self.get_blobs(args)
        fmt = args.format or self.DEFAULT_LIST_FMT
        for blob in blobs:
            if args.allow_regex and not re.match(args.allow_regex, blob['path']):
                self.dbg(
                    f"[list] blob path '{blob['path']}' does not match "
                    f"'{args.allow_regex}', skipping"
                )
                continue
            self.inf(fmt.format(**blob))

    def ensure_folder(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)

    def handle_auto_cache(self, blob, auto_cache_dir) -> Path:
        cached_blob = self.get_cached_blob(blob, [auto_cache_dir])
        if cached_blob:
            return cached_blob
        name = Path(blob['path']).name
        sha256 = blob['sha256']
        self.download_blob(blob, auto_cache_dir / f'{name}.{sha256}')
        cached_blob = self.get_cached_blob(blob, [auto_cache_dir])
        assert cached_blob, f'Blob {name} still not cached in auto-cache.'
        return cached_blob

    def get_cached_blob(self, blob, cache_dirs):
        name = Path(blob['path']).name
        sha256 = blob['sha256']
        candidate_names = [
            f'{name}.{sha256}',  # suffixed version
            name,                # original blob name
        ]
        for cache_dir in cache_dirs:
            if not cache_dir.exists():
                continue
            for cand in candidate_names:
                candidate_path = cache_dir / cand
                if get_blob_status(candidate_path, sha256) == BLOB_PRESENT:
                    return candidate_path
        return None

    def download_blob(self, blob, path):
        '''Download a blob from its url to a given path.'''
        urls = blob['url']
        if not isinstance(urls, list):
            urls = (urls,)

        valid_url = None
        has_error = False
        for url in urls:
            scheme = blob.get('fetcher') or urlparse(url).scheme
            self.dbg(f'Fetching blob from url {url} with {scheme} to path: {path}')
            import fetchers

            fetcher_class = fetchers.get_fetcher_cls(scheme)
            self.dbg(f'Found fetcher: {fetcher_class}')
            fetcher = fetcher_class()
            self.ensure_folder(path)

            single_url_blob = blob.copy()
            single_url_blob['url'] = url

            try:
                fetcher.fetch(self, single_url_blob, path)
            except McuxBlobException as e:
                self.wrn(e)
                has_error = True
            else:
                valid_url = url
                break

        if valid_url is None:
            raise McuxBlobException('No URL worked for this blob')
        if has_error:
            self.inf(f'Fallback URL worked: {valid_url}')

    def fetch_blob(self, args, blob):
        path = Path(blob['abspath'])

        cache_dirs = args.cache_dirs
        auto_cache_dir = args.auto_cache
        if self.has_config:
            if cache_dirs is None:
                cache_dirs = self.config.get('blobs.cache-dirs')
            if auto_cache_dir is None:
                auto_cache_dir = self.config.get('blobs.auto-cache')

        if auto_cache_dir is not None:
            auto_cache_dir = Path(auto_cache_dir).expanduser()
        if cache_dirs is not None:
            cache_dirs = [Path(p).expanduser() for p in cache_dirs.split(';') if p]

        cached_blob = self.get_cached_blob(blob, cache_dirs or [])

        if not cached_blob and auto_cache_dir:
            cached_blob = self.handle_auto_cache(blob, auto_cache_dir)

        if cached_blob:
            self.dbg(f'Copy cached blob: {cached_blob}')
            self.ensure_folder(path)
            shutil.copy(cached_blob, path)
        else:
            self.download_blob(blob, path)

    def verify_blob(self, blob) -> bool:
        self.dbg(f"Verifying blob {blob['module']}: {blob['abspath']}")
        status = get_blob_status(blob['abspath'], blob['sha256'])
        if status == BLOB_OUTDATED:
            self.err(
                textwrap.dedent(
                    f'''\
                The checksum of the downloaded file does not match that
                in the blob metadata:
                - if it is not certain that the download was successful,
                  try running 'west blobs fetch {blob['module']}'
                  to re-download the file
                - if the error persists, please consider contacting
                  the maintainers of the module so that they can check
                  the corresponding blob metadata

                Module: {blob['module']}
                Blob:   {blob['path']}
                URL:    {blob['url']}
                Info:   {blob['description']}'''
                )
            )
            return False
        return True

    @contextlib.contextmanager
    def _ssh_control_master(self):
        # SSH connection multiplexing for the duration of a fetch run.
        #
        # Sets GIT_SSH_COMMAND so every git subprocess spawned while this
        # context is active reuses a single authenticated SSH session per host
        # (ControlMaster=auto, ControlPersist=10s) instead of opening a fresh
        # ~1.2s handshake for every clone/fetch call.
        #
        # Measured benefit: cold ls-remote ~1.2s vs warm reused ~0.2s (~6x).
        # Per blob: 3 git SSH ops drop from ~3.6s to ~1.6s.
        # 887-blob run: ~50 min -> ~16 min.
        #
        # The socket lives under <topdir>/.west_blobs_tmp/ so it is on a local
        # filesystem (SSH control sockets cannot be on NFS). It is scoped to
        # this process only via a temporary environment override; the user's
        # GIT_SSH_COMMAND and ~/.ssh/config are not modified. If ssh is absent
        # or the master fails to start the fetch continues without multiplexing.
        tmp_dir = None
        prev_git_ssh_cmd = os.environ.get('GIT_SSH_COMMAND')
        try:
            topdir = Path(self.topdir)
            blob_tmp = topdir / '.west_blobs_tmp'
            blob_tmp.mkdir(parents=True, exist_ok=True)
            tmp_dir = Path(tempfile.mkdtemp(prefix='ssh-cm-', dir=str(blob_tmp)))
            sock = tmp_dir / 'cm.sock'

            ssh_cmd = (
                f'ssh -o ControlMaster=auto'
                f' -o ControlPath={sock}'
                f' -o ControlPersist=10s'
            )
            os.environ['GIT_SSH_COMMAND'] = ssh_cmd
            self.dbg(f'SSH ControlMaster enabled (socket: {sock})')
        except Exception as e:  # noqa: BLE001
            self.dbg(f'SSH ControlMaster setup failed, continuing without: {e}')
        try:
            yield
        finally:
            # Tear down the master gracefully so we do not leave a background
            # ssh process running after the fetch completes.
            if tmp_dir is not None:
                sock = tmp_dir / 'cm.sock'
                if sock.exists():
                    try:
                        subprocess.run(
                            ['ssh', '-O', 'exit',
                             '-o', f'ControlPath={sock}',
                             'localhost'],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                            timeout=5,
                        )
                    except Exception:  # noqa: BLE001
                        pass
                shutil.rmtree(tmp_dir, ignore_errors=True)
            # Restore the original GIT_SSH_COMMAND (or unset if it was absent).
            if prev_git_ssh_cmd is None:
                os.environ.pop('GIT_SSH_COMMAND', None)
            else:
                os.environ['GIT_SSH_COMMAND'] = prev_git_ssh_cmd

    def _resolve_cache_settings(self, args):
        '''Return (cache_dirs, auto_cache_dir) resolved from args + west config.'''
        cache_dirs = args.cache_dirs
        auto_cache_dir = args.auto_cache
        if self.has_config:
            if cache_dirs is None:
                cache_dirs = self.config.get('blobs.cache-dirs')
            if auto_cache_dir is None:
                auto_cache_dir = self.config.get('blobs.auto-cache')
        if auto_cache_dir is not None:
            auto_cache_dir = Path(auto_cache_dir).expanduser()
        if cache_dirs is not None:
            cache_dirs = [Path(p).expanduser() for p in cache_dirs.split(';') if p]
        return cache_dirs or [], auto_cache_dir

    def fetch(self, args):
        bad_checksum_count = 0
        failed_fetch_count = 0
        fetch_times = []   # list of (path, elapsed_s) for successfully fetched blobs
        run_t0 = time.perf_counter()

        cache_dirs, auto_cache_dir = self._resolve_cache_settings(args)

        with self._ssh_control_master():
            blobs = self.get_blobs(args)

            # ------------------------------------------------------------------
            # Pass 1: per-blob filter + click-through gate.
            # Produces 'eligible': blobs that need to be delivered to dest.
            # ------------------------------------------------------------------
            eligible = []
            for blob in blobs:
                if blob['status'] == BLOB_PRESENT:
                    self.dbg(f"Blob {blob['module']}: {blob['abspath']} is up to date")
                    continue

                if args.allow_regex and not re.match(args.allow_regex, blob['path']):
                    self.dbg(
                        f"Blob {blob['module']}: {blob['abspath']} does not match regex "
                        f"'{args.allow_regex}', skipping"
                    )
                    continue

                self.inf(f"Fetching blob {blob['module']}: {blob['abspath']}")

                if blob['click-through'] and not args.auto_accept:
                    while True:
                        user_input = input(
                            "For this blob, need to read and accept "
                            "license to continue. Read it?\n"
                            "Please type 'y' or 'n' and press enter to confirm: "
                        )
                        if user_input.upper() in ('Y', 'N'):
                            break

                    if user_input.upper() != 'Y':
                        self.wrn('Skip fetching this blob.')
                        continue

                    if blob['license-abspath']:
                        with open(blob['license-abspath'], encoding='utf-8') as license_file:
                            print(license_file.read())

                    while True:
                        user_input = input(
                            "Accept license to continue?\n"
                            "Please type 'y' or 'n' and press enter to confirm: "
                        )
                        if user_input.upper() in ('Y', 'N'):
                            break

                    if user_input.upper() != 'Y':
                        self.wrn('Skip fetching this blob.')
                        continue

                eligible.append(blob)

            # ------------------------------------------------------------------
            # Pass 2: cache lookup + routing.
            # Cache hits are resolved immediately (file copy only).
            # Network downloads are grouped by (url, revision, fetcher_scheme)
            # so blobs that share a repo are fetched in a single clone.
            # Blobs with list URLs skip batching and go to 'individuals'.
            # ------------------------------------------------------------------
            batch_groups = {}   # (url, revision, scheme) -> [(blob, dest_path)]
            individuals = []    # (blob, dest_path) -- fallback: one clone per blob

            for blob in eligible:
                dest_path = Path(blob['abspath'])

                # Check explicit cache dirs first, then auto_cache.
                all_cache_dirs = list(cache_dirs)
                if auto_cache_dir is not None:
                    all_cache_dirs.append(auto_cache_dir)
                cached = self.get_cached_blob(blob, all_cache_dirs)

                if cached:
                    blob_t0 = time.perf_counter()
                    self.ensure_folder(dest_path)
                    shutil.copy(cached, dest_path)
                    dt = time.perf_counter() - blob_t0
                    fetch_times.append((blob['path'], dt))
                    self.inf(f"  -> from cache in {dt:.3f}s")
                    if not self.verify_blob(blob):
                        bad_checksum_count += 1
                    continue

                # Needs network download.
                url = blob['url']
                if isinstance(url, list):
                    # Multi-URL fallback chain: keep original per-blob logic.
                    individuals.append((blob, dest_path))
                    continue

                scheme = blob.get('fetcher') or urlparse(url).scheme
                revision = blob.get('revision') or ''
                key = (url, revision, scheme)
                batch_groups.setdefault(key, []).append((blob, dest_path))

            # ------------------------------------------------------------------
            # Pass 3: batched network download (one clone per repo group).
            #
            # fetch_many() either raises (the shared clone/checkout itself
            # failed -- nothing in the group was fetched, so the whole group
            # falls back to individual fetching) or returns a list of the
            # specific (blob, dest_path) entries that failed (possibly empty).
            # Only the entries that actually failed are requeued individually
            # -- blobs that were already fetched successfully in the batch are
            # NOT re-fetched.
            # ------------------------------------------------------------------
            for (url, revision, scheme), group in batch_groups.items():
                import fetchers
                fetcher_class = fetchers.get_fetcher_cls(scheme)
                fetcher = fetcher_class()
                n = len(group)
                self.inf(
                    f"  Batch-fetching {n} blob(s) from {url!r}"
                    f" @ {revision or 'HEAD'} ..."
                )
                group_t0 = time.perf_counter()
                try:
                    failed = fetcher.fetch_many(self, group)
                except McuxBlobException as e:
                    self.wrn(
                        f"Batch fetch failed ({e}); retrying {n} blob(s) individually ..."
                    )
                    individuals.extend(group)
                    continue

                group_dt = time.perf_counter() - group_t0

                if failed:
                    failed_paths = {blob['path'] for blob, _ in failed}
                    self.wrn(
                        f"  {len(failed)} of {n} blob(s) in this batch failed; "
                        f"retrying individually ..."
                    )
                    individuals.extend(failed)
                else:
                    failed_paths = set()

                succeeded = [
                    (blob, dest_path) for blob, dest_path in group
                    if blob['path'] not in failed_paths
                ]
                # Compute per_blob_dt unconditionally so it is always defined
                # before the loop below references it (even when succeeded is
                # non-empty but the `if succeeded:` block above was skipped in
                # a future refactor).
                per_blob_dt = group_dt / n if n else 0.0
                if succeeded:
                    self.inf(
                        f"  -> batch done: {len(succeeded)}/{n} blob(s) in "
                        f"{group_dt:.2f}s ({per_blob_dt:.2f}s/blob avg)"
                    )
                for blob, dest_path in succeeded:
                    # Populate auto_cache after a successful batch download.
                    if auto_cache_dir is not None and dest_path.is_file():
                        name = Path(blob['path']).name
                        sha256 = blob['sha256']
                        cache_path = auto_cache_dir / f'{name}.{sha256}'
                        cache_path.parent.mkdir(parents=True, exist_ok=True)
                        try:
                            shutil.copy(dest_path, cache_path)
                        except OSError:
                            pass
                    fetch_times.append((blob['path'], per_blob_dt))
                    if not self.verify_blob(blob):
                        bad_checksum_count += 1

            # ------------------------------------------------------------------
            # Pass 4: individual fallbacks (list URLs + batch failures).
            # Uses the existing fetch_blob() path (cache + auto_cache + verify).
            # ------------------------------------------------------------------
            for blob, dest_path in individuals:
                blob_t0 = time.perf_counter()
                try:
                    self.fetch_blob(args, blob)
                except McuxBlobException as e:
                    self.err(f"Failed to fetch blob: {e}")
                    failed_fetch_count += 1
                else:
                    dt = time.perf_counter() - blob_t0
                    fetch_times.append((blob['path'], dt))
                    self.inf(f"  -> fetched in {dt:.2f}s")
                    if not self.verify_blob(blob):
                        bad_checksum_count += 1

        # ------------------------------------------------------------------
        # Timing summary
        # ------------------------------------------------------------------
        if fetch_times:
            total_dt = time.perf_counter() - run_t0
            n = len(fetch_times)
            avg_dt = sum(dt for _, dt in fetch_times) / n
            slowest_path, slowest_dt = max(fetch_times, key=lambda x: x[1])
            self.inf(
                f"\nTiming summary: fetched {n} blob(s) in {total_dt:.1f}s "
                f"(avg {avg_dt:.2f}s/blob, slowest {slowest_dt:.2f}s: {slowest_path})"
            )

        if bad_checksum_count:
            self.err(f"{bad_checksum_count} blobs have bad checksums")
            sys.exit(os.EX_DATAERR)

        if failed_fetch_count:
            self.die(f"{failed_fetch_count} blobs failed to be fetched")

    def clean(self, args):
        blobs = self.get_blobs(args)
        for blob in blobs:
            if blob['status'] == BLOB_NOT_PRESENT:
                self.dbg(f"Blob {blob['module']}: {blob['abspath']} not in filesystem")
                continue

            # Honor the same --allow-regex path filter that 'fetch' uses, so a
            # targeted 'west blobs clean -l <regex>' deletes only the matching
            # blobs instead of every present blob.
            if args.allow_regex and not re.match(args.allow_regex, blob['path']):
                self.dbg(
                    f"Blob {blob['module']}: {blob['abspath']} does not match regex "
                    f"'{args.allow_regex}', skipping"
                )
                continue

            self.inf(f"Deleting blob {blob['module']}: {blob['status']} {blob['abspath']}")
            Path(blob['abspath']).unlink()

    def check(self, args):
        '''Verify every declared blob's on-disk hash matches its manifest entry.

        Read-only: never fetches, writes, or modifies anything. This is the
        round-trip verification step -- run after 'west blobs fetch' and
        before removing binaries from the SDK source tree, so a stale/mismatched
        blob is caught before it becomes the only copy of that binary.
        '''
        blobs = self.get_blobs(args)
        if not blobs:
            self.die('No blobs matched.')

        ok = mismatch = missing = 0
        for blob in blobs:
            if blob['status'] == BLOB_PRESENT:
                ok += 1
            elif blob['status'] == BLOB_OUTDATED:
                mismatch += 1
                self.err(
                    f"MISMATCH [{blob['module']}] {blob['path']} "
                    f"({blob['abspath']})"
                )
            else:
                missing += 1
                self.wrn(
                    f"MISSING  [{blob['module']}] {blob['path']} "
                    f"({blob['abspath']})"
                )

        total = len(blobs)
        self.inf(
            f'\n{ok}/{total} entries: OK'
            + (f', {mismatch} MISMATCH' if mismatch else '')
            + (f', {missing} MISSING' if missing else '')
        )

        if mismatch or missing:
            self.die(f'{mismatch} mismatched, {missing} missing blob(s)')

    def update(self, args):
        '''Add or refresh a single blob entry from a local file.

        Day-to-day counterpart to gen_mcux_blobs.py's bulk regeneration: a
        developer who just built/vendored one new or changed prebuilt binary
        (sitting at its normal in-tree path, NOT committed to the source repo)
        runs 'west blobs update <file>' to hash it and upsert the matching
        mcux_blobs.yml entry, without touching any other entry in that file.
        '''
        files = args.modules  # positional MODULE args double as FILE args here
        if not files:
            self.die('usage: west blobs update <file> [<file> ...]')

        overrides_given = args.version or args.description or args.click_through or args.type
        if len(files) > 1 and overrides_given:
            self.die(
                '--version/--description/--click-through/--type only apply to '
                'a single file (they would otherwise overwrite every file\'s '
                'entry with the same value); run update separately per file.'
            )

        prebuilt_root = self.prebuilt_root(args)
        manifests = self.discover_manifests(args)
        if not manifests:
            self.die(
                'No mcux_blobs.yml manifests found. For a brand-new repo, '
                'bootstrap one first (see gen_mcux_blobs.py) before using '
                "'west blobs update' to add further blobs to it."
            )

        # manifest_path -> {"blobs": [...], "name": module_name}; touched
        # manifests are only read once and written once even if several of the
        # given files belong to the same manifest.
        touched = {}

        for f in files:
            fpath = Path(f).expanduser().resolve()
            if not fpath.is_file():
                self.die(f'Not a file: {fpath}')

            try:
                sdk_path = fpath.relative_to(prebuilt_root).as_posix()
            except ValueError:
                self.die(
                    f'{fpath} is not under MCUX_PREBUILT_ROOT ({prebuilt_root}); '
                    "a blob's local file must sit at its normal in-tree path."
                )

            # Owning manifest = the one whose project directory contains this
            # file; pick the most specific (deepest) match if more than one.
            owner = None
            for name, manifest_dir, manifest_path in manifests:
                try:
                    fpath.relative_to(manifest_dir)
                except ValueError:
                    continue
                if owner is None or len(str(manifest_dir)) > len(str(owner[1])):
                    owner = (name, manifest_dir, manifest_path)
            if owner is None:
                self.die(
                    f'No mcux_blobs.yml owns {sdk_path}. For a brand-new repo, '
                    'bootstrap a manifest first (see gen_mcux_blobs.py).'
                )
            name, owner_manifest_dir, manifest_path = owner

            if manifest_path not in touched:
                with manifest_path.open(encoding='utf-8') as fh:
                    meta = yaml.safe_load(fh) or {}
                touched[manifest_path] = {
                    'name': name,
                    'blobs': list(meta.get('blobs') or []),
                }

            entry_list = touched[manifest_path]['blobs']
            existing = next((b for b in entry_list if b.get('path') == sdk_path), None)
            new_sha = sha256_of_file(fpath)

            if existing:
                old_sha = existing.get('sha256')
                existing['sha256'] = new_sha
                if args.version:
                    existing['version'] = args.version
                if args.description:
                    existing['description'] = args.description
                if args.click_through:
                    existing['click-through'] = True
                if args.type:
                    existing['type'] = args.type
                if old_sha == new_sha:
                    self.inf(f'[{name}] {sdk_path}: unchanged (hash already up to date)')
                else:
                    self.inf(f'[{name}] {sdk_path}: updated {old_sha} -> {new_sha}')
            else:
                # Seed fetcher/url/revision/license-path from an existing entry
                # in the same manifest -- all entries in one repo share those.
                template = entry_list[0] if entry_list else {}
                ext = fpath.suffix.lstrip('.')
                new_entry = {
                    'path': sdk_path,
                    'sha256': new_sha,
                    'type': args.type or ('lib' if ext in LIB_EXTS else 'img'),
                    'version': args.version or '1.0',
                    'license-path': template.get('license-path', '../COPYING-BSD-3'),
                }
                if template.get('fetcher'):
                    new_entry['fetcher'] = template['fetcher']
                new_entry['url'] = template.get('url', '')
                if template.get('repo-path') is not None or new_entry.get('fetcher') == 'git':
                    new_entry['repo-path'] = fpath.relative_to(owner_manifest_dir).as_posix()
                if template.get('revision'):
                    new_entry['revision'] = template['revision']
                if args.click_through:
                    new_entry['click-through'] = True
                new_entry['description'] = args.description or f'{name} blob {fpath.name}'
                entry_list.append(new_entry)
                self.inf(f'[{name}] {sdk_path}: NEW entry added (sha256 {new_sha})')

        for manifest_path, data in touched.items():
            manifest_path.write_text(emit_mcux_blobs_yaml(data['blobs']), encoding='utf-8')
            self.inf(f"Wrote {manifest_path} ({len(data['blobs'])} entries)")

        self.inf(
            '\nNext steps:\n'
            '  1. Copy the file(s) above into your local clone of the matching\n'
            "     blob repo (see each entry's 'url' in the manifest) at the same\n"
            "     'repo-path', then commit + push there.\n"
            '  2. Commit this mcux_blobs.yml change as part of your normal\n'
            '     source PR (it should be a small, single-entry diff).\n'
            '  Do NOT commit the binary file itself to this source repo.'
        )

    # ------------------------------------------------------------------
    # regen helpers
    # ------------------------------------------------------------------

    def _regen_allowed_exts(self, args, old_by_path=None):
        '''Extension allowlist for a regen directory scan.

        Self-adapting: whatever extensions a manifest's existing entries
        already use ARE this repo's legitimate blob types, so scanning by
        that set can never mistake a stray non-binary file (Makefile,
        CODEOWNERS, NOTICE, .editorconfig, ... none of which carry a
        tracked extension) for a blob. Falls back to LIB_EXTS only when
        there is no existing manifest to learn from (--init bootstrap).
        --init-suffix always extends whichever base applies, so a run can
        intentionally widen scope (e.g. adding .bin to a lib-only repo).
        '''
        exts = set()
        if old_by_path:
            exts |= {
                Path(p).suffix.lstrip('.').lower()
                for p in old_by_path if Path(p).suffix
            }
        if not exts:
            exts |= set(LIB_EXTS)
        exts |= {s.lstrip('.').lower() for s in getattr(args, 'init_suffix', [])}
        return exts

    def _regen_stage_one(self, args, sdk_src, repo_dest, sdk_path):
        '''Copy sdk_src -> repo_dest if missing OR its content differs.

        Returns True if a copy happened (or would happen, under --dry-run).
        Unlike a plain existence check, this re-syncs a blob-repo checkout
        whose staged copy has gone stale relative to the SDK tree (e.g. the
        SDK-tree binary was rebuilt after an earlier --stage run) -- staging
        only on 'file not present' would otherwise silently leave the old
        bytes in place with no warning.
        '''
        if repo_dest.is_file() and sha256_of_file(repo_dest) == sha256_of_file(sdk_src):
            return False  # already in sync
        if args.dry_run:
            self.inf(f'  [stage-dry] {sdk_path}')
        else:
            repo_dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(sdk_src, repo_dest)
            self.inf(f'  [staged]    {sdk_path}')
        return True

    def _regen_scan_dir(self, root, prebuilt_root, allowed_exts):
        '''Walk root for files whose extension is in allowed_exts.

        Returns a dict of sdk_path -> absolute Path, skipping anything not
        under prebuilt_root (so an sdk-relative 'path' can be computed) and
        skipping '.git' internals entirely.
        '''
        found = {}
        for fpath in root.rglob('*'):
            if not fpath.is_file():
                continue
            if '.git' in fpath.parts:
                continue
            ext = fpath.suffix.lstrip('.').lower()
            if ext not in allowed_exts:
                continue
            try:
                sdk_path = fpath.relative_to(prebuilt_root).as_posix()
            except ValueError:
                continue
            found[sdk_path] = fpath
        return found

    def _regen_find_blob_repo(self, module_name, manifest_url, explicit_map):
        '''Return a Path to the local blob-repo working copy, or None.

        Resolution order:
          1. Explicit --blob-repo MODULE=DIR overrides (already parsed into
             explicit_map by regen()).
          2. Auto-detect: scan sibling directories of the workspace root for
             any git repo whose 'origin' remote URL matches manifest_url
             (after stripping the .git suffix and ignoring https/ssh variance
             in the host part, since git insteadOf may rewrite the URL).
        '''
        # 1. explicit override
        if module_name in explicit_map:
            p = Path(explicit_map[module_name]).expanduser().resolve()
            if not p.is_dir():
                self.die(f'--blob-repo {module_name}={p}: directory not found')
            return p

        # 2. auto-detect by matching git remote URL of sibling directories
        # The canonical "repo name" from a URL is the last path component,
        # minus any .git suffix. We match by that alone so that github vs
        # bitbucket and https vs ssh all resolve to the same checkout.
        def repo_name_from_url(url):
            # ssh://git@host/path/name.git  ->  name
            # https://host/path/name        ->  name
            # git@host:path/name.git        ->  name
            name = url.rstrip('/').split('/')[-1]
            if ':' in name and '/' not in name:
                # scp-style: git@host:name.git
                name = name.split(':')[-1]
            return name.removesuffix('.git')

        target_name = repo_name_from_url(str(manifest_url))
        if not target_name:
            return None

        topdir = Path(self.topdir)
        for sibling in topdir.parent.iterdir():
            if sibling == topdir or not sibling.is_dir():
                continue
            git_dir = sibling / '.git'
            if not git_dir.exists():
                # Also check one level deeper (bare-style or workspace repos).
                continue
            # Check if any remote URL yields the same repo name.
            try:
                result = subprocess.run(
                    ['git', '-C', str(sibling), 'remote', '-v'],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    text=True,
                    check=False,
                )
                for line in result.stdout.splitlines():
                    parts = line.split()
                    if len(parts) >= 2:
                        if repo_name_from_url(parts[1]) == target_name:
                            return sibling.resolve()
            except OSError:
                continue

        # Try the topdir itself (blob repo directly alongside sdk tree).
        for sibling in topdir.iterdir():
            if not sibling.is_dir():
                continue
            if not (sibling / '.git').exists():
                continue
            try:
                result = subprocess.run(
                    ['git', '-C', str(sibling), 'remote', '-v'],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    text=True,
                    check=False,
                )
                for line in result.stdout.splitlines():
                    parts = line.split()
                    if len(parts) >= 2:
                        if repo_name_from_url(parts[1]) == target_name:
                            return sibling.resolve()
            except OSError:
                continue

        return None

    def regen(self, args):
        '''Reconcile mcux_blobs.yml manifests against local blob-repo checkouts.

        For each discovered manifest (filtered by MODULE args if given):
          1. Locate the blob-repo working copy (--blob-repo override or auto).
          2. (Optional, --stage) copy any blob present in the SDK tree but not
             yet in the blob repo to its mirrored repo-path.
          3. Reconcile the manifest against the blob repo:
               changed  - blob in repo differs from manifest sha256: update hash.
               added    - blob in repo not in manifest: append new entry.
               removed  - entry in manifest absent from repo AND sdk tree: drop
                          (unless --no-prune).
          4. Write the updated manifest (unless --dry-run).

        Byte source (--source):
          auto      - blob-repo copy preferred; fall back to sdk tree.
          blob-repo - only hash from blob-repo copy (error if missing).
          sdk-tree  - only hash from sdk tree (pre-migration convenience).

        The tool never runs git rm / commit / push. It only edits manifest
        files and (under --stage) copies binary files into the blob-repo tree.
        '''
        # Parse --blob-repo MODULE=DIR overrides.
        explicit_map = {}
        for spec in args.blob_repo:
            if '=' not in spec:
                self.die(f'--blob-repo: expected MODULE=DIR, got {spec!r}')
            mod, _, directory = spec.partition('=')
            explicit_map[mod.strip()] = directory.strip()

        prebuilt_root = self.prebuilt_root(args)
        manifests = self.discover_manifests(args)

        # ------------------------------------------------------------------
        # --init: resolve module names that have no manifest yet against the
        # west project list and inject them as synthetic manifest entries so
        # the per-manifest loop can bootstrap a fresh mcux_blobs.yml for them.
        # ------------------------------------------------------------------
        init_project_paths = {}  # module_name -> Path(project_abspath)
        if getattr(args, 'init', False):
            if not getattr(args, 'url', None):
                self.die('--init requires --url <blob-repo-url>')
            if not args.modules:
                self.die('--init requires at least one MODULE name')
            already = {n for n, _, _ in manifests}
            for mod_name in args.modules:
                if mod_name in already:
                    # Module already has a manifest; normal reconcile is enough.
                    continue
                proj_abspath = None
                try:
                    for proj in self.manifest.projects:
                        if proj.name == mod_name:
                            proj_abspath = getattr(proj, 'abspath', None)
                            break
                except Exception as e:  # noqa: BLE001
                    self.dbg(f'west project lookup for {mod_name!r} failed: {e}')
                if proj_abspath is None:
                    self.die(
                        f'--init: {mod_name!r} is not a known west project.\n'
                        f'Run "west list" to see available projects.')
                init_project_paths[mod_name] = Path(proj_abspath)
                # Inject a synthetic entry; the manifest file does not exist yet.
                # The per-manifest loop detects this via is_init.
                manifests.append(
                    (mod_name, Path(proj_abspath),
                     Path(proj_abspath) / MCUX_BLOBS_MANIFEST)
                )

        if not manifests:
            self.die('No mcux_blobs.yml manifests found.')

        # Filter by module names if given.
        if args.modules:
            all_names = {name for name, _, _ in manifests}
            # --init modules were already validated above; exclude them from
            # the unknown-module check so only genuine typos cause an error.
            unknown = set(args.modules) - all_names - set(init_project_paths)
            if unknown:
                self.die(
                    f'Unknown module(s): {", ".join(sorted(unknown))}\n'
                    f'Available modules: {", ".join(sorted(all_names))}')
            manifests = [(n, d, p) for n, d, p in manifests if n in args.modules]

        total_changed = total_added = total_removed = total_staged = 0

        for name, manifest_dir, manifest_path in manifests:
            self.inf(f'\n[{name}] {manifest_path}')

            # repo_path for a blob = path relative to manifest_dir (the module root).
            # This mirrors the source module layout rather than the full sdk-relative
            # path, so the blob repo has the same tree as the original module with no
            # redundant wrapper directory (e.g. blob repo root is _boards/... directly,
            # not examples/_boards/...).
            try:
                manifest_rel = manifest_dir.relative_to(prebuilt_root)
            except ValueError:
                manifest_rel = Path('.')

            def _to_repo_path(sp):
                try:
                    return Path(sp).relative_to(manifest_rel).as_posix()
                except ValueError:
                    return sp

            # Detect whether this is a bootstrap (--init) run for a project
            # that has no mcux_blobs.yml yet.
            is_init = name in init_project_paths and not manifest_path.exists()

            if is_init:
                # ------------------------------------------------------------------
                # --init path: the manifest does not exist yet.  Scan the project
                # directory for binary candidates and treat all of them as new.
                # ------------------------------------------------------------------
                self.inf(f'  [init] bootstrapping new manifest')
                old_entries = []
                template = {
                    'url': args.url,
                    'revision': getattr(args, 'blob_revision', 'main'),
                    'license-path': getattr(args, 'init_license_path', '../COPYING-BSD-3'),
                    'fetcher': getattr(args, 'init_fetcher', 'git'),
                    'version': '1.0',
                }
                manifest_url = args.url

                # Locate blob-repo checkout (uses --blob-repo override or auto).
                blob_repo_dir = self._regen_find_blob_repo(name, manifest_url, explicit_map)
                if blob_repo_dir is not None:
                    self.inf(f'  blob-repo: {blob_repo_dir}')
                elif args.stage:
                    self.wrn(
                        f'  [{name}] --stage requested but no blob-repo checkout found; '
                        f'use --blob-repo {name}=<dir> to specify one.'
                    )

                # Collect binary candidates from the project directory.
                init_exts = self._regen_allowed_exts(args)
                project_dir = init_project_paths[name]
                found = self._regen_scan_dir(project_dir, prebuilt_root, init_exts)
                init_blobs = sorted(found.items())   # list of (sdk_path_str, abs_fpath)
                self.inf(f'  [init] found {len(init_blobs)} binary candidate(s)')

                # Stage: copy SDK-tree binaries into the blob-repo checkout.
                if args.stage and blob_repo_dir is not None:
                    for sdk_path, src_fpath in init_blobs:
                        repo_dest = blob_repo_dir / _to_repo_path(sdk_path)
                        if self._regen_stage_one(args, src_fpath, repo_dest, sdk_path):
                            total_staged += 1

                # Build new_entries: every candidate becomes an 'added' entry.
                new_entries = []
                changed = []
                added = []
                removed = []
                for sdk_path, src_fpath in init_blobs:
                    # Hash from the staged blob-repo copy if available,
                    # otherwise from the SDK-tree original.
                    if blob_repo_dir and (blob_repo_dir / _to_repo_path(sdk_path)).is_file():
                        src_for_hash = blob_repo_dir / _to_repo_path(sdk_path)
                    else:
                        src_for_hash = src_fpath
                    new_sha = sha256_of_file(src_for_hash)
                    ext = src_fpath.suffix.lstrip('.')
                    new_entry = {
                        'path': sdk_path,
                        'sha256': new_sha,
                        'type': 'lib' if ext.lower() in LIB_EXTS else 'img',
                        'version': template['version'],
                        'license-path': template['license-path'],
                        'fetcher': template['fetcher'],
                        'url': template['url'],
                        'repo-path': _to_repo_path(sdk_path),
                    }
                    if template.get('revision'):
                        new_entry['revision'] = template['revision']
                    new_entry['description'] = f'{name} prebuilt {src_fpath.name}'
                    new_entries.append(new_entry)
                    added.append(sdk_path)
                    self.inf(f'  [added]     {sdk_path}')

            else:
                # ------------------------------------------------------------------
                # Normal reconcile path: load existing manifest and diff it
                # against the blob-repo working copy / SDK tree.
                # ------------------------------------------------------------------

                # Load existing manifest entries.
                try:
                    with manifest_path.open(encoding='utf-8') as fh:
                        meta = yaml.safe_load(fh) or {}
                except (OSError, yaml.YAMLError) as e:
                    self.err(f'  Failed to read {manifest_path}: {e}')
                    continue
                old_entries = list(meta.get('blobs') or [])
                if not old_entries:
                    self.wrn('  No blobs entries; skipping.')
                    continue

                # Extract shared manifest conventions from the first entry (used
                # when creating entries for blobs added from the blob repo).
                template = old_entries[0]
                manifest_url = template.get('url', '')
                if isinstance(manifest_url, list):
                    # Multi-URL list: use the first for repo-name matching.
                    manifest_url = manifest_url[0]

                # Locate the blob-repo checkout.
                blob_repo_dir = self._regen_find_blob_repo(name, manifest_url, explicit_map)
                if blob_repo_dir is None:
                    if args.source == 'blob-repo':
                        self.die(
                            f'  [{name}] Cannot find a local blob-repo checkout for '
                            f'url {manifest_url!r}. Use --blob-repo {name}=<dir>.'
                        )
                    elif args.source == 'auto':
                        self.wrn(
                            f'  [{name}] No blob-repo checkout found for url '
                            f'{manifest_url!r}; falling back to sdk-tree only.'
                        )
                else:
                    self.inf(f'  blob-repo: {blob_repo_dir}')

                # Build sdk_path -> entry dict from old manifest.
                old_by_path = {b['path']: dict(b) for b in old_entries}

                # ------------------------------------------------------------------
                # Step 1 (--stage): copy SDK-tree files to their mirrored
                # repo-path -- for every path the manifest already knows about
                # AND missing/stale (re-syncs a checkout whose staged copy has
                # since gone stale relative to a rebuilt SDK-tree binary; see
                # _regen_stage_one).
                # ------------------------------------------------------------------
                if args.stage and blob_repo_dir is not None:
                    for sdk_path, entry in sorted(old_by_path.items()):
                        sdk_src = prebuilt_root / sdk_path
                        if not sdk_src.is_file():
                            continue  # not in sdk tree either; nothing to stage
                        repo_dest = blob_repo_dir / _to_repo_path(sdk_path)
                        if self._regen_stage_one(args, sdk_src, repo_dest, sdk_path):
                            total_staged += 1

                # ------------------------------------------------------------------
                # Step 2: build the set of blobs in the blob-repo working copy,
                # and (separately) any brand-new binary candidates already
                # sitting in the SDK tree that the manifest doesn't know about
                # yet (a plain "drop a new .bin in and re-run regen" flow --
                # previously only 'west blobs update <file>' could add these).
                # Both scans use the same self-adapting extension allowlist
                # (see _regen_allowed_exts) instead of a hand-maintained
                # metadata-file denylist, so a stray Makefile/CODEOWNERS/NOTICE
                # sitting in the blob-repo checkout can never be mistaken for a
                # blob.
                # ------------------------------------------------------------------
                allowed_exts = self._regen_allowed_exts(args, old_by_path)

                repo_paths = set()
                if blob_repo_dir is not None:
                    raw_rp = set(self._regen_scan_dir(blob_repo_dir, blob_repo_dir, allowed_exts))
                    # Normalize to sdk-relative paths (same coordinate system as
                    # old_by_path keys and sdk_new_paths) so the discard and
                    # union operations work correctly when manifest_dir != prebuilt_root.
                    repo_paths = {(manifest_rel / rp).as_posix() for rp in raw_rp}

                sdk_new = self._regen_scan_dir(manifest_dir, prebuilt_root, allowed_exts)
                sdk_new_paths = {p for p in sdk_new if p not in old_by_path}

                # ------------------------------------------------------------------
                # Step 3: reconcile manifest entries against blob-repo content.
                # ------------------------------------------------------------------
                new_entries = []     # final reconciled entry list
                changed = []
                added = []
                removed = []
                repo_path_fixed = []

                # Process existing manifest entries.
                for sdk_path, entry in sorted(old_by_path.items()):
                    # Resolve the byte source.
                    repo_file = (blob_repo_dir / _to_repo_path(sdk_path)) if blob_repo_dir else None
                    sdk_file = prebuilt_root / sdk_path

                    if args.source == 'blob-repo':
                        src_file = repo_file if (repo_file and repo_file.is_file()) else None
                    elif args.source == 'sdk-tree':
                        src_file = sdk_file if sdk_file.is_file() else None
                    else:  # auto
                        if repo_file and repo_file.is_file():
                            src_file = repo_file
                        elif sdk_file.is_file():
                            src_file = sdk_file
                        else:
                            src_file = None

                    if src_file is None:
                        # Blob not found anywhere.
                        if args.no_prune:
                            self.wrn(f'  [missing]   {sdk_path} (kept, --no-prune)')
                            new_entries.append(entry)
                        else:
                            removed.append(sdk_path)
                            self.inf(f'  [removed]   {sdk_path}')
                        continue

                    new_sha = sha256_of_file(src_file)
                    old_sha = entry.get('sha256', '')
                    updated = dict(entry)
                    updated['sha256'] = new_sha
                    # Keep repo-path in sync with the module-relative layout.
                    # Existing entries written before the flat-layout migration
                    # may carry an sdk-relative repo-path (e.g. examples/_boards/...)
                    # -- normalise to the module-relative form (_boards/...).
                    if updated.get('repo-path') is not None:
                        new_rp = _to_repo_path(sdk_path)
                        if updated['repo-path'] != new_rp:
                            repo_path_fixed.append(sdk_path)
                            self.inf(f'  [rp-fixed]  {sdk_path}  {updated["repo-path"]}  ->  {new_rp}')
                            updated['repo-path'] = new_rp
                    new_entries.append(updated)
                    if new_sha != old_sha:
                        changed.append(sdk_path)
                        self.inf(f'  [changed]   {sdk_path}  {old_sha[:12]}..  ->  {new_sha[:12]}..')

                    # Remove from repo_paths: any remaining after this loop are new.
                    repo_paths.discard(sdk_path)

                # Remaining candidates -- blobs present in the blob repo but not
                # yet in the manifest, UNION brand-new SDK-tree binaries not yet
                # anywhere -- become new entries. Stage sdk-tree-only candidates
                # first (if requested) so the hash can be taken from whichever
                # source --source prefers.
                for sdk_path in sorted(repo_paths | sdk_new_paths):
                    repo_file = (blob_repo_dir / _to_repo_path(sdk_path)) if blob_repo_dir else None
                    sdk_file = prebuilt_root / sdk_path
                    repo_has_it = bool(repo_file and repo_file.is_file())
                    sdk_has_it = sdk_file.is_file()

                    if args.stage and blob_repo_dir is not None and sdk_has_it and not repo_has_it:
                        if self._regen_stage_one(args, sdk_file, repo_file, sdk_path):
                            total_staged += 1
                            repo_has_it = not args.dry_run

                    if args.source == 'blob-repo':
                        src_file = repo_file if repo_has_it else None
                    elif args.source == 'sdk-tree':
                        src_file = sdk_file if sdk_has_it else None
                    else:  # auto
                        src_file = repo_file if repo_has_it else (sdk_file if sdk_has_it else None)

                    if src_file is None:
                        # e.g. --source blob-repo but this candidate only exists
                        # in the sdk tree and --stage was not requested.
                        continue

                    ext = Path(sdk_path).suffix.lstrip('.')
                    new_sha = sha256_of_file(src_file)
                    new_entry = {
                        'path': sdk_path,
                        'sha256': new_sha,
                        'type': 'lib' if ext.lower() in LIB_EXTS else 'img',
                        'version': template.get('version', '1.0'),
                        'license-path': template.get('license-path', '../COPYING-BSD-3'),
                    }
                    if template.get('fetcher'):
                        new_entry['fetcher'] = template['fetcher']
                    new_entry['url'] = template.get('url', '')
                    if template.get('repo-path') is not None or new_entry.get('fetcher') == 'git':
                        new_entry['repo-path'] = _to_repo_path(sdk_path)
                    if template.get('revision'):
                        new_entry['revision'] = template['revision']
                    new_entry['description'] = f'{name} blob {Path(sdk_path).name}'
                    new_entries.append(new_entry)
                    added.append(sdk_path)
                    self.inf(f'  [added]     {sdk_path}')

            total_changed += len(changed)
            total_added += len(added)
            total_removed += len(removed)

            # Summary line for this manifest.
            self.inf(
                f'  -> {len(new_entries)} entries: '
                f'{len(changed)} changed, {len(added)} added, {len(removed)} removed'
                + (' (dry-run, not written)' if args.dry_run else '')
            )

            total_changed += len(repo_path_fixed)

            if not args.dry_run and (changed or added or removed or repo_path_fixed):
                manifest_path.write_text(
                    emit_mcux_blobs_yaml(new_entries), encoding='utf-8'
                )
                self.inf(f'  Wrote {manifest_path}')

        # Final summary across all manifests.
        self.inf(
            f'\nregen summary: '
            f'{total_changed} changed, {total_added} added, {total_removed} removed'
            + (f', {total_staged} staged' if args.stage else '')
            + (' [DRY RUN]' if args.dry_run else '')
        )

    def scan(self, args):
        '''Report which west projects still contain committed build-artifact binaries.

        Walks every west project directory for files with build-artifact
        extensions (.a .lib .o .obj .bin .so .dll .hex .axf .elf .out .srec),
        cross-references the discovered mcux_blobs.yml manifests, and classifies
        each project into one of three migration states:

          not-started  - has committed binaries, no mcux_blobs.yml
          in-progress  - has BOTH a mcux_blobs.yml AND committed binaries
          ported       - has a mcux_blobs.yml, no committed binaries left

        Default output: one row per project with committed binaries (not-started
        and in-progress), ranked by total binary size. Add --state all to also
        show fully-ported projects, or --state <state> to restrict.

        Add --files to list every individual binary found (path + size),
        grouped by project. Use -l/--allow-regex to filter by path.
        '''
        # ------------------------------------------------------------------ #
        # 1. Build west-project -> abspath map (longest-prefix matching).     #
        # ------------------------------------------------------------------ #
        projects = []   # list of {name, proj_path (ws-relative), abspath, owner}
        try:
            for proj in self.manifest.projects:
                abspath = getattr(proj, 'abspath', None)
                if not abspath:
                    continue
                proj_path = getattr(proj, 'path', None) or ''
                # A3: pick up owner from userdata (populated by submanifests).
                userdata = getattr(proj, 'userdata', None) or {}
                owner = userdata.get('owner', '') if isinstance(userdata, dict) else ''
                projects.append({
                    'name': getattr(proj, 'name', None) or Path(abspath).name,
                    'proj_path': proj_path.rstrip('/'),
                    'abspath': Path(abspath).resolve(),
                    'owner': owner,
                })
        except Exception as e:  # noqa: BLE001
            self.wrn(f'west project discovery skipped: {e}')

        # Sort longest-prefix first for match_project.
        projects.sort(key=lambda p: len(p['proj_path']), reverse=True)

        def match_project(fpath_abs):
            for proj in projects:
                try:
                    fpath_abs.relative_to(proj['abspath'])
                    return proj
                except ValueError:
                    continue
            return None

        # ------------------------------------------------------------------ #
        # 2. Collect manifests (which projects are already onboarded).        #
        # ------------------------------------------------------------------ #
        manifests_found = self.discover_manifests(args)
        onboarded = {manifest_dir.resolve() for _, manifest_dir, _ in manifests_found}

        # ------------------------------------------------------------------ #
        # 3. Find committed build-artifact binaries.              (A1: fast) #
        #                                                                     #
        # Instead of os.walk (which stats every file in a huge source tree), #
        # we call "git ls-files -- *.ext ..." per west project.  git reads   #
        # its packed index directly, which is O(index) not O(disk), so a     #
        # 100k-file repo like mcuxsdk takes ~0.1s not ~1s per project.       #
        # git also returns ONLY committed files, so a separate                #
        # git-tracking filter step (step 3.5 from earlier versions) is not   #
        # needed: fetched-back blobs that are .gitignored are never listed.  #
        #                                                                     #
        # Fall-back: if git ls-files fails (not a git repo, timeout, etc.)   #
        # we fall back to os.walk for that project only.                     #
        # ------------------------------------------------------------------ #
        scan_root = self.prebuilt_root(args)
        allow_re = re.compile(args.allow_regex) if getattr(args, 'allow_regex', None) else None

        # Extension patterns for git pathspecs (e.g. '*.a', '*.bin', ...).
        _ext_patterns = [f'*{ext}' for ext in SCAN_BINARY_EXTS]

        def _git_scan_project(proj_abspath: Path):
            """Return list of committed binary entries, or None on git failure."""
            try:
                result = subprocess.run(
                    ['git', 'ls-files', '-z', '--'] + _ext_patterns,
                    cwd=str(proj_abspath),
                    capture_output=True,
                    text=True,
                    timeout=60,
                )
                if result.returncode != 0:
                    return None
                paths = [p for p in result.stdout.split('\0') if p]
            except (OSError, subprocess.TimeoutExpired):
                return None

            entries = []
            for rel_path in paths:
                fpath = (proj_abspath / rel_path).resolve()
                try:
                    sdk_rel = fpath.relative_to(scan_root).as_posix()
                except ValueError:
                    sdk_rel = rel_path
                if allow_re and not allow_re.match(sdk_rel):
                    continue
                try:
                    size = fpath.stat().st_size
                except OSError:
                    size = 0
                entries.append({'path': sdk_rel, 'size': size})
            return entries

        def _walk_scan_project(proj_abspath: Path):
            """os.walk fallback when git ls-files is unavailable."""
            entries = []
            for dirpath, dirnames, filenames in os.walk(proj_abspath):
                dpath = Path(dirpath)
                dirnames[:] = [
                    d for d in dirnames
                    if d not in SCAN_EXCLUDE_DIR_PARTS
                    and not d.startswith('build')
                    and not any(p.search(d) for p in SCAN_EXCLUDE_DIR_PATTERNS)
                ]
                for fn in filenames:
                    ext = os.path.splitext(fn)[1].lower()
                    if ext not in SCAN_BINARY_EXTS:
                        continue
                    fpath = (dpath / fn).resolve()
                    try:
                        sdk_rel = fpath.relative_to(scan_root).as_posix()
                    except ValueError:
                        sdk_rel = fn
                    if allow_re and not allow_re.match(sdk_rel):
                        continue
                    try:
                        size = fpath.stat().st_size
                    except OSError:
                        size = 0
                    entries.append({'path': sdk_rel, 'size': size})
            return entries

        # per-project accumulator: abspath -> {name, proj_path, blobs: [...]}
        by_proj = {}
        unmatched = []   # files not belonging to any west project (unused for git scan)

        for proj in projects:
            proj_abs = proj['abspath']
            # Only scan directories that actually exist under the scan root.
            try:
                proj_abs.relative_to(scan_root)
            except ValueError:
                continue  # outside scan_root (e.g. the manifest repo itself)
            if not proj_abs.is_dir():
                continue

            entries = _git_scan_project(proj_abs)
            if entries is None:
                # git unavailable -- fall back to os.walk for this project
                entries = _walk_scan_project(proj_abs)

            if entries:
                by_proj[proj_abs] = {
                    'name': proj['name'],
                    'proj_path': proj['proj_path'],
                    'abspath': proj_abs,
                    'owner': proj.get('owner', ''),
                    'blobs': entries,
                }
        # (No step 3.5 needed: git ls-files only returns committed files.)

        # ------------------------------------------------------------------ #
        # 4. Classify each project and apply MODULE / --state filters.        #
        # ------------------------------------------------------------------ #
        # Optionally filter by positional MODULE args (matched against both
        # the west project name and its workspace-relative path).
        module_filter = set(args.modules) if args.modules else None

        # Validate module names early so a typo produces a helpful error
        # instead of silently showing an empty results table.
        if module_filter:
            all_proj_ids = (
                {p['name'] for p in projects}
                | {p['proj_path'] for p in projects}
            )
            unknown_mods = module_filter - all_proj_ids
            if unknown_mods:
                blob_module_names = sorted(n for n, _, _ in manifests_found)
                hint = (
                    f'Available blob modules: {", ".join(blob_module_names)}'
                    if blob_module_names
                    else 'No blob modules found in this workspace.'
                )
                self.die(
                    f'Unknown module(s): {", ".join(sorted(unknown_mods))}\n'
                    + hint
                )

        state_filter = getattr(args, 'state', None)
        # Default: show all three states so fully-ported repos are visible too.
        show_states = (
            {state_filter} if state_filter and state_filter != 'all'
            else {SCAN_STATE_NOT_STARTED, SCAN_STATE_IN_PROGRESS, SCAN_STATE_PORTED}
        )

        results = []
        for proj_abs, rec in by_proj.items():
            has_manifest = proj_abs in onboarded
            state = SCAN_STATE_IN_PROGRESS if has_manifest else SCAN_STATE_NOT_STARTED
            rec['state'] = state
            rec['has_manifest'] = has_manifest
            results.append(rec)

        # Also add fully-ported projects (manifest present, no committed bins)
        # when the user wants to see them.
        if SCAN_STATE_PORTED in show_states:
            ported_abspaths = {r['abspath'] for r in results}
            for _, manifest_dir, _ in manifests_found:
                mdir = manifest_dir.resolve()
                if mdir not in ported_abspaths:
                    # Find the matching west project entry for name/proj_path.
                    proj = match_project(mdir / 'placeholder')
                    results.append({
                        'name': proj['name'] if proj else mdir.name,
                        'proj_path': proj['proj_path'] if proj else str(mdir),
                        'abspath': mdir,
                        'blobs': [],
                        'state': SCAN_STATE_PORTED,
                        'has_manifest': True,
                    })

        # Apply MODULE filter.
        if module_filter:
            results = [
                r for r in results
                if r['name'] in module_filter or r['proj_path'] in module_filter
            ]

        # Apply state filter.
        results = [r for r in results if r['state'] in show_states]

        # Sort by binary size descending (ported projects have size 0).
        results.sort(key=lambda r: sum(b['size'] for b in r['blobs']), reverse=True)

        # ------------------------------------------------------------------ #
        # 5. Print results.                                                   #
        # ------------------------------------------------------------------ #
        show_files = getattr(args, 'files', False)
        by_owner   = getattr(args, 'by_owner', False)

        if not results and not unmatched:
            self.inf('No projects with committed build-artifact binaries found.')
            return

        # Helper: compute per-result size and blob count once.
        def _row_stats(r):
            total_size = sum(b['size'] for b in r['blobs'])
            return total_size, total_size / (1024 * 1024), len(r['blobs'])

        if not show_files:
            # A3: table columns include owner.
            col_proj  = 36
            col_owner = 22
            col_state = 13
            col_n     = 7
            col_mb    = 8
            header = (
                f"\n{'west_project':<{col_proj}} {'owner':<{col_owner}} "
                f"{'state':<{col_state}} {'blobs':>{col_n}} "
                f"{'MB':>{col_mb}}"
            )
            sep = '-' * (col_proj + col_owner + col_state + col_n + col_mb + 4)

            def _print_row(label, owner, state, n_blobs, mb):
                self.inf(
                    f"{label:<{col_proj}} {owner:<{col_owner}} "
                    f"{state:<{col_state}} {n_blobs:>{col_n},} "
                    f"{mb:>{col_mb}.1f}"
                )

            if by_owner:
                # Group rows under their owner; aggregate per-owner totals.
                from collections import defaultdict
                owner_groups = defaultdict(list)
                for r in results:
                    owner_groups[r.get('owner', '') or '(unknown)'].append(r)
                # Sort owners by total MB descending.
                sorted_owners = sorted(
                    owner_groups.items(),
                    key=lambda kv: sum(_row_stats(r)[0] for r in kv[1]),
                    reverse=True,
                )
                self.inf(header)
                self.inf(sep)
                for own, rows in sorted_owners:
                    tot_bytes = sum(_row_stats(r)[0] for r in rows)
                    tot_mb    = tot_bytes / (1024 * 1024)
                    tot_n     = sum(_row_stats(r)[2] for r in rows)
                    # owner aggregate line
                    _print_row(f'[{own}]', '', '', tot_n, tot_mb)
                    for r in sorted(rows, key=lambda x: _row_stats(x)[0], reverse=True):
                        _, mb, n_blobs = _row_stats(r)
                        _print_row(
                            '  ' + (r['proj_path'] or r['name']),
                            '', r['state'], n_blobs, mb,
                        )
            else:
                self.inf(header)
                self.inf(sep)
                for r in results:
                    _, mb, n_blobs = _row_stats(r)
                    _print_row(
                        r['proj_path'] or r['name'],
                        r.get('owner', '') or '',
                        r['state'], n_blobs, mb,
                    )

            if unmatched and (not module_filter):
                um_size = sum(u['size'] for u in unmatched) / (1024 * 1024)
                _print_row('(unmatched)', '', '', len(unmatched), um_size)

        else:
            # Per-file listing.
            for r in results:
                if not r['blobs']:
                    continue
                self.inf(
                    f"\n[{r['state']}] {r['proj_path'] or r['name']}"
                    + (f" ({r['owner']})" if r.get('owner') else '')
                    + (' (has mcux_blobs.yml)' if r['has_manifest'] else '')
                )
                for b in sorted(r['blobs'], key=lambda x: x['path']):
                    kb = b['size'] / 1024
                    self.inf(f"  {b['path']}  ({kb:.1f} KB)")

            if unmatched and (not module_filter):
                self.inf('\n[(unmatched -- no west project)]')
                for b in sorted(unmatched, key=lambda x: x['path']):
                    kb = b['size'] / 1024
                    self.inf(f"  {b['path']}  ({kb:.1f} KB)")

        # ------------------------------------------------------------------ #
        # 6. Summary line.                                                    #
        # ------------------------------------------------------------------ #
        not_started_n = sum(1 for r in results if r['state'] == SCAN_STATE_NOT_STARTED)
        in_progress_n = sum(1 for r in results if r['state'] == SCAN_STATE_IN_PROGRESS)
        ported_n      = sum(1 for r in results if r['state'] == SCAN_STATE_PORTED)
        total_blobs   = sum(len(r['blobs']) for r in results)
        total_size_mb = sum(b['size'] for r in results for b in r['blobs']) / (1024 * 1024)

        parts = []
        if not_started_n:
            parts.append(f'{not_started_n} not-started')
        if in_progress_n:
            parts.append(f'{in_progress_n} in-progress')
        if ported_n:
            parts.append(f'{ported_n} ported')

        self.inf(
            f'\n{", ".join(parts) if parts else "0 projects"}'
            + (f' | {total_blobs:,} binaries / {total_size_mb:.1f} MB'
               if total_blobs else '')
            + (f' | {len(unmatched)} unmatched' if unmatched and not module_filter else '')
        )

        # ------------------------------------------------------------------ #
        # 7. JSON / CSV output (A2).                                          #
        # ------------------------------------------------------------------ #
        import datetime
        ts = datetime.datetime.now(tz=datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

        scan_json = getattr(args, 'scan_json', None)
        scan_csv  = getattr(args, 'scan_csv', None)

        if scan_json or scan_csv:
            # Build serialisable rows (blobs list omitted; only aggregate stats).
            rows = []
            for r in results:
                _, mb, n_blobs = _row_stats(r)
                rows.append({
                    'proj_path':   r['proj_path'] or r['name'],
                    'name':        r['name'],
                    'owner':       r.get('owner', '') or '',
                    'state':       r['state'],
                    'blobs':       n_blobs,
                    'size_mb':     round(mb, 2),
                })

            if scan_json:
                payload = {
                    'generated': ts,
                    'scan_root': str(scan_root),
                    'summary': {
                        'not_started': not_started_n,
                        'in_progress': in_progress_n,
                        'ported':      ported_n,
                        'total_blobs': total_blobs,
                        'total_size_mb': round(total_size_mb, 2),
                        'unmatched': len(unmatched),
                    },
                    'projects': rows,
                    'unmatched': [
                        {'path': u['path'], 'size_bytes': u['size']}
                        for u in unmatched
                    ],
                }
                out = Path(scan_json).expanduser()
                out.parent.mkdir(parents=True, exist_ok=True)
                out.write_text(json.dumps(payload, indent=2), encoding='utf-8')
                self.inf(f'Wrote {out}')

            if scan_csv:
                fields = ['proj_path', 'name', 'owner', 'state', 'blobs', 'size_mb']
                out = Path(scan_csv).expanduser()
                out.parent.mkdir(parents=True, exist_ok=True)
                with out.open('w', newline='', encoding='utf-8') as fh:
                    w = csv.DictWriter(fh, fieldnames=fields, extrasaction='ignore')
                    w.writeheader()
                    w.writerows(rows)
                self.inf(f'Wrote {out}')

    def do_run(self, args, unknown):
        # accepts_unknown_args=True lets west use parse_known_args so that
        # a module name placed AFTER a flag (e.g. "regen --stage mcu-sdk-examples")
        # is not rejected by argparse before we can print a helpful error.
        # Recover any stray positional tokens as additional module names; reject
        # stray flags so typos like "--stge" still produce a clear error.
        if unknown:
            stray_flags = [u for u in unknown if u.startswith('-')]
            if stray_flags:
                self.die(f'unrecognised option(s): {" ".join(stray_flags)}')
            # Treat every remaining token as an extra module name.
            args.modules = list(args.modules) + list(unknown)

        self.dbg(f"subcmd: '{args.subcmd[0]}' modules: {args.modules}")

        subcmd = getattr(self, args.subcmd[0])

        if args.subcmd[0] != 'list' and args.format is not None:
            self.die('unexpected --format argument; this is a "west blobs list" option')

        subcmd(args)
