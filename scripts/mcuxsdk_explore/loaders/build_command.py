# Copyright 2025 NXP
# SPDX-License-Identifier: BSD-3-Clause

import pprint
import sys
import pathlib
import os
import re
import datetime
import time

sys.path.append(f'{pathlib.Path(__file__).parent.resolve()}/../..')
from misc import sdk_project_target

class BuildCommandDataLoader():
    def __init__(self, manifest_root_path, core_root_path):
        self.manifest_root_path = manifest_root_path
        self.core_root_path = core_root_path

        self.types = [
            ('raw_build_command',),
            ('example','path'),
            ('board','name'),
            ('device','name'),
            ('toolchain',),
            ('config',),
            ('core','id'),
            ('sysbuild',),
        ]

    def load(self):
        build_commands = self.get_all_build_commands()
        return self.parse_build_commands(build_commands)

    def get_all_build_commands(self):
        match_cases = list()
        op = sdk_project_target.MCUXRepoProjects()
        match_cases = op.search_app_targets(app_path='examples',
                                            board_cores_filter=[r'r@.']
                                           )
        if os.path.isdir(os.path.normpath(self.core_root_path+'/examples_int')):
            match_cases.extend(op.search_app_targets(app_path='examples_int',
                                                     board_cores_filter=[r'r@.']
                                                    )
                              )
        return [case.build_cmd for case in match_cases]

    def parse_build_commands(self, commands):
        build_commands = list()
        data = dict()
        for command in commands:
            data[('raw_build_command',)]=None
            data[('example','path')]=None
            data[('board','name')]=None
            data[('device','name')]=None
            data[('toolchain',)]=None
            data[('config',)]=None
            data[('core','id')]=None
            data[('sysbuild',)]=None
            data[('raw_build_command',)]=command

            tokens = re.split(' |=', command)
            if '--sysbuild' not in tokens[4]:
                data[('example','path')]=tokens[4]
                data[('sysbuild',)]='False'
            else:
                data[('example','path')]=tokens[5]
                data[('sysbuild',)]='True'
            if '--toolchain' in tokens:
                i = tokens.index('--toolchain')
                data[('toolchain',)]=tokens[i+1]
            if '--config' in tokens:
                i = tokens.index('--config')
                data[('config',)]=tokens[i+1]
            if '-b' in tokens:
                i = tokens.index('-b')
                data[('board','name')]=tokens[i+1]
            if '--device' in tokens:
                i = tokens.index('--device')
                data[('device','name')]=tokens[i+1]
            if '-Dcore_id' in tokens:
                i = tokens.index('-Dcore_id')
                data[('core','id')]=tokens[i+1]
            build_commands.append(data)
            data = dict()
        return build_commands

if __name__ == "__main__":

    current_dir = os.getcwd().replace('\\','/')
    manifest_path = current_dir + '/../../../../manifest'
    core_path = current_dir + '/../../../../mcuxsdk'

    start_time = time.time()

    build_data = BuildCommandDataLoader(manifest_path, core_path)
    data = build_data.load()

    end_time = time.time()
    print(f'Build command data loading: {str(datetime.timedelta(seconds=end_time - start_time))}')

    pprint.pp(len(data))
