# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: Apache-2.0

'''
Process a build folder and generate an HTML dashboard covering memory
footprint, Kconfig values, and ELF statistics for an MCUXpresso SDK
application build.

This is the MCUXpresso SDK port of the Zephyr ``dashboard`` tool. Zephyr's
device-tree and sys-init pages have no analogue in the SDK build flow and
are omitted here.
'''

import argparse
import contextlib
import glob
import html
import io
import json
import logging
import os
import pickle
import re
import shutil
import subprocess
import sys
import webbrowser
from datetime import datetime
from functools import partial
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

import jinja2
from elftools.elf.constants import SH_FLAGS
from elftools.elf.elffile import ELFFile
from pygments.formatters import HtmlFormatter  # pylint: disable=E0611
from pygments.styles import get_style_by_name

try:
    import plotly.graph_objects as go
    from plotly.offline.offline import get_plotlyjs
    _plotly_available = True
except ImportError:
    _plotly_available = False


def generate_figure(data, depth=4):
    '''
    Build a Plotly sunburst chart from a size_report JSON tree.
    Mirrors Zephyr's ``scripts/footprint/plot.py:generate_figure``.
    '''
    if not _plotly_available:
        return None

    totalsize = data.get('total_size', 0)
    ids = []
    labels = []
    parents = []
    values = []
    hovertext = []

    def iter_node(node, parent=''):
        identifier = node.get('identifier')
        if identifier is None:
            return

        if identifier in ids:
            idx = 0
            while f'{identifier}_{idx}' in ids:
                idx += 1
            identifier = f'{identifier}_{idx}'

        ids.append(identifier)
        labels.append(node.get('name', ''))
        parents.append(parent)
        values.append(node.get('size', 0))

        details = []
        if totalsize > 0:
            details.append(f'percentage: {node.get("size", 0) / totalsize:.2%}')
        if 'address' in node:
            details.append(f'address: 0x{node.get("address"):08x}')
        if 'section' in node:
            details.append(f'section: {node.get("section")}')
        hovertext.append("<br>".join(details))

        for child in node.get('children', ()):
            iter_node(child, identifier)

    iter_node(data.get('symbols', {}))

    fig = go.Figure(
        go.Sunburst(
            ids=ids,
            labels=labels,
            parents=parents,
            values=values,
            hovertext=hovertext,
            branchvalues='total',
            maxdepth=depth,
        ),
        skip_invalid=True,
    )
    fig.update_layout(margin={'t': 0, 'l': 0, 'r': 0, 'b': 0})
    fig.update_traces(textfont={'size': 24})
    return fig

logger = logging.getLogger('dashboard')

# Set to match the CSS used in the HTML as it is set via CSS variable
# that we cannot access from Python script.
CSS_BS_TABLE_BG = '#f8f9fa'

# Constants for converting from bytes to human-friendly sizes.
MEMORY_UNIT_SIZES = {
    1073741824: 'GB',
    1048576: 'MB',
    1024: 'KB',
    1: 'Bytes',
}


def display_size(byte_cnt):
    '''
    Display a number of bytes in human-readable form with a size indicator.
    '''

    if byte_cnt in [None, '']:
        return ''

    compressed_bytes = byte_cnt
    unit = 'Bytes'
    for unit_size, unit_str in MEMORY_UNIT_SIZES.items():
        if abs(byte_cnt) >= unit_size:
            compressed_bytes = float(byte_cnt) / unit_size
            unit = unit_str
            break

    return f"{compressed_bytes:.1f} {unit}".replace('.0', '')


def elf_memory_summary(elf_file):
    '''
    Get a summary of memory use from the given ELF file.
    '''

    report = {'bss': 0, 'rodata': 0, 'rwdata': 0, 'text': 0, 'other': 0}

    with open(elf_file, "rb") as fd:
        elf = ELFFile(fd)

        for section in elf.iter_sections():
            flags = section.header['sh_flags']
            size = section.header['sh_size']
            sh_type = section.header['sh_type']

            if sh_type == 'SHT_NOBITS':
                report['bss'] += size
            elif sh_type == 'SHT_PROGBITS':
                if flags & SH_FLAGS.SHF_EXECINSTR:
                    report['text'] += size
                elif flags & SH_FLAGS.SHF_WRITE:
                    report['rwdata'] += size
                elif flags & SH_FLAGS.SHF_ALLOC:
                    report['rodata'] += size
                else:
                    report['other'] += size
            else:
                report['other'] += size

    return report


