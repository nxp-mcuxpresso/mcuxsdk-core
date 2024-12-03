# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import shutil
import sqlite3
from west.commands import WestCommand, Verbosity
import re
import os
import sys
import logging
from west.configuration import config

script_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)))
sdk_root_dir = os.path.abspath(os.path.join(script_dir, '..'))
sys.path.append(os.path.join(script_dir))
MIR_ROOT_DIR = os.path.join(sdk_root_dir, 'MIR', 'marketing_data', '1.0')
MIR_ROOT_DEVICE_DIR = os.path.join(MIR_ROOT_DIR, 'devices')
MIR_ROOT_BOARD_DIR = os.path.join(MIR_ROOT_DIR, 'boards')
MIR_ROOT_BOARD_IMAGE_DIR = os.path.join(MIR_ROOT_DIR, 'boards', 'images')
MIR_ROOT_KIT_DIR = os.path.join(MIR_ROOT_DIR, 'kits')
MIR_DB = os.path.join(MIR_ROOT_DIR, 'sqlite', 'mir.db')
TOOL_DATA_ROOT_DIR = os.path.join(sdk_root_dir, 'tool_data')
COPYRIGHT_HEADER = '''#
# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
#
'''

from misc import *

LIST_PROJECT_USAGE = '''
Example:
    west update_tool_data -c ./MIR/marketing_data/release_config/release_config.yml

Function
    It will copy board/kit/device yml data and pictures from MIR repo to tool_data repo based on the scope determined in release_config.yml.
    The existing data in tool_data repo will be override during the update.


'''

