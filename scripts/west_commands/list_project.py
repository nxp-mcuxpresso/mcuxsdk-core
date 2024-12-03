# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

from west.commands import WestCommand, Verbosity
import re
import os
import sys
import logging
from west.configuration import config

script_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)))
sdk_root_dir = os.path.abspath(os.path.join(script_dir, '..'))
sys.path.append(os.path.join(script_dir))

from misc import *
from misc import sdk_project_target
# import misc

LIST_PROJECT_USAGE = '''
Example:
    west list_project -p examples/src/driver_examples/lpuart/interrupt -o test.yml

Data Source
        # examples/_boards/evkbmimxrt1170, board default targets
        board.toolchains:
        - +armgcc@debug

        # examples/driver_examples/lpuart/interrupt
        lpuart_interrupt:
          ....
          boards:
            ....
            # Keep with the board default targets
            evkbmimxrt1170@cm7: []
            # Add armgcc debug target comparing to its board default targets
            - +armgcc@debug
            frdmke17z512:
            # Remove the armgcc debug target comparing to its board default targets
            - -armgcc@debug

Filter String format
- by using different string to achive the include/exclude,  exact match or regex match
{}

Output Format
- Output the matched projects into json/yaml file if files ends with .json or .yml
- Output the matched projects into robot framework file if files ends with .robot
    - In visual studio code, install the plugin "Robot Framework Language Server" 
      to get the syntax highlight and interactive test case run feature

'''.format(sdk_project_target.MCUXAppTargets.config_filter.__doc__)

def config_get(option, fallback):
    return config.get('list_project', option, fallback=fallback)

def config_getboolean(option, fallback):
    return config.getboolean('list_project', option, fallback=fallback)

class ListProject(WestCommand):
    def __init__(self):
        super().__init__(
            name='list_project',
            help='List projects and targets',
            description='List projects and targets'
        )

    def do_add_parser(self, parser_adder):# -> Any:
        parser = parser_adder.add_parser(
            self.name, help=self.help, description=self.description, usage=LIST_PROJECT_USAGE
        )

        parser.add_argument('-p', '--app_path',     action="append", type=str, required=True, default=[],
                                                    help= 'Path regex to match examples.yml in its dir or child-dirs. -p pathA -p pathB. Glob pattern match. -p example/src/driver_examples/** to match all driver_exmaples.  Note in shell, wrap them by ", otherwise it will be parsed shell itself.')
        parser.add_argument('-b', '--board',        nargs='+', action="extend", type=str, default=[],
                                                    help='boards to build, default to include all boards. -b frdmk22f evkmimxrt1170@cm7')
        parser.add_argument('--shield',             nargs='+', action="extend", type=str, default=[], help='shield to build')
        parser.add_argument('-t', '--toolchain',    nargs='+', action="extend", choices=['iar', 'armgcc', 'mdk', 'xtensa', 'codewarrior', 'riscvllvm'], default=[],
                                                    help='Toolchains to build, the default value is armgcc, e.g, -t armgcc iar')
        parser.add_argument('-c', '--config',       nargs='+', action="extend", default=[],
                                                    help='Targets to build, the default value is release. e.g, -c release debug')
        parser.add_argument('-l', '--list_format',  action='store', choices=['none', 'cmd', 'silent_cmd'], default=None,
                                                    help='List format for matched projects.')
        parser.add_argument('-o', '--output_file',  action='store', default=None, help='Output file name. Must ends with .yml or .json')
        parser.add_argument(      '--cmake_invoke', action='store_true', default=False, help='If invoked by cmake, the target field will be ignored so that all available targets will be printed out.')
        parser.add_argument('--pick_one_target',    action='store_true', default=False, help='Default False, if set, only pick one target for one project and skip others')
        parser.add_argument('-v', '--verbose',      action='store_true', default=False, help='Level of logs. Default is INFO. -v means DEBUG')
        parser.add_argument('--validate',           action='store_true', default=False, help='Validate example.yml')

        return parser

    def do_run(self, args, unknow) -> None:
        mcux_log_init(logging.DEBUG if args.verbose else logging.INFO)
        # Search for the testcase
        op = sdk_project_target.MCUXRepoProjects()
        output_format = args.list_format or config_get('list_format', 'cmd')
        is_validate_example_yml = args.validate or config_getboolean('validate', False)
        match_cases = []
        for app_path in args.app_path:
            match_cases.extend(
                op.search_app_targets(
                    app_path=app_path,
                    board_cores_filter=args.board,
                    shields_filter=args.shield,
                    toolchains_filter=args.toolchain,
                    targets_filter=args.config if not args.cmake_invoke else [],
                    is_pick_one_target_for_app=args.pick_one_target,
                    validate=is_validate_example_yml
                )
            )
        # Export data when necessary
        if args.output_file:
            op.dump_to_file(args.output_file, match_cases)

        # List the output
        if output_format == 'silent_cmd':
            op.silent_print_apps(match_cases)
        elif output_format == 'cmd':
            op.pretty_print_apps(match_cases)
        elif output_format == 'none':
            pass

        # Return the matched cases
        if args.cmake_invoke:
            if set(args.config) & set([item.target for item in match_cases]):
                exit(0)
            else:
                mcux_banner(f'Start of Project Target Report')
                mcux_error(f'[{args.app_path[0]}][{args.board[0]}][{args.toolchain[0]}][{args.config[0]}] not found in [{len(match_cases)}] available targets:' + '\n' + "\n".join(["- " + str(idx) + " " + item.target for idx, item in enumerate(match_cases)]))
                mcux_banner(f'End of Project Target Report')
                exit(-1)
        exit(0)
