# Copyright 2024-2025 NXP
#
# SPDX-License-Identifier: Apache-2.0

import os, sys
import argparse
from pathlib import Path
from west.commands import WestCommand
from export_app.cmake_app import CmakeApp
from export_app.cmake_parser import cmparser

SCRIPT_DIR = Path(__file__).parent.parent
sys.path.append(SCRIPT_DIR.as_posix())
from misc import sdk_project_target

_ARG_SEPARATOR = '--'
SDK_ROOT_DIR = SCRIPT_DIR.parent
DOC_URL = 'https://mcuxpresso.nxp.com/mcuxsdk/latest/html/develop/sdk/example_development.html#freestanding-examples'

USAGE = f'''\
west export_app [-h] [source_dir] [-b board_id] [-DCMAKE_VAR=VAL] [-o OUTPUT_DIR] [--build]
The script will directly generate all files to OUTPUT_DIR, so please make sure the directory is empty.
You can use -Dcore_id=xxx to export multi-core example. When use '--build' feature, you can 
pass other parameters to west build command, like '--config', '--toolchain', etc.
To know what is freestanding example and how it works, see
{DOC_URL}
'''

class ExportApp(WestCommand):
    def __init__(self):
        super().__init__(
            'export_app',
            'Create a freestanding application',
            f'Create a freestanding application from sdk repository example.',
            accepts_unknown_args=True
        )
        self.core_id = None
        self.general_export = False
        self.target_apps = []

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
        parser.add_argument('-o', '--output-dir', required=True,
                            help='output directory to hold the freestanding project')
        # Only for internal use
        parser.add_argument('--build', action="store_true", default=False, help=argparse.SUPPRESS)
        return parser
    
    def do_run(self, args, remainder):
        self.args = args
        # To align with west build usage
        self._parse_remainder(remainder)
        self._sanity_precheck()
        self._app_precheck()
        self.entry_app = CmakeApp(self.source_dir, self.output_dir, self.cmake_variables, self.extra_variables, False, self.target_apps)
        self.entry_app.run()
        self.banner(f'Successfully create the freestanding project, see {self.entry_app.dest_list_file}.')
        if self.args.build:
            self.banner('Start building the project')
            for l_cmd in self.all_l_build_cmd():
                ret = self.run_subprocess(l_cmd, cwd=SDK_ROOT_DIR.as_posix())
                print(' '.join(l_cmd))
            if ret.returncode != 0:
                self.die("Build Failed!", exit_code=ret.returncode)
        else:
            self.banner('you can use following command to build it.')
            for l_cmd in self.all_l_build_cmd():
                print(' '.join(l_cmd))

    def l_build_cmd(self, extra_args=[]):
        board_var = self.board if self.board else "<board_id>"
        cmd_list = ['west', 'build', '-b', board_var, '--toolchain', self.args.toolchain,
                    '-p', 'always', self.entry_app.dest_list_file.parent.as_posix(),
                    '-d', (self.output_dir/'build').as_posix(),
                    ]
        if self.entry_app.is_sysbuild:
            cmd_list.append('--sysbuild')
        if self.args.cmake_opts:
            cmd_list.extend(self.args.cmake_opts)
        if extra_args:
            cmd_list.extend(extra_args)
        return cmd_list
    
    def all_l_build_cmd(self):
        result = [self.l_build_cmd()]
        for conf_file in self.entry_app.custom_conf_files:
            result.append(self.l_build_cmd([f'-DCONF_FILE={conf_file}']))
        return result

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
        out = self.args.output_dir
        if (os.path.isdir(out)) and (len(os.listdir(out)) != 0):
            self.wrn(f"f'Output directory {out} is not empty.")

        self.source_dir = Path(app).resolve()
        self.output_dir = Path(out).resolve()

    def _app_precheck(self):
        sdk_project_target.MCUXAppTargets.config_internal_data()
        op = sdk_project_target.MCUXRepoProjects()
        self.board = self.args.board
        self.extra_variables = {}
        if not self.board:
            self.general_export = True
            if self.args.build:
                self.wrn("--build is only valid when you specify board")
                self.args.build = False
            return
        if 'core_id' in self.cmake_variables:
            self.core_id = self.cmake_variables['core_id']
        # Hardcode for board_root
        self.extra_variables['board_root'] = self.source_dir.relative_to(SDK_ROOT_DIR).parts[0] + '/_boards'
        board_core = self.board
        if self.core_id:
            board_core = board_core + '@' + self.core_id
        matched_app = op.search_app_targets(app_path=self.source_dir.as_posix(), board_cores_filter=[board_core])
        self.target_apps = list(set([app.name for app in matched_app]))
        self.check_force(matched_app,
                         f'Cannot find any app match your input, please ensure following command can get a valid output\
                          {os.linesep}west list_project -p {self.source_dir} -b {board_core}')

    def check_force(self, cond, msg):
        if not cond:
            self.die(msg)
