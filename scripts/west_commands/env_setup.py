#!/usr/bin/python3

# Copyright 2024-2026 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import os
import platform
import re
import hashlib
import shutil
from pathlib import Path
from west.commands import WestCommand
from west import configuration as config

# Files we ship under ecosystem/scripts/resources/portable_ruby_nt/ for the
# legacy directory format. Used to filter them out when scanning the dir for
# a sidecar file whose *name* is the target version.
_LEGACY_PACKAGE_FILES = frozenset({
    '7zr.exe', 'command', 'md5.bat', 'readme.md', 'ruby.7z', 'setup.bat',
})
_VERSION_NAME_RE = re.compile(r'^\d+(\.\d+)+([-+][\w.+-]*)?$')

SCRIPT_DIR = Path(__file__).parent.parent
PORTABLE_RUBY_BASE = 'https://formulae.brew.sh/formula/portable-ruby'
ECOSYSTEM_RESOURCES = SCRIPT_DIR.parent / 'ecosystem' / 'scripts' / 'resources'
GUI_RESOURCES = SCRIPT_DIR / 'resources'


def _ruby_exe_name():
    return 'ruby.exe' if os.name == 'nt' else 'ruby'


def _find_extracted_version_dirs(root):
    """Yield each <root>/<version>/ subdir that holds a ruby executable."""
    if not root.is_dir():
        return
    for child in sorted(root.iterdir()):
        if child.is_dir() and (child / 'bin' / _ruby_exe_name()).is_file():
            yield child


def _set_active_version(root, version):
    """Write the top-level current.<version> marker; remove any previous one."""
    for old in root.glob('current.*'):
        try:
            old.unlink()
        except OSError:
            pass
    (root / f'current.{version}').touch()


def _resolve_resource(name, override=None):
    """Return the resource path, or None if not found.

    If `override` is given, search only that directory. Otherwise, search
    ecosystem/scripts/resources first (heavy archives, original format)
    and fall back to scripts/resources (slim archives produced by
    ecosystem/scripts/build_portable_ruby/build_portable_ruby.py).
    """
    if override is not None:
        candidate = Path(override) / name
        return candidate if candidate.exists() else None
    for base in (ECOSYSTEM_RESOURCES, GUI_RESOURCES):
        candidate = base / name
        if candidate.exists():
            return candidate
    return None

def get_file_md5(filename):
    digest = hashlib.md5()
    with open(filename, "rb") as f:
        while chunk := f.read(2**18):
            digest.update(chunk)
    return digest.hexdigest()

class PlatformNotSupported(Exception):
    def __init__(self, arch, sys_name, msg=None, *args, **kwargs):
        msg = msg or f"""portable_ruby does not support {arch}_{sys_name}. You can only use it under Windows, x86_64-linux and arm64-darwin.
For other Unix-like systems, we strongly suggest you use https://github.com/rbenv/rbenv.
For more details, please refer GUIDE, or contact us."""
        super().__init__(msg, *args, **kwargs)