class McuxVersion:
    '''
    Class representing the MCUXpresso SDK version, loaded from the
    ``MCUX_VERSION`` file at the SDK root.
    '''

    FIELDS = ['current_year', 'version_major', 'version_minor']

    def __init__(self, sdk_base):
        self.current_year = None
        self.version_major = None
        self.version_minor = None

        version_file = sdk_base / 'MCUX_VERSION'
        if not version_file.is_file():
            return

        try:
            with open(version_file, encoding='utf-8') as f:
                version_data = f.readlines()
        except OSError as e:
            logger.error(f"Unable to read version information from {version_file}: {e}")
            return

        for version_line in version_data:
            if '=' not in version_line:
                continue
            field, value = version_line.split('=', 1)
            field = field.strip().lower()
            value = value.strip()
            if field in McuxVersion.FIELDS:
                setattr(self, field, value)

    def __str__(self):
        parts = [p for p in (self.current_year, self.version_major, self.version_minor) if p]
        return '.'.join(parts) if parts else 'unknown'


class McuxToolchain:
    '''
    Container for the build toolchain information.
    Extracted from the CMakeCCompiler.cmake file under the build tree.
    '''

    def __init__(self, build_path):
        self.cmake_c_compiler_id = None
        self.cmake_c_compiler_version = None

        cmake_glob = build_path / 'CMakeFiles' / '*' / 'CMakeCCompiler.cmake'
        cmake_file = glob.glob(str(cmake_glob))
        if cmake_file:
            cmake_file = cmake_file[0]
        else:
            return

        try:
            with open(cmake_file, encoding='utf-8') as f:
                lines = f.readlines()
        except OSError as e:
            logger.error(f"Unable to load CMakeCCompiler.cmake file {cmake_file}: {e}")
            return

        cmake_c_compiler_id_re = re.compile(r'\s*set\(CMAKE_C_COMPILER_ID\s+"(.*)"\)')
        cmake_c_compiler_version_re = re.compile(r'\s*set\(CMAKE_C_COMPILER_VERSION\s+"(.*)"\)')

        for line in lines:
            if match := cmake_c_compiler_id_re.match(line):
                self.cmake_c_compiler_id = match.group(1)
            if match := cmake_c_compiler_version_re.match(line):
                self.cmake_c_compiler_version = match.group(1)
            if self.cmake_c_compiler_id and self.cmake_c_compiler_version:
                break

    def __str__(self):
        if not self.cmake_c_compiler_id:
            return ''
        return f"{self.cmake_c_compiler_id} {self.cmake_c_compiler_version or ''}".strip()


class KconfigSymbol:
    '''
    Class representing a KconfigSymbol and its value in a given build.
    '''

    def __init__(self, name, visible, sym_type, value, src, loc, build):
        self.sym_type = sym_type
        self.visible = bool(visible == 'y')
        self.name = name
        self.value = value
        if sym_type == "string" and self.value is not None:
            self.value = f'"{self.value}"'
        self.src = src
        self.loc = loc
        self.build = build

    def loc_html(self):
        if self.loc and self.src in ['default', 'assign']:
            fn = os.path.relpath(self.loc[0], self.build.sdk_base)
            disp_fn = os.path.normpath(fn).replace("../", "")
            sym_loc = f'{disp_fn}:{self.loc[1]}'
        elif self.loc and self.src in ['select', 'imply']:
            if len(self.loc) > 1:
                sym_loc = " || ".join(f"({html.escape(loc)})" for loc in self.loc)
            else:
                sym_loc = html.escape(self.loc[0])
            sym_loc = f"<code>{sym_loc}</code>"
        elif self.loc is None and self.src == "default":
            sym_loc = "<i>(implicit)</i>"
        else:
            sym_loc = ''
        return sym_loc

    def src_html(self):
        if self.src == "unset":
            return ''
        if self.src == "default":
            return '<span class="badge bg-secondary">default</span>'
        if self.src == "assign":
            return '<span class="badge bg-primary">assigned</span>'
        if self.src == "select":
            return '<span class="badge bg-info">selected</span>'
        if self.src == "imply":
            return '<span class="badge bg-warning">implied</span>'
        return self.src


