# Copyright 2025 NXP
# SPDX-License-Identifier: BSD-3-Clause

import pprint
import glob
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

    def get_prj_conf_files_from_directory(self, board_directory):
        p = pathlib.Path(board_directory)
        files = p.glob('*/prj.conf')
        return list(sorted(set(files)))

    def get_device_yml_files(self):
        files = list()
        p = pathlib.Path(self.core_root_path, 'examples/_boards')
        if p.is_dir():
            files.extend(self.get_prj_conf_files_from_directory(p))
        p = pathlib.Path(self.core_root_path, 'examples_int/_boards')
        if p.is_dir():
            files.extend(self.get_prj_conf_files_from_directory(p))
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

    current_dir = pathlib.Path().cwd()
    manifest_path = pathlib.Path(current_dir, '../../../../manifest')
    core_path = pathlib.Path(current_dir, '../../../../mcuxsdk')

    start_time = time.time()

    device_data = BoardDataLoader(manifest_path, core_path)
    data = device_data.load()

    end_time = time.time()
    print(f'Board data loading: {str(datetime.timedelta(seconds=end_time - start_time))}')
    pprint.pp(len(data))
