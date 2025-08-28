# Copyright 2024-2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import os, sys
import argparse
import shutil
import logging
from pathlib import Path
from west.commands import WestCommand
from west.configuration import config
from export_app.cmake_app import CmakeApp
from export_app.cmake_parser import cmparser

SCRIPT_DIR = Path(__file__).parent.parent
sys.path.append(SCRIPT_DIR.as_posix())
from misc import sdk_project_target

_ARG_SEPARATOR = '--'
SDK_ROOT_DIR = SCRIPT_DIR.parent
DOC_URL = 'https://mcuxpresso.nxp.com/mcuxsdk/latest/html/develop/sdk/example_development.html#freestanding-examples'
DEFAULT_BOARD_FOLDERS=[f"{SDK_ROOT_DIR.name}/examples/"]

USAGE = f'''\
west export_app [-h] [source_dir] [-b board_id] [-DCMAKE_VAR=VAL] [-o OUTPUT_DIR] [--build]
The script will directly generate all files to OUTPUT_DIR, so please make sure the directory is empty.
You can use -Dcore_id=xxx to export multi-core example. When use '--build' feature, you can 
pass other parameters to west build command, like '--config', '--toolchain', etc.
To know what is freestanding example and how it works, see
{DOC_URL}
'''


class BoardCopyFolderAction(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):
        current = getattr(namespace, self.dest, None)
        if current is None:
            current = []

        if not values:
            setattr(namespace, self.dest, DEFAULT_BOARD_FOLDERS)
        else:
            setattr(namespace, self.dest, values)

