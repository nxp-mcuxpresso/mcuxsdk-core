# Copyright 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

"""
West command for exporting project information and configuration details.

This module implements a West command that extracts project-specific information
from MCUXpresso SDK projects and exports it to a JSON file for use with
MCUXpresso Config Tools. The command performs a temporary "build" to gather
configuration data, parses build outputs, and generates a structured project
information file.

Usage:
    west cfg_project_info -b <board> <source_dir> [-Dcore_id=<core>]
"""
import subprocess
import re
import json
import os
import shutil
import sys

from west import log
from west.commands import WestCommand

# Description text for the project-info west command that explains its purpose
# and functionality to users when they request help information
PROJECT_INFO_DESCRIPTION = '''\
This command exports project specific information and configuration details,
and stores them in project_info.json which is then used in MCUXpresso Config Tools.
'''

class ProjectInfo(WestCommand):
    """
    West command class for extracting and exporting MCUXpresso SDK project information.
    """
    def __init__(self):
        super().__init__(
            'cfg_project_info',
            # Keep this in sync with the string in west-commands.yml.
            'export project information and configuration details',
            PROJECT_INFO_DESCRIPTION,
            accepts_unknown_args=True)

    def do_add_parser(self, parser_adder):
        parser = parser_adder.add_parser(
            self.name,
            help=self.help,
            description=self.description)
        
        parser.add_argument('-b', '--board', help='board for which to create the project info file')
        parser.add_argument('source_dir', help="source directory for project")
        parser.add_argument('-D', action='append', dest='cmake_defines', help="CMake defines in format key=value (e.g., -Dcore_id=cm33)")
        parser.add_argument("--no_tmp_delete", action="store_true", help="Disables deletion of temporary build file. Used for debugging")

        return parser
    
    def run_build_command(self):
        """
        Execute a temporary CMake-only build to generate project configuration files.

        Handles both single-core and multi-core project configurations.
        """ 
        try:
            log.inf("\n=== Running CMake configuration build: ", colorize=True)
            if self.core_id:
                log.inf(f"Target: {self.args.board} (core: {self.core_id})")
            else:
                log.inf(f"Target: {self.args.board}")

            build_output_path = os.path.join(self.output_dir, self.build_dir)
            cmd_args = ["west", "build", "--cmake-only", "--pristine=always", "-b", 
                   self.args.board, self.args.source_dir, "-d", build_output_path, "--"]
            
            if self.core_id:
                cmd_args.append(f"-Dcore_id={self.core_id}")
            
            cmd_args.append("-DCMAKE_EXPORT_COMPILE_COMMANDS=ON")
            
            build_output = subprocess.run(
                cmd_args,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
        except subprocess.CalledProcessError as e:
            log.err("Error occurred:\n", e.stderr)
            return False
        
        return True

    def parse_build_output(self):
        """
        Parse CMakeCache.txt to extract project configuration information.

        Returns:
            dict: 
            Dictionary containing extracted project information with keys:
            projectRootPath, name, device_package, board, and optionally core
        """
        try:
            cmake_cache =  open(os.path.join(self.output_dir, self.build_dir, "CMakeCache.txt"), 'r').read()
            if cmake_cache:
                project_path_regex = r".*APPLICATION_SOURCE_DIR:PATH=([^\s]+)"
                project_path = self.regex_match_helper(project_path_regex, cmake_cache)
                if not project_path:
                    log.err("Project root path not found in CMakeCache.txt")
                    return False

                project_name_regex = r".*CMAKE_PROJECT_NAME:STATIC=([^\s]+)"
                project_name = self.regex_match_helper(project_name_regex, cmake_cache)
                if not project_name:
                    log.err("Project name not found in CMakeCache.txt")
                    return False

                board_regex = r".*board:STRING=([^\s]+)"
                board = self.regex_match_helper(board_regex, cmake_cache)

                device_regex = r".*-DCPU_([^\s_]+)"
                device = self.regex_match_helper(device_regex, cmake_cache)
                if not device:
                    log.err("Device package not found in CMakeCache.txt")
                    return False

                core_regex = r".*core_id:UNINITIALIZED=([^\s]+)"
                core = self.regex_match_helper(core_regex, cmake_cache)

                outpath_regex = r".*MCUXPRESSO_CONFIG_TOOL_MEX_PATH:STRING=([^\s]+)"
                outpath = self.regex_match_helper(outpath_regex, cmake_cache)

                cmake_regex = r".*MCUXPRESSO_CONFIG_TOOL_GENERATED_CMAKE_FILE_PATH:FILEPATH=([^\s]+)"
                cmake_file_path = self.regex_match_helper(cmake_regex, cmake_cache)
                if not cmake_file_path:
                    log.err("Generated CMake file path not found in CMakeCache.txt")
                    return False
                
                prj_regex = r".*MCUXPRESSO_CONFIG_TOOL_EDIT_PRJ_FILE_PATH:FILEPATH=([^\s]+)"
                prj_file_path = self.regex_match_helper(prj_regex, cmake_cache)
                if not prj_file_path:
                    log.err("Generated project edit file path not found in CMakeCache.txt")
                    return False
                
                self.project_info = {
                    "projectRootPath": project_path,
                    "name": project_name,
                    "device_package": device,
                    "board": board,
                    "source_generated_cmake_file_path": cmake_file_path,
                    "component_edit_prj_file_path": prj_file_path
                }

                if core:
                    self.project_info["core"] = core

                if outpath:
                    self.project_info["outputPath"] = outpath

                return True
            
        except FileNotFoundError:
            log.err(f"CMakeCache.txt not found in {os.path.join(self.output_dir, self.build_dir)}")
            return False

    def regex_match_helper(self, regex, string):
        """
        Helper function to perform regex matching on strings.
        
        Args:
            regex (str): Regular expression pattern to match
            string (str): Input string to search in
            
        Returns:
            str/None: First captured group from regex match, or None if no match
        """
        regex_match = re.match(regex, string, re.DOTALL)

        return regex_match.group(1) if regex_match else None

    def parse_compile_commands(self):
        """
        Parse compile_commands.json to extract include paths and source files.

        Updates the project_info dictionary with includes and files lists.
        
        Returns:
            dict: Updated project_info dictionary with includes and files added
        """
        compile_commands_path = os.path.join(self.output_dir, self.build_dir, "compile_commands.json")
        try:
            with open(compile_commands_path, 'r') as f:
                compile_commands = json.load(f)

            include_paths = set()

            for command in compile_commands:
                includes = re.findall(r'-I([^\s]+)', command['command'])
                include_paths.update(includes)
                
            self.project_info["includes"] = list(include_paths)

        except FileNotFoundError:
            log.err(f"Compile commands file not found at {compile_commands_path}")
            return False
        except json.JSONDecodeError:
            log.err(f"Error parsing compile commands JSON at {compile_commands_path}")
            return False

        return True
    
    def parse_source_list(self):
        source_list_path = self.find_source_list_file()
        try:
            with open(source_list_path, 'r') as f:
                source_list_content = f.read().strip()
            
            file_paths = [path.strip() for path in source_list_content.split(";") if path.strip()]

            files = set()

            for file_path in file_paths:
                if file_path.lower().endswith('.c'):
                    files.add(file_path)
                elif file_path.lower().endswith('.h'):
                    files.add(file_path)

            self.project_info["files"] = list(file_paths)

        except FileNotFoundError:
            log.err(f"Source list file not found at {source_list_path}")
            return False
        
        return True
    
    def parse_config_file(self):
        """
        Parse configuration file to extract components in project.
        Attempts to find and read .config file.
        Updates the project_info dictionary with the components.

        Returns:
            bool: True if parsing is successful, False otherwise
        """
        try:
            config_file_path = os.path.join(self.output_dir, self.build_dir, ".config")

            with open(config_file_path, 'r') as f:
                config_content = f.read().strip()

            component_regex = r"(?<=CONFIG_MCUX_COMPONENT_)(.*?)(?==y)"
            match_components = re.findall(component_regex, config_content, re.MULTILINE)

            components = []

            for component in match_components:
                component_dict = {
                    "kconfig_id": component
                }
                components.append(component_dict)

            self.project_info["components"] = components
            return True
        
        except FileNotFoundError:
            log.err(f"Configuration file not found at {config_file_path}")
            return False
            
    def find_source_list_file(self):
        
        source_list_regex = r"^(?!.*exclude).*source_list\.txt$"
        build_path = os.path.join(self.output_dir, self.build_dir)

        try:
            for filename in os.listdir(build_path):
                if re.match(source_list_regex, filename):
                    source_list_path = os.path.join(build_path, filename)                    
                    return source_list_path
                
        except FileNotFoundError:
            log.err(f"Build directory not found: {build_path}")
            return None
        
        log.err("No source_list.txt file found")
        return None

    def create_json_file(self):
        """
        Generate and write the final project_info.json file.
        
        The file is written to the cfg_tools directory
        within the project root for use by MCUXpresso Config Tools.
        """
        try:
            self.json_data_raw["$schema"] = "https://mcuxpresso.nxp.com/staticdata/mcux/schema/project_info/project_info_schema_1.0.json"

            projects = list()
            projects.append(self.project_info)
            self.json_data_raw["projects"] = list(projects)

            json_file_path = os.path.join(self.output_dir, "project_info.json")

            json_data_real = json.dumps(self.json_data_raw, indent=4)

            open(json_file_path, 'w').write(json_data_real)

        except (OSError, IOError) as e:
            log.err(f"Error writing project_info.json file: {e}")
            return False
        
        except json.JSONEncodeError as e:
            log.err(f"Error encoding JSON data: {e}")
            return False
        
        return True

    def check_cfg_tools_folder(self):
        """
        Create cfg_tools directory if it doesn't exist
        """
        if not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir, exist_ok=True)

        return os.path.exists(self.output_dir)
    
    def delete_temp_build_file(self):
        """
        Delete temporary build directory if it exists
        """
        build_path = os.path.join(self.output_dir, self.build_dir)
        if os.path.exists(build_path):
            shutil.rmtree(build_path)
        

    def do_run(self, args, remainder):
        """
        Main execution method for the project-info west command.
        """

        log.inf("=== Starting project info extraction: ", colorize=True)
        log.inf(f"Source directory: {args.source_dir}")
        log.inf(f"Board: {args.board}")

        self.core_id = None
        if args.cmake_defines:
            for define in args.cmake_defines:
                if define.startswith('core_id='):
                    self.core_id = define.split('=', 1)[1]
                    log.inf(f"Core: {self.core_id}")
                    break

        self.args = args
        self.build_dir = "tmp_build"

        self.project_root = os.path.join(os.curdir, self.args.source_dir)
        self.output_folder_name = "cfg_tools"
        self.output_dir = os.path.join(self.project_root, self.output_folder_name)

        self.json_data_raw = {}

        folder_exist = self.check_cfg_tools_folder()
        if not folder_exist:
            log.err(f"Could not create output directory: {self.output_dir}")


        status = self.run_build_command()
        if not status:
            log.err("Build command failed: terminating project info extraction")
            self.delete_temp_build_file()
            sys.exit(-1)

        log.inf("\n=== Creating project_info.json file from build output: ", colorize=True)

        status = self.parse_build_output()
        if not status:
            log.err("Build data parsing failed: terminating project info extraction")
            self.delete_temp_build_file()
            sys.exit(-1)
        
        status = self.parse_compile_commands()
        if not status:
            log.err("Build data parsing failed: terminating project info extraction")
            self.delete_temp_build_file()
            sys.exit(-1)
        
        status = self.parse_source_list()
        if not status:
            log.err("Build data parsing failed: terminating project info extraction")
            self.delete_temp_build_file()
            sys.exit(-1)
        
        status = self.parse_config_file()
        if not status:
            log.err("Parsing configuration file failed: terminating project info extraction")
            self.delete_temp_build_file()
            sys.exit(-1)
        
        status = self.create_json_file()
        if not status:
            log.err("Creating project_info.json failed: terminating project info extraction")
            self.delete_temp_build_file()
            sys.exit(-1)
        
        if (not args.no_tmp_delete):
            self.delete_temp_build_file()

        log.inf("Project info extraction completed successfully!\n")
        log.inf(f"Output file: {os.path.join(os.path.abspath(self.output_dir), 'project_info.json')}")
        log.inf("-- Use the output file directory (cfg_tools) in Config Tools as a toolchain project information source. --", colorize=True)
