# Copyright 2025 NXP
# SPDX-License-Identifier: BSD-3-Clause

from west.commands import WestCommand
import os
import os.path
from textwrap import dedent
import sys
import pathlib

sys.path.append(f'{pathlib.Path(__file__).parent.resolve()}/../mcuxsdk_explore/commands')
import explore_command as e

class McuxsdkExplore(WestCommand):
    def __init__(self):
        super().__init__(
            name='explore',
            help='Interactive visualization of MCUXpresso SDK data.',
            description=dedent('''Visualization of MCUXpresso SDK data and build command selection.'''))

    def do_add_parser(self, parser_adder):
        parser = parser_adder.add_parser(self.name,
                                 help=self.help,
                                 description=self.description)
        return parser

    def do_run(self, args, unknown):
        west_topdir = os.path.realpath(self.topdir).replace('\\','/')
        core_root_path = west_topdir + '/mcuxsdk'
        e.RunExplorer(self.manifest.repo_abspath, core_root_path)
