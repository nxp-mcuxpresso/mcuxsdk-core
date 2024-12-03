# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import yaml
import sys  
import os
import traceback

BY_PASS_DATA_SECTION = [
    'board.toolchains',
]

class ExampleList:
    def __init__(self):
        self.example_list = []
        self.example_yml_list = []
        self.repo_root = os.getenv("SdkRootDirPath")
        self.board = os.getenv("board")
        self.core_id = os.getenv("core_id")
        self.project_root_path = os.getenv("project_root_path")
        self.example_name = os.getenv("example_name") 
        self.toolchain = os.getenv("toolchain")
    
    def get_example_list(self):
        try:
            self._get_example_list_ymls()
            for yml in self.example_yml_list:
                with open(yml, 'r') as file:
                    data = yaml.safe_load(file)
                for example_name, example_data in data.items():
                    if example_name in BY_PASS_DATA_SECTION:
                        continue
                    if example_data['required']:
                        if 'contents' in example_data and 'remove_toolchain' in example_data['contents']:
                            if self.toolchain in list(example_data['contents']['remove_toolchain'].keys()):
                                continue
                            else:
                                self.example_list.append(example_name)
                        else:
                            self.example_list.append(example_name)

            print((";").join(self.example_list), end='')
            
            if self.example_name in self.example_list:
                exit(0)
            else:
                exit(-1)
        except Exception as exc:
            print(traceback.format_exc())
            exit(-2)

    def _get_example_list_ymls(self):
        folders_to_be_searched = []
        board_folder = os.path.join(self.repo_root, f"examples/{self.board}").replace("\\", "/").rstrip('/')
        board_core_id_foler = os.path.join(board_folder, f"{self.core_id}").replace("\\", "/").rstrip('/')

        if os.path.isdir(board_folder):
            folders_to_be_searched.append(board_folder)
        if os.path.isdir(board_core_id_foler):
            folders_to_be_searched.append(board_core_id_foler)

        # remove duplicate folders in folders_to_be_searched
        folders_to_be_searched = list(dict.fromkeys(folders_to_be_searched))

        # parse all files inside board_folder and get all yml files ending with _example_list.yml
        for folder in folders_to_be_searched:
            for file in os.listdir(folder):
                file_path = os.path.join(folder, file)
                if file.endswith("example.yml"):
                    self.example_yml_list.append(file_path.replace("\\", "/").rstrip('/'))

if __name__ == "__main__":
    ExampleList().get_example_list()