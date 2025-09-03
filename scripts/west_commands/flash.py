# Copyright (c) 2018 Open Source Foundries Limited.
# Copyright 2019 Foundries.io
# Copyright (c) 2020 Nordic Semiconductor ASA
# Copyright 2024, 2025 NXP
#
# SPDX-License-Identifier: Apache-2.0

'''west "sdk_flash" command'''

from west.commands import WestCommand

from run_common import add_parser_common, do_run_common, get_build_dir
from build_helpers import load_domains


class SdkFlash(WestCommand):

    def __init__(self):
        super(SdkFlash, self).__init__(
            'sdk_flash',
            # Keep this in sync with the string in west-commands.yml.
            'flash and run a binary on a board',
            "Permanently reprogram a board's flash with a new binary.",
            accepts_unknown_args=True)
        self.runner_key = 'flash-runner'  # in runners.yaml

    def do_add_parser(self, parser_adder):
        return add_parser_common(self, parser_adder)

    def do_run(self, my_args, runner_args):
        build_dir = get_build_dir(my_args)
        domains = load_domains(build_dir).get_domains(my_args.domain,
                                                      default_flash_order=True)
        do_run_common(self, my_args, runner_args, domains=domains)
