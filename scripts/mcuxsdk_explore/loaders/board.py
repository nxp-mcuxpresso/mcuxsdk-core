# Copyright 2025 NXP
# SPDX-License-Identifier: BSD-3-Clause

import pprint
import glob
import os
import os.path
import re
import pathlib
import multiprocessing as mp
from multiprocessing import Manager
import datetime
import time

class BoardDataLoader():

    def __init__(self, manifest_root_path, core_root_path):
        self.manifest_root_path = manifest_root_path
        self.core_root_path = core_root_path

        self.types = [
            ('board', 'name'),
            ('part', 'name'),
        ]

    def load(self):
        files = self.get_device_yml_files()
        return self.load_files_parallel(files)

    def get_prj_conf_files_from_directory(self, core_repo_dir):
        target_files_patterns = ['prj.conf']
        files = glob.glob(core_repo_dir + "/*/*", recursive=True)
        files2 = list()
        for file in files:
            for pattern in target_files_patterns:
                if file.endswith(pattern):
                    files2.append(file)
        files = files2
        return list(sorted(set(files)))

    def get_device_yml_files(self):
        files = list()
        files = self.get_prj_conf_files_from_directory(self.core_root_path + '/examples/_boards')
        if os.path.isdir(os.path.normpath(self.core_root_path + '/examples_int/_boards')):
            files.extend(self.get_prj_conf_files_from_directory(self.core_root_path + '/examples_int/_boards'))
        return list(sorted(set(files)))

    def load_single_file(self, args):
        filepath, shared_list, lock = args
        pattern = r'(?<=CONFIG_MCUX_HW_DEVICE_PART_)(.*)(?=\=y)'

        board = None
        device = None
        with open(filepath, 'r', encoding="utf-8") as f_input:
            lines = f_input.readlines()
            for line in lines:
                match = re.search(pattern, line)
                if match:
                    device = match.group()
                    board = pathlib.Path(filepath).parts[-2]
                    if device and board:
                        data_record = dict()
                        data_record[('board', 'name')] = pathlib.Path(filepath).parts[-2]
                        data_record[('part', 'name')] = match.group()
                        with lock:
                            shared_list.append(data_record)

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

if __name__ == "__main__":

    current_dir = os.getcwd().replace('\\','/')
    manifest_path = current_dir + '/../../../../manifest'
    core_path = current_dir + '/../../../../mcuxsdk'

    start_time = time.time()

    device_data = BoardDataLoader(manifest_path, core_path)
    data = device_data.load()

    end_time = time.time()
    print(f'Board data loading: {str(datetime.timedelta(seconds=end_time - start_time))}')
    pprint.pp(len(data))
