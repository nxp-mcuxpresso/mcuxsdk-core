# Copyright 2025 NXP
# SPDX-License-Identifier: BSD-3-Clause

import pprint
import sys
import pathlib
import os
import multiprocessing as mp
from multiprocessing import Manager
import datetime
import time
import yaml

sys.path.append(f'{pathlib.Path(__file__).parent.resolve()}')
import build_command as bcl

class ExampleDataLoader():
    def __init__(self, manifest_root_path, core_root_path):
        self.manifest_root_path = manifest_root_path
        self.core_root_path = core_root_path

        self.types = [
            ('example','category'),
            ('example','path'),
            ('example','name')
        ]

    def load(self, example_paths=None):
        if example_paths:
            pass
        else:
            self.build_command_data = bcl.BuildCommandDataLoader(self.manifest_root_path, self.core_root_path)
            build_command_data = self.build_command_data.load()
            example_paths = []
            for x in build_command_data:
                example_paths.append(x[('example','path')])
            example_paths = list(sorted(set(example_paths)))
        return self.load_files_parallel(example_paths)

    def load_files_parallel(self, files, num_processes=None):
        if num_processes is None:
            num_processes = mp.cpu_count()
        with Manager() as manager:
            shared_list = manager.list()
            lock = manager.Lock()
            args = [(filepath, shared_list, lock) for filepath in files]
            with mp.Pool(processes=num_processes) as pool:
                pool.map(self.load_single_file, args)
            return list(shared_list)

    def load_single_file(self, args):
        example_path, shared_list, lock = args
        with open(self.core_root_path + '/' + example_path + '/example.yml', 'r', encoding="utf-8") as file:
            example_data = yaml.safe_load(file)
            for example_name in example_data.keys():
                if 'section-type' not in example_data[example_name].keys():
                    break
                if example_data[example_name]['section-type'] not in ['application', 'library']:
                    break
                if 'category' not in example_data[example_name]['contents']['document'].keys():
                    break
                data_record = dict()
                data_record[('example','category')] = example_data[example_name]['contents']['document']['category']
                data_record[('example','name')] = example_name
                data_record[('example','path')] = example_path
                with lock:
                    shared_list.append(data_record)

if __name__ == "__main__":

    current_dir = os.getcwd().replace('\\','/')
    manifest_path = current_dir + '/../../../../manifest'
    core_path = current_dir + '/../../../../mcuxsdk'

    start_time = time.time()

    example_data = ExampleDataLoader(manifest_path, core_path)
    data = example_data.load()

    end_time = time.time()
    print(f'Examples data loading: {str(datetime.timedelta(seconds=end_time - start_time))}')

    pprint.pp(len(data))
