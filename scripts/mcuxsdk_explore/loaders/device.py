# Copyright 2025 NXP
# SPDX-License-Identifier: BSD-3-Clause

import pprint
import glob
import pathlib
import multiprocessing as mp
from multiprocessing import Manager
import datetime
import time
import yaml

class DeviceDataLoader():
    def __init__(self, manifest_root_path, core_root_path):
        self.manifest_root_path = manifest_root_path
        self.core_root_path = core_root_path

        self.types = [
            ('device', 'id'),
            ('device', 'full_name'),
            ('device', 'name'),
            ('device', 'platform'),
            ('device', 'series'),
            ('device', 'family'),
            ('device', 'subfamily'),
        ]

    def load(self):
        files = self.get_device_yml_files()
        return self.load_files_parallel(files)

    def get_device_yml_files_from_directory(self, device_directory):
        p = pathlib.Path(device_directory)
        files = p.glob('**/*/chip.yml')
        return list(sorted(set(files)))

    def get_device_yml_files(self):
        files = list()
        p = pathlib.Path(self.core_root_path, 'devices')
        if p.is_dir():
            files.extend(self.get_device_yml_files_from_directory(p))
        p = pathlib.Path(self.core_root_path, 'devices_int')
        if p.is_dir():
            files.extend(self.get_device_yml_files_from_directory(p))
        return list(sorted(set(files)))

    def load_single_file(self, args):
        filepath, shared_list, lock = args
        data = self.load_yml(filepath)
        for device in data['device.hardware_data']['contents']['devices']:
            data_record = dict()
            data_record[('device', 'id')] = device['id']
            data_record[('device', 'full_name')] = device['full_name']
            data_record[('device', 'name')] = device['name']
            data_record[('device', 'platform')] = device['platform']
            data_record[('device', 'series')] = device['series']
            data_record[('device', 'family')] = device['family']
            data_record[('device', 'subfamily')] = device['subfamily']
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
                results = pool.map(self.load_single_file, args)
            return list(shared_list)

    def load_yml(self, file):
        with open(file, 'r', encoding="utf-8") as f:
            result = yaml.safe_load(f)
        return result

if __name__ == "__main__":
    current_dir = pathlib.Path().cwd()
    manifest_path = pathlib.Path(current_dir, '../../../../manifest')
    core_path = pathlib.Path(current_dir, '../../../../mcuxsdk')

    start_time = time.time()
    device_data = DeviceDataLoader(manifest_path, core_path)
    data = device_data.load()
    end_time = time.time()
    print(f'Device data loading: {str(datetime.timedelta(seconds=end_time - start_time))}')
    pprint.pp(len(data))