class UpdateToolDataRepo(WestCommand):
    def __init__(self):
        super().__init__(
            name='update_tool_data_repo',
            help='Update tool data repo based on the scope determined in release_config.yml',
            description='Update tool data repo based on the scope determined in release_config.yml'
        )

    def do_add_parser(self, parser_adder):
        parser = parser_adder.add_parser(
            self.name, help=self.help, description=self.description, usage=LIST_PROJECT_USAGE
        )

        parser.add_argument('-c', '--config', action="store", type=str, required=True, default=[],
                            help= 'The release config yml to decide the release scope.')

        return parser

    def do_run(self, args, unknow) -> None:
        mcux_log_init(logging.DEBUG if args.verbose else logging.INFO)
        mcux_banner('Start updating tool data repo based on boards/kits/devices scope in {}'.format(args.config))
        # get db
        try:
            self.mir_db = sqlite3.connect(MIR_DB)
            mcux_info('Connected to database {}'.format(MIR_DB))
        except sqlite3.Error as e:
            self.die('Cannot connect to database {}'.format(MIR_DB))
        
        # check the existence of release config.yml
        # get the full path of release_config.yml
        release_config_yml_path = os.path.join(sdk_root_dir, args.config)
        if not os.path.exists(release_config_yml_path):
            self.die(f'Cannot find designated {release_config_yml_path}')

        # open the release_config.yml
        try:
            with open(release_config_yml_path, 'r') as f:
                release_config_yml_contents = yaml.safe_load(f)
        except:
            self.die(f'Cannot open designated {release_config_yml_path} which must be a valid release config yml file')

        if "devices" in release_config_yml_contents['release_configuration']:
            self.update_device(release_config_yml_contents['release_configuration']['devices'])

        if "boards" in release_config_yml_contents['release_configuration']:
            self.update_board_kit(release_config_yml_contents['release_configuration']['boards'], 'board')

        if "kits" in release_config_yml_contents['release_configuration']:
            self.update_board_kit(release_config_yml_contents['release_configuration']['kits'], 'kit')

        self.mir_db.close()

        mcux_banner('Finish updating tool data repo.\nPlease check in the tool_data folder and commit your changes.')

    def update_device(self, device_list):
        if not device_list:
            return
        processed_data_id_list = []
        tool_data_devices_dir = os.path.join(TOOL_DATA_ROOT_DIR, "devices")
        # creat the tool_data devices dir
        if not os.path.exists(tool_data_devices_dir):
            os.makedirs(tool_data_devices_dir)

        for device in device_list:
            
            sql = f"select device_id from devices_boards where device_full_name = '{device}'"
            device_id = self.mir_db.execute(sql).fetchone()[0]


            if device_id in processed_data_id_list: 
                continue

            processed_data_id_list.append(device_id)

            mcux_info("Processing device: {}".format(device_id))
            
            original_yml = os.path.join(MIR_ROOT_DIR, "devices", "{}.yml".format(device_id))
            # check existence of original yml
            if not os.path.exists(original_yml):
                mcux_error("Cannot find device {} yml in {}.".format(device_id, MIR_ROOT_DEVICE_DIR))
                continue

            new_yml = os.path.join(TOOL_DATA_ROOT_DIR, "devices", "{}.yml".format(device_id))
            # open the original yml to check copyright
            with open(original_yml, 'r', encoding='UTF-8',  errors='ignore') as f:
                contents = f.read()
                if 'copyright' not in contents.lower():
                    # add copyright
                    contents = COPYRIGHT_HEADER + contents
                # dump to new yml
                with open(new_yml, 'w', encoding='UTF-8',  errors='ignore') as f:
                    f.write(contents)
            # Copy original yml to new yml
            # shutil.copyfile(original_yml, new_yml)

    def update_board_kit(self, board_kit_list, type):
        # return if board_kit_list is empty
        
        if not board_kit_list:
            return
        
        folder_name = type + 's'

        tool_data_board_kit_dir = os.path.join(TOOL_DATA_ROOT_DIR, folder_name)
        tool_data_board_kit_images_dir = os.path.join(TOOL_DATA_ROOT_DIR, folder_name, "images")

        # creat the tool_data boards dir
        if not os.path.exists(tool_data_board_kit_dir):
            os.makedirs(tool_data_board_kit_dir)

        if not os.path.exists(tool_data_board_kit_images_dir):
            os.makedirs(tool_data_board_kit_images_dir)

        for board_kit in board_kit_list:
            mcux_info("Processing {}: {}".format(type, board_kit))

            if type == 'kit':
                sql = f"select id from kits where name = '{board_kit}'"
                id = self.mir_db.execute(sql).fetchone()[0]
            else:
                sql = f"select id from boards where name = '{board_kit}'"
                id = self.mir_db.execute(sql).fetchone()[0]

            original_yml = os.path.join(MIR_ROOT_DIR, folder_name, "{}.yml".format(id))
            # check existence of original yml
            if not os.path.exists(original_yml):
                mcux_error("Cannot find {} {} yml in {}.".format(type, id, MIR_ROOT_BOARD_DIR))
                continue

            new_yml = os.path.join(TOOL_DATA_ROOT_DIR, folder_name, "{}.yml".format(id))
            with open(original_yml, 'r', encoding='UTF-8',  errors='ignore') as f:
                contents = f.read()
                if 'copyright' not in contents.lower():
                    # add copyright
                    contents = COPYRIGHT_HEADER + contents
                # dump to new yml
                with open(new_yml, 'w', encoding='UTF-8',  errors='ignore') as f:
                    f.write(contents)
            # Copy original yml to new yml
            # shutil.copyfile(original_yml, new_yml)

            orignal_image_png = os.path.join(MIR_ROOT_DIR, folder_name, "images", "{}.png".format(id))
            # check existence of original png
            if not os.path.exists(orignal_image_png):
                mcux_error("Cannot find {} {} png in {}.".format(type, id, MIR_ROOT_BOARD_DIR))
                continue

            new_image_png = os.path.join(TOOL_DATA_ROOT_DIR, folder_name, "images", "{}.png".format(id))
            shutil.copyfile(orignal_image_png, new_image_png)
        