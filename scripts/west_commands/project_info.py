"""
West command for exporting project information and configuration details.

This module implements a West command that extracts project-specific information
from MCUXpresso SDK projects and exports it to a JSON file for use with
MCUXpresso Config Tools. The command performs a temporary "build" to gather
configuration data, parses build outputs, and generates a structured project
information file.

Usage:
    west project-info -b <board> -s <source_dir> [-c <core>]
"""
import subprocess
import re
import json
import os
import shutil

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
            'project-info',
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
        parser.add_argument('-s', '--source_dir', help="source directory for project")
        parser.add_argument('-c', '--core', default=None, help="specific core for multi-core project")

        return parser
    
    def run_build_command(self):
        """
        Execute a temporary CMake-only build to generate project configuration files.

        Handles both single-core and multi-core project configurations.
        """ 
        try:
            print("Running CMake configuration build...")
            if self.args.core:
                print(f"Target: {self.args.board} (core: {self.args.core})")
            else:
                print(f"Target: {self.args.board}")

            build_output_path = os.path.join(self.output_dir, self.build_dir)
            if (self.args.core):
                core_arg = f"-Dcore_id={self.args.core}"
                build_output = subprocess.run(
                    ["west", "build", "--cmake-only", "--pristine=always","-b", 
                    self.args.board, self.args.source_dir, "-d", build_output_path, "--", core_arg, "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"],
                    check=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )
            else:
                build_output = subprocess.run(
                    ["west", "build", "--cmake-only", "--pristine=always","-b", 
                    self.args.board, self.args.source_dir, "-d", build_output_path, "--", "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"],
                    check=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )
            
        except subprocess.CalledProcessError as e:
            print("Error occurred:\n", e.stderr)

    def parse_build_output(self):
        """
        Parse CMakeCache.txt to extract project configuration information.

        Returns:
            dict: 
            Dictionary containing extracted project information with keys:
            projectRootPath, name, device_package, board, and optionally core
        """
        cmake_cache =  open(os.path.join(self.output_dir, self.build_dir, "CMakeCache.txt"), 'r').read()
        if cmake_cache:
            project_path_regex = r".*APPLICATION_SOURCE_DIR:PATH=([^\s]+)"
            project_path = self.regex_match_heleper(project_path_regex, cmake_cache)

            project_name_regex = r".*CMAKE_PROJECT_NAME:STATIC=([^\s]+)"
            project_name = self.regex_match_heleper(project_name_regex, cmake_cache)

            board_regex = r".*board:STRING=([^\s]+)"
            board = self.regex_match_heleper(board_regex, cmake_cache)

            device_regex = r".*device:STRING=([^\s]+)"
            device = self.regex_match_heleper(device_regex, cmake_cache)

            core_regex = r".*core_id:UNINITIALIZED=([^\s]+)"
            core = self.regex_match_heleper(core_regex, cmake_cache)
            
            self.project_info = {
                "projectRootPath": project_path,
                "name": project_name,
                "device_package": device,
                "board": board,
            }

            if core:
                self.project_info["core"] = core

            return self.project_info

    def regex_match_heleper(self, regex, string):
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
            file_paths = set()

            for command in compile_commands:
                includes = re.findall(r'-I([^\s]+)', command['command'])
                include_paths.update(includes)

                file_paths.add(command['file'])
                
            self.project_info["includes"] = list(include_paths)
            self.project_info["files"] = list(file_paths)

        except FileNotFoundError:
            print(f"Compile commands file not found at {compile_commands_path}")
        except json.JSONDecodeError:
            print(f"Error parsing compile commands JSON at {compile_commands_path}")

        return self.project_info

    def create_json_file(self):
        """
        Generate and write the final project_info.json file.
        
        The file is written to the cfg_tools directory
        within the project root for use by MCUXpresso Config Tools.
        """
        self.json_data_raw["schema"] = "http://json-schema.org/draft-07/schema#"

        projects = list()
        projects.append(self.project_info)
        self.json_data_raw["projects"] = list(projects)

        json_file_path = os.path.join(self.output_dir, "project_info.json")

        json_data_real = json.dumps(self.json_data_raw, indent=4)

        open(json_file_path, 'w').write(json_data_real)

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
        

    def do_run(self, args, unknown):
        """
        Main execution method for the project-info west command.
        """

        print("Starting project info extraction...")
        print(f"Source directory: {args.source_dir}")
        print(f"Board: {args.board}")
        if args.core:
            print(f"Core: {args.core}")
        print()

        self.args = args
        self.build_dir = "tmp_build"

        self.project_root = os.path.join(os.curdir, self.args.source_dir)
        self.output_folder_name = "cfg_tools"
        self.output_dir = os.path.join(self.project_root, self.output_folder_name)

        self.json_data_raw = {}

        folder_exist = self.check_cfg_tools_folder()
        if not folder_exist:
            print(f"Could not create output directory: {self.output_dir}")


        self.run_build_command()

        print("\nCreating project_info.json file from build output...")
        self.parse_build_output()
        self.parse_compile_commands()
        self.create_json_file()
        self.delete_temp_build_file()

        print("Project info extraction completed successfully!\n")
        print(f"Output file: {os.path.join(os.path.abspath(self.output_dir), 'project_info.json')}")
        print("-- Use the output file directory (cfg_tools) in Config Tools as a toolchain project information source. --")


        
    

