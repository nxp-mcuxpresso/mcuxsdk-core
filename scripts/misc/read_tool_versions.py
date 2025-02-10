# Copyright 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import yaml
import jsonschema
import sys
import json
import os

def main():
    # Get the current directory path
    current_dir = os.path.dirname(os.path.abspath(__file__))

    # Determine the paths to the schema file and YAML file
    tool_schema_file = os.path.join(current_dir, "../data_schema/tool.json")
    yaml_file = os.path.join(current_dir, "../../tool.yml")

    # Load the JSON schema from the file
    with open(tool_schema_file, 'r') as file:
        tool_schema = json.load(file)

    # Load the YAML file
    with open(yaml_file, 'r') as file:
        data = yaml.safe_load(file)
    
    # Validate the YAML file against the schema
    try:
        jsonschema.Draft7Validator(tool_schema).validate(data)
    except jsonschema.exceptions.ValidationError as err:
        print(f"Validation error: {err.message}")
        sys.exit(1)
    
    for toolchain, details in data['toolchains'].items():
        print(f"{toolchain}_compiler_minimum_version={details['compiler_version']}".upper())
    
    for tool, details in data['build_tools'].items():
        print(f"{tool}_minimum_version={details['version']}".upper())

if __name__ == "__main__":
    main()