class McuxDashboard:
    '''
    Collect and process MCUXpresso SDK build artifacts to create the
    HTML dashboard.
    '''

    def __init__(
        self,
        sdk_base,
        build_path,
        output_path,
        bin_name,
        board=None,
        application=None,
        command=None,
        topdir=None,
        skip_memory_report=False,
    ):
        self.sdk_base = Path(sdk_base).resolve()
        self.bin_name = bin_name
        self.build_path = Path(build_path).resolve() if build_path else self.sdk_base / "build"
        self.output_path = Path(output_path).resolve() if output_path else self.build_path / "dashboard"

        self.elf_file = self.build_path / f"{self.bin_name}.elf"
        self.kconfig_file = self.build_path / ".config"

        self.board = board
        self.command = command
        self.topdir = Path(topdir).resolve() if topdir else self.sdk_base

        if application:
            app = Path(application)
            try:
                self.application = str(app.resolve().relative_to(self.sdk_base))
            except ValueError:
                self.application = str(app)
        else:
            self.application = None

        # Optional .bin file size.
        try:
            bin_file = self.build_path / f"{self.bin_name}.bin"
            bin_stats = bin_file.stat()
            self.bin_size_str = display_size(bin_stats.st_size)
        except OSError:
            self.bin_size_str = None

        # ELF file stats are required.
        elf_stats = self.elf_file.stat()
        self.elf_date_str = datetime.fromtimestamp(elf_stats.st_mtime).strftime("%Y-%m-%d %H:%M:%S")
        self.elf_size_str = display_size(elf_stats.st_size)

        self.toolchain = McuxToolchain(self.build_path)
        self.mcux_version = McuxVersion(self.sdk_base)

        self._init_kconfigs()

        self.memory_summary = elf_memory_summary(self.elf_file)

        # Create the memory reports if they are stale.
        self.skip_memory_report = skip_memory_report
        if not self.skip_memory_report:
            memory_report = self.output_path / "all_report.json"
            if not os.path.isfile(memory_report) or os.path.getmtime(
                memory_report
            ) < os.path.getmtime(self.elf_file):
                self._create_memory_reports()

    def _init_kconfigs(self):
        '''
        Load the kconfig trace information from the pickled data file.
        '''
        pickle_path = self.build_path / ".config-trace.pickle"
        if not pickle_path.is_file():
            logger.warning(f'Kconfig trace pickle not found at {pickle_path}; Kconfig page will be empty.')
            self.kconfigs = []
            return
        with open(pickle_path, 'rb') as f:
            trace_data = pickle.load(f)
        self.kconfigs = [KconfigSymbol(*sym, build=self) for sym in trace_data]
        self.kconfigs.sort(key=lambda kc: kc.name)

    def _create_memory_reports(self):
        '''
        Use the footprint size_report tool to create the ram/rom JSON data,
        then synthesize the combined "all" report.

        The MCUXpresso SDK ``size_report`` accepts a single target per
        invocation, uses ``--json`` as a literal path, and when called with
        target ``all`` it overwrites the output file on the second pass,
        so we only call it for ``rom`` and ``ram`` and build the combined
        view ourselves.
        '''
        logger.info("Creating memory reports (may take a few minutes).")

        self.output_path.mkdir(parents=True, exist_ok=True)

        size_report = self.sdk_base / "scripts" / "footprint" / "size_report"

        for target in ('rom', 'ram'):
            json_path = self.output_path / f"{target}_report.json"
            cmd = [
                sys.executable,
                str(size_report),
                '-k', str(self.elf_file),
                '-z', str(self.sdk_base.absolute()),
                f'--workspace={self.topdir}',
                '--json', str(json_path),
                '--quiet',
                '--output', str(self.output_path),
                target,
            ]
            logger.debug(' '.join(cmd))
            try:
                subprocess.check_call(cmd)
            except subprocess.CalledProcessError as e:
                logger.error(
                    f"Failed generating {target} memory size report (exit code {e.returncode}). "
                    + f"Command:\n{' '.join(e.cmd)}"
                )

        self._synthesize_all_report()

    def _synthesize_all_report(self):
        '''
        Build an ``all_report.json`` by wrapping the rom and ram trees under
        a combined root. Tags each subtree with a ``loc`` so the Top Ten
        list shows whether a symbol lives in RAM or ROM.
        '''
        all_json = self.output_path / "all_report.json"
        rom_json = self.output_path / "rom_report.json"
        ram_json = self.output_path / "ram_report.json"

        subtrees = []
        total = 0
        for label, src in (('ROM', rom_json), ('RAM', ram_json)):
            if not src.is_file():
                continue
            with open(src, encoding='utf-8') as fd:
                data = json.load(fd)
            symbols = data.get('symbols') or {}
            size = symbols.get('size', 0)
            total += size
            subtrees.append({
                'name': label,
                'identifier': label,
                'size': size,
                'loc': [label],
                'children': self._tag_loc(symbols.get('children', []), label),
            })

        combined = {
            'symbols': {
                'name': 'Root',
                'identifier': 'root',
                'size': total,
                'children': subtrees,
            },
            'total_size': total,
        }
        with open(all_json, 'w', encoding='utf-8') as fd:
            json.dump(combined, fd)

    @staticmethod
    def _tag_loc(nodes, label):
        '''Propagate a location tag down to leaf symbols for the Top Ten list.'''
        tagged = []
        for node in nodes:
            new = dict(node)
            children = node.get('children')
            if children:
                new['children'] = McuxDashboard._tag_loc(children, label)
            else:
                new['loc'] = [label]
            tagged.append(new)
        return tagged

    def _load_memory_report(self, mem_type):
        fname = self.output_path / f"{mem_type}_report.json"
        if not os.path.isfile(fname):
            logger.error(f'Memory report file "{fname}" not found.')
            return None

        with open(fname, encoding="utf-8") as fd:
            return json.load(fd)

    def _symbols_by_size(self, report, limit=None):
        if not report:
            return []

        symbol_list = []

        def flatten(symbols, lst):
            for symbol in symbols:
                children = symbol.get('children')
                if children:
                    flatten(children, lst)
                elif symbol['name'][0] != '(':
                    lst.append(symbol)

        flatten(report['symbols']['children'], symbol_list)

        symbol_list = sorted(symbol_list, key=lambda s: s['size'], reverse=True)

        if limit:
            symbol_list = symbol_list[0:limit]

        return symbol_list

    def _memory_report_template_context(self, mem_type, ctxt):
        report = self._load_memory_report(mem_type)

        def create_node(symbol, expanded=False):
            size = symbol['size']
            return (
                {
                    "expanded": expanded,
                    "data": {
                        "name": symbol['name'],
                        "size": size,
                        "displaySize": display_size(size),
                        "memoryType": [loc.upper() for loc in symbol.get('loc', [])],
                    },
                }
                if size
                else None
            )

        def add_children(node, children):
            if not children:
                return
            node['children'] = []
            for symbol in sorted(children, key=lambda c: c['name']):
                child_node = create_node(symbol)
                if not child_node:
                    continue
                node['children'].append(child_node)
                add_children(child_node, symbol.get('children'))

        def create_tree(report):
            tree = {}
            symbol = report.get('symbols')
            if symbol:
                tree['size'] = symbol['size']
                tree['tree'] = []
                node = create_node(symbol, expanded=True)
                tree['tree'].append(node)
                add_children(node, symbol.get('children'))
            return tree

        if report:
            tree = create_tree(report)
            ctxt[f'{mem_type}_report'] = json.dumps(tree)
            ctxt[f'{mem_type}_report_size'] = tree['size']

            if _plotly_available:
                figure = generate_figure(report)
                figure.update_layout(paper_bgcolor=CSS_BS_TABLE_BG, height=600)
                ctxt[f'{mem_type}_plot'] = figure.to_html(full_html=False, include_plotlyjs=False)
            else:
                ctxt[f'{mem_type}_plot'] = None
        else:
            ctxt[f'{mem_type}_report'] = None
            ctxt[f'{mem_type}_plot'] = None

        if mem_type == 'all':
            ctxt['top_ten'] = self._symbols_by_size(report, 10)

    def create_html(self):
        '''
        Generate all the HTML output.
        '''

        templates_path = Path(__file__).parents[0] / "templates"
        template_loader = jinja2.FileSystemLoader(searchpath=str(templates_path))
        env = jinja2.Environment(
            loader=template_loader, autoescape=True, trim_blocks=True, lstrip_blocks=True
        )
        env.filters['display_size'] = display_size

        # Create the output directory tree and copy bundled static assets.
        self.output_path.mkdir(parents=True, exist_ok=True)
        rpt_static = self.output_path / "static"
        shutil.copytree(Path(__file__).parent.resolve() / 'static', rpt_static, dirs_exist_ok=True)

        # Create the pygments CSS file.
        pygments_style = get_style_by_name('default')
        pygments_formatter = HtmlFormatter(style=pygments_style)
        pygments_css = pygments_formatter.get_style_defs('.highlight')
        with open(rpt_static / "css" / "pygments.css", 'w', encoding="utf-8") as fd:
            fd.write(pygments_css)

        # Create the plotly.js file if plotly was found.
        if _plotly_available:
            with open(rpt_static / "js" / "plotly.js", 'w', encoding="utf-8") as fd:
                fd.write(get_plotlyjs())

        # ---------------------------------
        # HTML: index.html
        # ---------------------------------

        template = env.get_template("index.html")
        context = {'build': self, 'title': 'Build Summary', 'current': 'home'}
        fname = self.output_path / "index.html"
        logger.info(f"Creating {fname}")
        with open(fname, 'w', encoding="utf-8") as fd:
            fd.write(template.render(**context))

        # ---------------------------------
        # HTML: kconfig.html
        # ---------------------------------

        template = env.get_template("kconfig.html")
        context = {
            'build': self,
            'title': 'Kconfig',
            'current': 'kconfig',
            'kconfig_browser': None,
        }
        fname = os.path.join(self.output_path, 'kconfig.html')
        logger.debug(f"Creating {fname}")
        with open(fname, 'w', encoding="utf-8") as fd:
            fd.write(template.render(**context))

        # ---------------------------------
        # HTML: memoryreport.html
        # ---------------------------------

        if not self.skip_memory_report:
            template = env.get_template("memoryreport.html")
            context = {
                'build': self,
                'title': 'Memory Report',
                'current': 'memory',
                'include_plotly_js': _plotly_available,
            }
            self._memory_report_template_context('all', context)
            self._memory_report_template_context('ram', context)
            self._memory_report_template_context('rom', context)
            fname = self.output_path / 'memoryreport.html'
            logger.debug(f"Creating {fname}")
            with open(fname, 'w', encoding="utf-8") as fd:
                fd.write(template.render(**context))

        # ---------------------------------
        # HTML: elfstats.html
        # ---------------------------------

        stat_file = self.build_path / f"{self.bin_name}.stat"
        if stat_file.is_file():
            with open(stat_file, encoding="utf-8") as fd:
                file_contents = fd.read()
        else:
            file_contents = self._elf_section_stats()

        template = env.get_template("textviewer.html")
        context = {
            'build': self,
            'title': 'ELF Stats',
            'current': 'elfstats',
            'file_contents': file_contents,
            'file_path': stat_file.absolute() if stat_file.is_file() else self.elf_file.absolute(),
        }
        fname = self.output_path / "elfstats.html"
        logger.debug(f"Creating {fname}")
        with open(fname, 'w', encoding='utf-8') as fd:
            fd.write(template.render(**context))

    def _elf_section_stats(self):
        '''
        Render an objdump-style section header table from the ELF file.
        '''
        lines = [f"Sections in {self.elf_file}:", ""]
        lines.append(f"{'Idx':>3}  {'Name':<22} {'Size':>10}  {'VMA':>18}  "
                     f"{'LMA':>18}  {'Offset':>10}  Flags")
        with open(self.elf_file, "rb") as fd:
            elf = ELFFile(fd)
            for idx, section in enumerate(elf.iter_sections()):
                hdr = section.header
                flags_val = hdr['sh_flags']
                flag_chars = ''
                if flags_val & SH_FLAGS.SHF_ALLOC:
                    flag_chars += 'A'
                if flags_val & SH_FLAGS.SHF_WRITE:
                    flag_chars += 'W'
                if flags_val & SH_FLAGS.SHF_EXECINSTR:
                    flag_chars += 'X'
                lines.append(
                    f"{idx:>3}  {section.name:<22} {hdr['sh_size']:>10}  "
                    f"0x{hdr['sh_addr']:016x}  0x{hdr['sh_addr']:016x}  "
                    f"0x{hdr['sh_offset']:08x}  {flag_chars}"
                )
        return '\n'.join(lines)

    def clean_up(self):
        for mem_type in ['ram', 'rom', 'all']:
            fname = self.output_path / f"{mem_type}_report.json"
            fname.unlink(missing_ok=True)

    def open_browser(self):
        handler = partial(SimpleHTTPRequestHandler, directory=str(self.output_path))
        server = HTTPServer(("127.0.0.1", 0), handler)
        url = f"http://127.0.0.1:{server.server_port}/index.html"
        logger.info("Serving dashboard at %s (Ctrl+C to stop)", url)
        webbrowser.open(url)
        with contextlib.suppress(KeyboardInterrupt):
            server.serve_forever()


