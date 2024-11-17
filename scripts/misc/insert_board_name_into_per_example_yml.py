# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import os
import sys
import yaml

def main():
    if len(sys.argv) < 4:
        print("Usage: python insert_board_name_into_per_example_yml.py <board name> <toolchain name> <target name>")
        print("E.g. python insert_board_name_into_per_example_yml.py imx95lpd5evk19 armgcc debug")
        sys.exit(1)

    cur_dir_path = os.getcwd()
    examples_dir_path = F'{cur_dir_path}/examples'
    if not os.path.exists(examples_dir_path):
        print("Pls make sure that the examples directory exists in SDK NEXT")
        sys.exit(-1)

    file_to_find="hardware_init.c"
    error_demos_file_name="error_demos.txt"
    board_name = sys.argv[1]
    toolchain_name = sys.argv[2]
    target_name = sys.argv[3]
    search_directory=f'examples/{board_name}'
    dst_directory='examples/src'

    print("search_directory = " + search_directory)
    found_files = find_files(search_directory, file_to_find)
    dst_path = []
    for path in found_files:
        print("board path: " + path)
        dst_path.append(path.replace(search_directory, dst_directory))
    with open(error_demos_file_name, 'w', encoding ='utf-8') as error_demos_file:
        error_demos_contents = ""
        for new_path in dst_path:
            print("common path: " + new_path)
            if os.path.exists(new_path):
                yaml_files = find_yaml_files(new_path)
                for yaml_file in yaml_files:
                    insert_board_name_to_example_yml(yaml_file, board_name, "", toolchain_name, target_name)
            elif is_parent_directory_exists(new_path):
                yaml_files = find_yaml_files(os.path.dirname(new_path))
                core_name = os.path.basename(new_path)
                print(F'{core_name}')
                for yaml_file in yaml_files:
                    insert_board_name_to_example_yml(yaml_file, board_name, core_name, toolchain_name, target_name)
            else:
                error_demos_contents += F"{new_path} or {new_path}/.. does not exist, pls manually correct the demo path\n"
        error_demos_file.write(error_demos_contents)

def is_parent_directory_exists(directory):
    parent_directory = os.path.dirname(directory)
    return os.path.exists(parent_directory)

def find_yaml_files(directory):
    yaml_files = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(('.yml', '.yaml')):
                yaml_files.append(os.path.join(root, file))
    return yaml_files

def is_subkey_present(data, subkey):
    if isinstance(data, dict):
        if subkey in data:
            return True
        for key, value in data.items():
            if is_subkey_present(value, subkey):
                return True
    return False

def add_content_to_matching_subkeys(data, new_sub_key, new_content, match_key):
    #print(f'{new_content}')
    for key, value in data.items():
        #print(F'{key}, {value}')
        if key == match_key:
            #print(F'{key}, {value}')
            if not is_subkey_present(data, new_sub_key):
                data[match_key][new_sub_key] = {}
                # add a new item
                data[match_key][new_sub_key] = [F'{new_content}']
            else:
                if new_content not in data[match_key][new_sub_key]:
                    data[match_key][new_sub_key].append(F'{new_content}')
        elif isinstance(value, dict):
            add_content_to_matching_subkeys(value, new_sub_key, new_content, match_key)


def insert_board_name_to_example_yml(example_yml_file_name, board_name, core_name, toolchain_name, target_name):
    yaml_file_path = F'{example_yml_file_name}'
    parent_key = 'boards'
    #new_content = '- +armgcc@debug'
    #new_content = '+armgcc@debug'
    new_content = F'+{toolchain_name}@{target_name}'
    #new_content = LiteralScalarString(F'{new_content}')
    
    if core_name == "":
        new_sub_key = F'{board_name}'
    else:
        new_sub_key = F'{board_name}@{core_name}'
    print(F'yaml_file_path = {yaml_file_path}, board_name = {board_name}, core_name = {core_name}')
    print(F'new_sub_key = {new_sub_key}')
    try:
        with open(yaml_file_path, 'r') as file:
            data = yaml.safe_load(file)
        add_content_to_matching_subkeys(data, new_sub_key, new_content, parent_key)
        with open(yaml_file_path, 'w') as file:
            print(F'write to file {yaml_file_path}')
            yaml.safe_dump(data, file, sort_keys=False, default_flow_style=False)
        print(f"A new item is added into yaml {yaml_file_path}")
    except yaml.YAMLError as exc:
        print(f"Error in YAML processing: {exc}")
    except FileNotFoundError:
        print(f"The file '{yaml_file_path}' does not exist")
    except Exception as exc:
        print(f"An error occured: {exc}")

def find_files(directory, filename):
    matches = []
    for root, dirs, files in os.walk(directory):
        if filename in files:
            matches.append(root)
    return matches


if __name__ == "__main__":
    main()
