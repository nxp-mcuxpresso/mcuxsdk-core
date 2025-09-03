# Copyright (c) 2018 Open Source Foundries Limited.
# Copyright 2019 Foundries.io
# Copyright (c) 2020 Nordic Semiconductor ASA
# Copyright 2024, 2025 NXP
#
# SPDX-License-Identifier: Apache-2.0

'''west "sdk_debug", "sdk_debugserver", and "sdk_attach" commands.'''

from textwrap import dedent

from west.commands import WestCommand

from run_common import add_parser_common, do_run_common


class SdkDebug(WestCommand):

    def __init__(self):
        super(SdkDebug, self).__init__(
            'sdk_debug',
            # Keep this in sync with the string in west-commands.yml.
            'flash and interactively debug a Zephyr application',
            dedent('''
            Connect to the board, flash the program, and start a
            debugging session. Use "west attach" instead to attach
            a debugger without reflashing.'''),
            accepts_unknown_args=True)
        self.runner_key = 'debug-runner'  # in runners.yaml

    def do_add_parser(self, parser_adder):
        return add_parser_common(self, parser_adder)

    def do_run(self, my_args, runner_args):
        do_run_common(self, my_args, runner_args)


class SdkDebugServer(WestCommand):

    def __init__(self):
        super(SdkDebugServer, self).__init__(
            'sdk_debugserver',
            # Keep this in sync with the string in west-commands.yml.
            'connect to board and launch a debug server',
            dedent('''
            Connect to the board and launch a debug server which accepts
            incoming connections for debugging the connected board.

            The debug server binds to a known port, and allows client software
            started elsewhere to connect to it and debug the running
            Zephyr image.'''),
            accepts_unknown_args=True)
        self.runner_key = 'debug-runner'  # in runners.yaml

    def do_add_parser(self, parser_adder):
        return add_parser_common(self, parser_adder)

    def do_run(self, my_args, runner_args):
        do_run_common(self, my_args, runner_args)


class SdkAttach(WestCommand):

    def __init__(self):
        super(SdkAttach, self).__init__(
            'sdk_attach',
            # Keep this in sync with the string in west-commands.yml.
            'interactively debug a board',
            "Like \"west sdk_debug\", but doesn't reflash the program.",
            accepts_unknown_args=True)
        self.runner_key = 'debug-runner'  # in runners.yaml

    def do_add_parser(self, parser_adder):
        return add_parser_common(self, parser_adder)

    def do_run(self, my_args, runner_args):
        do_run_common(self, my_args, runner_args)