class ExportApp(WestCommand):
    def __init__(self):
        super().__init__(
            'export_app',
            'Create a freestanding application',
            f'Create a freestanding application from sdk repository example.',
            accepts_unknown_args=True
        )
        self.core_id = None

    def do_add_parser(self, parser_adder):
        parser = parser_adder.add_parser(
            self.name,
            help=self.help,
            formatter_class=argparse.RawDescriptionHelpFormatter,
            description=self.description,
            usage=USAGE)
        parser.add_argument('-b', '--board', nargs=None, default=None, help="board id like mimxrt700evk")
        parser.add_argument('--toolchain', dest='toolchain', action='store',
                           default='armgcc', help='Specify toolchain')
        parser.add_argument('-o', '--output-dir', default=None,
                            help='output directory to hold the freestanding project')
        parser.add_argument('--bf', dest='board_copy_folders', action=BoardCopyFolderAction, nargs='*',
                            help='Copy board related files')
        # Only for internal use
        parser.add_argument('--build', action="store_true", default=False, help=argparse.SUPPRESS)
        parser.add_argument('--debug', action="store_true", default=config.getboolean('export_app', 'debug', fallback=False), help=argparse.SUPPRESS)
        return parser
    
    def do_run(self, args, remainder):
        self.args = args
        self._setup_logging(self.args.debug)
        # To align with west build usage
        self._parse_remainder(remainder)
        self._sanity_precheck()
        self._app_precheck()
        self.entry_app = CmakeApp(self.source_dir, self.output_dir, self.cmake_variables, self.extra_variables, 'main_app', self.misc_options)
        self.entry_app.run()
        self.banner(f'Successfully create the freestanding project, see {self.entry_app.dest_list_file}.')
        if self.args.build:
            self.banner('Start building the project')
            for l_cmd in self.entry_app.build_cmds():
                ret = self.run_subprocess(l_cmd, cwd=SDK_ROOT_DIR.as_posix())
                print(' '.join(l_cmd))
            if ret.returncode != 0:
                self.die("Build Failed!", exit_code=ret.returncode)
        else:
            self.banner('you can use following command to build it.')
            for l_cmd in self.entry_app.build_cmds():
                print(' '.join(l_cmd))

    def _parse_remainder(self, remainder):
        self.args.source_dir = None
        self.args.cmake_opts = None
        self.cmake_variables = {'CONFIG_TOOLCHAIN': self.args.toolchain}
        if self.args.board:
            self.cmake_variables['board'] = self.args.board

        try:
            # Only one source_dir is allowed, as the first positional arg
            if remainder[0] != _ARG_SEPARATOR:
                self.args.source_dir = remainder[0]
                remainder = remainder[1:]
            # Only the first argument separator is consumed, the rest are
            # passed on to CMake
            if remainder[0] == _ARG_SEPARATOR:
                remainder = remainder[1:]
            if remainder:
                self.args.cmake_opts = remainder
                for opt in self.args.cmake_opts:
                    if not opt.startswith('-D'):
                        continue
                    _ = opt.replace('-D', '').split('=')
                    if len(_) == 1:
                        self.cmake_variables[_[0]] = ''
                    else:
                        self.cmake_variables[_[0]] = opt.replace(f'-D{_[0]}=', '')
        except IndexError:
            pass

    def _sanity_precheck(self):
        self.check_force(cmparser, 'Cannot get a valid cmake file parser.')
        app = self.args.source_dir
        self.check_force(
            os.path.isdir(app),
            'source directory {} does not exist'.format(app))
        self.check_force(
            'CMakeLists.txt' in os.listdir(app),
            "{} doesn't contain a CMakeLists.txt".format(app))
        self.check_force(
            'example.yml' in os.listdir(app),
            "{} doesn't contain a example.yml".format(app))
        if self.args.output_dir:
            out = self.args.output_dir
        elif config_out := config.get('export_app', 'output_dir', fallback=None):
            out = config_out
        else:
            self.die('You must specify output directory with "-o" option or set it in west config')
        if (os.path.isdir(out)) and (len(os.listdir(out)) != 0):
            self.wrn(f"Output directory: {out} is not empty.")

        self.source_dir = Path(app).resolve()
        self.output_dir = Path(out).resolve()
        if config.get('export_app', 'clean_output_dir', fallback=False) and self.output_dir.exists():
            self.dbg('Clean output directory first...')
            shutil.rmtree(self.output_dir)

    def _app_precheck(self):
        sdk_project_target.MCUXAppTargets.config_internal_data()
        op = sdk_project_target.MCUXRepoProjects()
        self.board = self.args.board
        self.extra_variables = {}
        self.misc_options = {
            'main_output': self.output_dir,
            'cmake_opts': self.args.cmake_opts,
            'debug': self.args.debug,
        }
        if not self.board:
            if self.args.build:
                self.wrn("--build is only valid when you specify board/core")
                self.args.build = False
            if self.args.board_copy_folders:
                self.wrn('--bf is only valid when you specify board/core')
            return
        if 'core_id' in self.cmake_variables:
            self.core_id = self.cmake_variables['core_id']
        # Hardcode for board_root
        self.extra_variables['board_root'] = self.source_dir.relative_to(SDK_ROOT_DIR).parts[0] + '/_boards'
        board_core = self.board
        if self.core_id:
            board_core = board_core + '@' + self.core_id
        matched_app = op.search_app_targets(app_path=self.source_dir.as_posix(), board_cores_filter=[board_core])
        target_apps = list(set([app.name for app in matched_app]))
        self.check_force(matched_app,
                         f'Cannot find any app match your input, please ensure following command can get a valid output\
                          {os.linesep}west list_project -p {self.source_dir} -b {board_core}')
        self.misc_options['target_apps'] = target_apps
        if self.args.board_copy_folders:
            self.misc_options['board_copy_folders'] = self.args.board_copy_folders

    def _setup_logging(self, debug):
        if debug:
            logging.getLogger("export_app").setLevel(logging.DEBUG)
            level = logging.DEBUG
        else:
            level = logging.INFO
        logging.basicConfig(
            level=level,
            format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
            datefmt="%H:%M:%S",
            force=True
        )

    def check_force(self, cond, msg):
        if not cond:
            self.die(msg)
