# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import os, sys
import logging
import yaml, json

def mcux_log_init(log_level=logging.DEBUG):
    logging.basicConfig(level=log_level, format='%(message)s')

def mcux_banner(msg):
    logging.info(f'==== {msg} ====')

def mcux_small_banner(msg):
    logging.info(f'-- {msg}')

def mcux_info(msg):
    logging.info(f'INFO: {msg}')

def mcux_error(msg):
    logging.error(f'ERROR: {msg}')

def mcux_debug(msg):
    logging.debug(f'DEBUG: {msg}')

# File/Json/Yaml read/write
def mcux_read_yaml(file_path):
    if not os.path.exists(file_path):
        return None
    with open(file_path, 'r') as file:
        return yaml.safe_load(file)

def mcux_write_yaml(file_path, data, is_create_dir=False):
    if is_create_dir and os.path.dirname(file_path):
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
    with open(file_path, 'w') as file:
        yaml.dump(data, file, default_flow_style=False, sort_keys=False)

def mcux_read_json(file_path):
    if not os.path.exists(file_path):
        return None
    with open(file_path, 'r') as file:
        return json.load(file)

def mcux_write_json(file_path, data, is_create_dir=False):
    if is_create_dir and os.path.dirname(file_path):
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
    with open(file_path, 'w') as file:
        json.dump(data, file, indent=4)