def parse_args():
    parser = argparse.ArgumentParser(allow_abbrev=False)

    parser.add_argument("build", help="Build directory", nargs='?', default="build")
    parser.add_argument("--output", help="Output directory for index.html")
    parser.add_argument("--sdk-base", default=".", help="MCUXpresso SDK base directory")
    parser.add_argument("--bin-name", required=True, help="Application binary name (no extension)")
    parser.add_argument("--board", default=None, help="Target board name")
    parser.add_argument("--app-source-dir", default=None, help="Application source directory")
    parser.add_argument("--command", default=None, help="Build command used to produce this build")
    parser.add_argument("--topdir", default=None, help="West workspace top directory")
    parser.add_argument(
        "--skip-memory-report",
        action="store_true",
        help="Skip the memory report to generate faster",
    )
    parser.add_argument(
        "--no-clean", action="store_true", help="Do not remove temporary memory map json data"
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="Print extra debugging information"
    )
    parser.add_argument("-q", "--quiet", action="store_true", help="Print nothing to the console.")
    parser.add_argument(
        "--open", action="store_true", help="Open the default web browser to the dashboard."
    )
    return parser.parse_args()


def main():
    args = parse_args()

    if args.verbose:
        logging.basicConfig(level=logging.DEBUG)
        logger.setLevel(logging.DEBUG)
    elif not args.quiet:
        logging.basicConfig(level=logging.INFO)
        logger.setLevel(logging.INFO)

    build = McuxDashboard(
        sdk_base=args.sdk_base,
        build_path=args.build,
        output_path=args.output,
        bin_name=args.bin_name,
        board=args.board,
        application=args.app_source_dir,
        command=args.command,
        topdir=args.topdir,
        skip_memory_report=args.skip_memory_report,
    )
    build.create_html()

    if not args.no_clean:
        build.clean_up()

    if args.open:
        build.open_browser()


if __name__ == "__main__":
    main()