class InstallRuby(WestCommand):
    def __init__(self):
        super().__init__(
            'install_ruby',
            'Install portable ruby with gems for guiproject generation.',
            ''
        )
        self.install_path = Path.home()
        self.resource_path = None

    def do_add_parser(self, parser_adder):
        parser = parser_adder.add_parser(self.name,
                                         help=self.help,
                                         description=self.description)
        parser.add_argument('-p', '--path', action='store', default=None, help='The path to hold portable ruby. the default location is user home path.')
        parser.add_argument('-r', '--resource-path', action='store', default=None,
                            help='Directory containing the portable Ruby resource '
                                 '(portable_ruby_nt.exe or portable_ruby_<arch>.tar.xz). '
                                 'Defaults to searching ecosystem/scripts/resources then scripts/resources.')

        return parser

    def install_ruby_for_windows(self):
        """Install portable Ruby on Windows.

        Supports two on-disk formats, in priority order:
          1. ecosystem/scripts/resources/portable_ruby_nt/  — legacy directory
             with setup.bat + ruby.7z + 7zr.exe + md5.bat. Defers to setup.bat.
          2. scripts/resources/portable_ruby_nt.exe        — slim self-extracting
             7-Zip console SFX produced by build_portable_ruby.py. Internally
             carries a <version>/{bin,lib} layout so multiple installed
             versions coexist under <install>/portable-ruby/<version>/.
        """
        cwd = os.getcwd()
        ruby_root = self.install_path / 'portable-ruby'

        legacy = _resolve_resource('portable_ruby_nt', override=self.resource_path)
        if legacy is not None and legacy.is_dir() and (legacy / 'ruby.7z').is_file():
            os.chdir(cwd)
            return self._install_legacy_dir(ruby_root, legacy)

        sfx = _resolve_resource('portable_ruby_nt.exe', override=self.resource_path)
        if sfx is not None and sfx.is_file():
            file_md5 = get_file_md5(sfx)
            existing = self._find_version_with_marker(ruby_root, file_md5)
            if existing:
                self.inf(f'Portable Ruby {existing.name} already installed (md5 match)')
                _set_active_version(ruby_root, existing.name)
                os.chdir(cwd)
                return (existing / 'bin').as_posix()

            ruby_root.mkdir(parents=True, exist_ok=True)
            before = {d.name for d in _find_extracted_version_dirs(ruby_root)}
            # 7-Zip console SFX: -y auto-accepts, -o<dir> sets the extract root.
            # Pass `-o.` and use cwd= so install paths containing spaces or
            # special characters never appear on the command line. The SFX
            # archive has <version>/{bin,lib} at its root, so this lands at
            # <install>/portable-ruby/<version>/.
            self.run_subprocess([str(sfx), '-y', '-o.'], cwd=str(ruby_root))

            version_dir = self._detect_extracted_version(ruby_root, before)
            if version_dir is None:
                self.err(f'No <version>/bin/ruby.exe found under {ruby_root} after extraction')
                os.chdir(cwd)
                return None

            (version_dir / file_md5).touch()
            _set_active_version(ruby_root, version_dir.name)
            bin_path = (version_dir / 'bin').as_posix()
            self.inf(
                f'Portable Ruby {version_dir.name} installed at {bin_path}. '
                f'Add it to your user PATH if it is not already.'
            )
            os.chdir(cwd)
            return bin_path

        searched = (str(self.resource_path) if self.resource_path
                    else 'ecosystem/scripts/resources or scripts/resources')
        self.err(f'No portable Ruby resource found in {searched}')
        return None

    def _find_version_with_marker(self, ruby_root, file_md5):
        """Return the version dir that already contains the given md5 marker, or None."""
        for vd in _find_extracted_version_dirs(ruby_root):
            if (vd / file_md5).is_file():
                return vd
        return None

    def _detect_extracted_version(self, ruby_root, before):
        """Identify the version dir produced by the most recent extraction.

        `before` is the set of version names that existed before extracting.
        Picks the dir whose name first appeared in the post-extract listing.
        Falls back to "most recently modified" only if nothing new appeared
        (i.e. the archive overwrote an existing version dir).

        We can't use mtime as the primary signal because 7-Zip SFX and tar
        preserve the *archive's* original timestamps, so a freshly-installed
        version may have an older mtime than versions installed earlier.
        """
        after = list(_find_extracted_version_dirs(ruby_root))
        fresh = [d for d in after if d.name not in before]
        if len(fresh) > 1:
            self.err(f'Archive produced multiple new version dirs: '
                     f'{[d.name for d in fresh]}')
            return None
        if fresh:
            return fresh[0]
        # Overwrite case: no new name appeared; pick the latest-touched dir.
        if after:
            return max(after, key=lambda d: d.stat().st_mtime)
        return None

    def _install_legacy_dir(self, ruby_root, legacy_dir):
        """Install the legacy ecosystem package format (directory with ruby.7z
        + 7zr.exe + setup.bat + ...). The package itself doesn't carry its
        Ruby version in any of the bundled files, so the install pipeline
        looks for a sidecar empty file whose *name* is the version (e.g.
        "3.1.2") in the same directory.

        Bypasses setup.bat / md5.bat — we extract directly into
        <ruby_root>/<version>/ to keep the layout aligned with the new SFX.
        """
        version = self._read_legacy_version(legacy_dir)
        if version is None:
            self.err(
                f'No version sidecar file found in {legacy_dir}. '
                f'Add an empty file whose name is the target Ruby version '
                f'(e.g. an empty file literally named "3.1.2") so the '
                f'installer knows which subdir to extract into.'
            )
            return None

        archive = legacy_dir / 'ruby.7z'
        extractor = legacy_dir / '7zr.exe'
        if not extractor.is_file():
            self.err(f'7zr.exe missing under {legacy_dir}')
            return None

        file_md5 = get_file_md5(archive)
        existing = self._find_version_with_marker(ruby_root, file_md5)
        if existing:
            self.inf(f'Portable Ruby {existing.name} already installed (md5 match)')
            _set_active_version(ruby_root, existing.name)
            return (existing / 'bin').as_posix()

        target = ruby_root / version
        if target.exists():
            shutil.rmtree(target)
        target.mkdir(parents=True)
        # 7zr archive layout is flat (bin/ + lib/ at top). Run with cwd=target
        # and -o. so paths with spaces never appear on the command line; the
        # extracted tree lands directly at <ruby_root>/<version>/{bin,lib}/.
        self.run_subprocess([str(extractor), 'x', str(archive), '-o.', '-y'],
                            cwd=str(target))

        if not (target / 'bin' / _ruby_exe_name()).is_file():
            self.err(f'Ruby executable not found under {target} after extraction')
            return None

        (target / file_md5).touch()
        _set_active_version(ruby_root, version)
        bin_path = (target / 'bin').as_posix()
        self.inf(
            f'Portable Ruby {version} installed at {bin_path}. '
            f'Add it to your user PATH if it is not already.'
        )
        return bin_path

    def _read_legacy_version(self, legacy_dir):
        """Find a sidecar file whose *name* is a version (digits + dots)."""
        for entry in legacy_dir.iterdir():
            if not entry.is_file():
                continue
            if entry.name in _LEGACY_PACKAGE_FILES:
                continue
            if _VERSION_NAME_RE.match(entry.name):
                return entry.name
        return None

    def install_ruby_for_linux(self, sys_arch):
        return self._for_posix(sys_arch)

    def install_ruby_for_darwin(self, sys_arch):
        return self._for_posix(sys_arch)

    def do_run(self, args, unknown_args):
        if args.path:
            input_path = Path(args.path).resolve()
            if not input_path.exists():
                self.wrn(f'{args.path} does not exist, will create it.')
                input_path.mkdir(parents=True, exist_ok=True)
            self.install_path = input_path

        if args.resource_path:
            resource_path = Path(args.resource_path).resolve()
            if not resource_path.is_dir():
                self.die(f'--resource-path {args.resource_path} is not an existing directory')
            self.resource_path = resource_path

        arch = platform.machine()
        sys_name = platform.system()
        try:
            if arch in ['x86_64', 'AMD64']:
                if sys_name == 'Windows':
                    self.ruby_bin = self.install_ruby_for_windows()
                elif sys_name == 'Linux':
                    self.ruby_bin = self.install_ruby_for_linux('x86_64-linux')
                else:
                    raise PlatformNotSupported(arch, sys_name)
            elif arch in ['arm64']:
                if sys_name == 'Darwin':
                    self.ruby_bin = self.install_ruby_for_darwin('arm64-darwin')
                else:
                    raise PlatformNotSupported(arch, sys_name)
            else:
                raise PlatformNotSupported(arch, sys_name)
        except PlatformNotSupported as exec:
            print(str(exec))
            self.ruby_bin = None
        except Exception as exec:
            print(str(exec))
            self.ruby_bin = None
        finally:
            if not self.ruby_bin:
                self.die("Failed to install portable_ruby")
            config.update_config('env', 'ruby', self.ruby_bin)

    def _for_posix(self, sys_arch):
        archive = _resolve_resource(f'portable_ruby_{sys_arch}.tar.xz',
                                    override=self.resource_path)
        if archive is None:
            searched = (str(self.resource_path) if self.resource_path
                        else 'ecosystem/scripts/resources or scripts/resources')
            self.err(f'portable_ruby_{sys_arch}.tar.xz not found in {searched}')
            return None

        ruby_root = self.install_path / 'portable-ruby'
        file_md5 = get_file_md5(archive)

        existing = self._find_version_with_marker(ruby_root, file_md5)
        if existing:
            self.inf(f'Portable Ruby {existing.name} already installed (md5 match)')
            _set_active_version(ruby_root, existing.name)
            return (existing / 'bin').as_posix()

        self.banner(f"Start extract portable-ruby for {sys_arch}, "
                    f"it was created based on {PORTABLE_RUBY_BASE}")
        ruby_root.mkdir(parents=True, exist_ok=True)
        before = {d.name for d in _find_extracted_version_dirs(ruby_root)}
        # The tarball ships portable-ruby/<version>/{bin,lib,...}; unpacking
        # into install_path drops it at <install>/portable-ruby/<version>/.
        shutil.unpack_archive(archive, extract_dir=self.install_path)

        version_dir = self._detect_extracted_version(ruby_root, before)
        if version_dir is None:
            self.err(f'No <version>/bin/ruby found under {ruby_root} after extraction')
            return None

        (version_dir / file_md5).touch()
        _set_active_version(ruby_root, version_dir.name)
        ruby_bin = (version_dir / 'bin').as_posix()
        sys_rb = shutil.which("ruby")
        if sys_rb and ruby_bin not in sys_rb:
            self.inf(f"""The active ruby is {sys_rb}
Please append following line in your shell profile like .zshrc or .bashrc:
  export PATH={ruby_bin}:$PATH{os.linesep}""")
        return ruby_bin
