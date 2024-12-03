# Copyright (c) 2020 Nordic Semiconductor ASA
# Copyright 2024 NXP
#
# SPDX-License-Identifier: Apache-2.0

import argparse
from pathlib import Path
from shutil import rmtree

from west.commands import WestCommand
from west import log

from zcmake import run_cmake

EXPORT_DESCRIPTION = '''\
This command registers the current MCUX SDK installation as a CMake
config package in the CMake user package registry.

In Windows, the CMake user package registry is found in:
HKEY_CURRENT_USER\\Software\\Kitware\\CMake\\Packages\\

In Linux and MacOS, the CMake user package registry is found in:
~/.cmake/packages/'''


class McuxSdkExport(WestCommand):

    def __init__(self):
        super().__init__(
            'mcuxsdk-export',
            # Keep this in sync with the string in west-commands.yml.
            'export MCUX SDK installation as a CMake config package',
            EXPORT_DESCRIPTION,
            accepts_unknown_args=False)

    def do_add_parser(self, parser_adder):
        parser = parser_adder.add_parser(
            self.name,
            help=self.help,
            formatter_class=argparse.RawDescriptionHelpFormatter,
            description=self.description)
        return parser

    def do_run(self, args, unknown_args):
        # The 'share' subdirectory of the top level mcuxsdk repository.
        share = Path(__file__).parents[2] / 'share'

        run_cmake_export(share / 'mcuxsdk-package' / 'cmake')

def run_cmake_export(path):
    # Run a package installation script.
    #
    # Filtering out lines that start with -- ignores the normal
    # CMake status messages and instead only prints the important
    # information.

    lines = run_cmake(['-P', str(path / 'mcuxsdk_export.cmake')],
                      capture_output=True)
    msg = [line for line in lines if not line.startswith('-- ')]
    log.inf('\n'.join(msg))

def remove_if_exists(pathobj):
    if pathobj.is_file():
        log.inf(f'- removing: {pathobj}')
        pathobj.unlink()
    elif pathobj.is_dir():
        log.inf(f'- removing: {pathobj}')
        rmtree(pathobj)
