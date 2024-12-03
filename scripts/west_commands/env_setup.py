#!/usr/bin/python3

import os
from pathlib import Path
from west.commands import WestCommand
from west import configuration as config

script_dir = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))

class InstallRuby(WestCommand):
    def __init__(self):
        super().__init__(
            'install_ruby',
            'Install portable ruby with gems for guiproject generation.',
            ''
        )

    def do_add_parser(self, parser_adder):
        parser = parser_adder.add_parser(self.name,
                                         help=self.help,
                                         description=self.description)

        return parser

    def do_run(self, args, unknown_args):
        # TODO Use rbenv to help users install ruby in linux/macos
        if os.name != 'nt':
            self.die("Sorry, install_ruby only support Windows platform now, for linux or macos, please refer "
                  "https://github.com/rbenv/rbenv")
        cwd = os.getcwd()
        install_script_path = Path(script_dir) / 'resources/portable_ruby_nt/setup.bat'
        if not install_script_path.is_file():
            self.die(f"Cannot find {install_script_path.as_posix()}, please run 'west update sdk_generator' and try again")
        self.run_subprocess([install_script_path.as_posix()], shell=True)

        if os.name == 'nt':
            config.update_config('env', 'ruby', 'C:\\portable_ruby\\bin')
        os.chdir(cwd)
