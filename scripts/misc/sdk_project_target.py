# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import os, sys
import yaml, json
import glob
import re
from pathlib import Path

script_dir = os.path.abspath(os.path.dirname(__file__))
sdk_root_dir = os.path.abspath(os.path.join(script_dir, '..', '..')).replace('\\', '/')

from misc import *

SCHEMA_DIR = 'scripts/data_schema'
EXAMPLE_YML_SCHEMA = 'example_description_schema.json'
DEFINITION_YAL_SCHEMA = 'definitions_schema.json'

SUPPORTED_TOOLCHAINS = ['armgcc', 'iar', 'mdk', 'xcc', 'xtensa', 'codewarrior', 'riscvllvm']

class MCUXProjectData(object):
    def __init__(self):
        self.raw = {}

    def as_dict(self):
        export_dict = self.raw.copy()
        export_dict['build_cmd'] = self.build_cmd
        return export_dict

    @classmethod
    def from_fields(cls,
                    name,
                    board,
                    device,
                    core_id,
                    toolchain,
                    target,
                    project_file,
                    category,
                    use_sysbuild,
                    shield=None,
                    extra_build_args=[]
                    ):
        case = cls()
        assert(board or device)
        case.name = name
        case.board = board
        case.device = device
        case.shield = shield
        case.core_id = core_id
        case.toolchain = toolchain
        case.target = target
        case.project_file = project_file
        case.category = category
        case.use_sysbuild = use_sysbuild
        case.extra_build_args = extra_build_args
        return case

    @property
    def board(self):
        return self.raw.get('board')

    @board.setter
    def board(self, value):
        self.raw['board'] = value

    @property
    def device(self):
        return self.raw.get('device')

    @device.setter
    def device(self, value):
        self.raw['device'] = value

    @property
    def shield(self):
        return self.raw.get('shield')

    @shield.setter
    def shield(self, value):
        self.raw['shield'] = value

    @property
    def name(self):
        return self.raw.get('name', '')

    @name.setter
    def name(self, value):
        self.raw['name'] = value

    @property
    def core_id(self):
        return self.raw.get('core_id', '')

    @core_id.setter
    def core_id(self, value):
        self.raw['core_id'] = value

    @property
    def target(self):
        return self.raw.get('target', '')

    @target.setter
    def target(self, value):
        if value:
            self.raw['target'] = value

    @property
    def toolchain(self):
        return self.raw.get('toolchain', '')

    @toolchain.setter
    def toolchain(self, value):
        if value in SUPPORTED_TOOLCHAINS:
            self.raw['toolchain'] = value

    @property
    def project_file(self):
        return self.raw.get('project_file', '')

    @project_file.setter
    def project_file(self, value):
        if not os.path.exists(os.path.join(sdk_root_dir, value)):
            raise ValueError(f"Project file {value} does not exist in repository")
        self.raw['project_file'] = value.replace('\\', '/')

    @property
    def category(self):
        return self.raw.get('category', '')

    @category.setter
    def category(self, value):
        self.raw['category'] = value

    @property
    def extra_build_args(self):
        return self.raw.get('extra_build_args', [])

    @extra_build_args.setter
    def extra_build_args(self, value: list):
        self.raw['extra_build_args'] = value

    @property
    def build_cmd_board_device_core(self):
        if self.board:
            args = ['-b', self.board]
            if self.shield:
                args.extend(['--shield', self.shield])
        elif self.device:
            args = ['--device', self.device]

        if self.core_id:
            args.append(f'-Dcore_id={self.core_id}')
        return ' '.join(args)

    @property
    def build_cmd_pretty(self):
        # FIXME not sure the usage of this api
        return f'west build -p always{" --sysbuild" if self.use_sysbuild else ""} {self.project_file} --toolchain {self.toolchain:6} --config {self.target:10} {self.build_cmd_board_device_core:0}'

    @property
    def build_cmd(self):
        args = ['west', 'build', '-p', 'always']
        # Keep order with original api
        if self.use_sysbuild:
            args.append('--sysbuild')
        args.extend([self.project_file, '--toolchain', self.toolchain, '--config', self.target, self.build_cmd_board_device_core])
        if self.extra_build_args:
            args.extend(self.extra_build_args)
        return ' '.join(args)

    @property
    def board_core(self):
        return self.board + ('@' + self.core_id if self.core_id else '')

class MCUXAppTargets(object):
    BOARD_DEF_TARGETS = {}
    DEVICE_DEF_TARGETS = {}

    TOOLCHAINS_FILTER = []
    TOOLCHAINS_EXCLUDE_FILTER = []
    TARGETS_FILTER = []
    TARGETS_EXCLUDE_FILTER = []
    BOARDS_FILTER = []
    BOARDS_EXCLUDE_FILTER = []
    SHIELDS_FILTER = []
    SHIELDS_EXCLUDE_FILTER = []
    DEVICES_FILTER = []
    DEVICES_EXCLUDE_FILTER = []

    INT_EXAMPLE_DATA = {}

    def __init__(self):
        super().__init__()
        self.tgt_dict = {}

    def reset_targets(self):
        self.tgt_dict = {}

    @classmethod
    def config_internal_data(cls):
        # Try get internal data
        try:
            if not os.path.isdir(internal_module := os.path.join(sdk_root_dir, 'examples_int/scripts/list_project')):
                raise FileNotFoundError
            sys.path.append(internal_module)
            from list_project_mod import IntMCUXAppTargets
            IntMCUXAppTargets.parse()
            MCUXAppTargets.BOARD_DEF_TARGETS = IntMCUXAppTargets.BOARD_DEF_TARGETS
            MCUXAppTargets.DEVICE_DEF_TARGETS = IntMCUXAppTargets.DEVICE_DEF_TARGETS
            MCUXAppTargets.INT_EXAMPLE_DATA = IntMCUXAppTargets.INT_EXAMPLE_DATA
        except Exception:
            # reset if encounter any exception
            pass

    @classmethod
    def config_filter(cls, toolchains_filter=[], boards_filter=[], shields_filter=[], targets_filter=[], devices_filter=[]):
        '''
        Filter format: [e@][r@]filter_string
        - [e@] optional: means exclude these stuffs
        - [r@] optional: means regex match using the search string
        - example: e@frdmk22f: all input string exactly as frdmk22f will be filtered out
        - example: e@r@frdmk22f: all input string contains frdmk22f will be filtered out
        - example: frdmk22f: all input string exactly as frdmk22f will be filtered in
        - example: r@frdmk22f: all input string contains frdmk22f will be filtered in
        '''
        if toolchains_filter:
            cls.TOOLCHAINS_FILTER = [item for item in toolchains_filter if not item.startswith('e@')]
            cls.TOOLCHAINS_EXCLUDE_FILTER = [item[2:] for item in toolchains_filter if item.startswith('e@')]

        if boards_filter:
            cls.BOARDS_FILTER = [item for item in boards_filter if not item.startswith('e@')]
            cls.BOARDS_EXCLUDE_FILTER = [item[2:] for item in boards_filter if item.startswith('e@')]

        if shields_filter:
            cls.SHIELDS_FILTER = [item for item in shields_filter if not item.startswith('e@')]
            cls.SHIELDS_EXCLUDE_FILTER = [item[2:] for item in shields_filter if item.startswith('e@')]

        if targets_filter:
            cls.TARGETS_FILTER = [item for item in targets_filter if not item.startswith('e@')]
            cls.TARGETS_EXCLUDE_FILTER = [item[2:] for item in targets_filter if item.startswith('e@')]

        if devices_filter:
            cls.DEVICES_FILTER = [item for item in devices_filter if not item.startswith('e@')]
            cls.DEVICES_EXCLUDE_FILTER = [item[2:] for item in devices_filter if item.startswith('e@')]

        mcux_debug(f'Create Filters')
        mcux_debug(f'  Toolchains Include: ' + ', '.join(cls.TOOLCHAINS_FILTER))
        mcux_debug(f'  Toolchains Exclude: ' + ', '.join(cls.TOOLCHAINS_EXCLUDE_FILTER))
        mcux_debug(f'  Boards Include: ' + ', '.join(cls.BOARDS_FILTER))
        mcux_debug(f'  Boards Exclude: ' + ', '.join(cls.BOARDS_EXCLUDE_FILTER))
        mcux_debug(f'  Devices Include: ' + ', '.join(cls.DEVICES_FILTER))
        mcux_debug(f'  Devices Exclude: ' + ', '.join(cls.DEVICES_EXCLUDE_FILTER))
        mcux_debug(f'  Shields Include: ' + ', '.join(cls.SHIELDS_FILTER))
        mcux_debug(f'  Shields Exclude: ' + ', '.join(cls.SHIELDS_EXCLUDE_FILTER))
        mcux_debug(f'  Targets Include: ' + ', '.join(cls.TARGETS_FILTER))
        mcux_debug(f'  Targets Exclude: ' + ', '.join(cls.TARGETS_EXCLUDE_FILTER))

    def inject_target(self, target_str: str):
        match = re.match(r'(?P<prefix>[+-]?)(?P<toolchain>[a-z]+)@(?P<target>.+)', target_str)
        if not match:
            mcux_debug(f"Invalid target {target_str}")
            return None
        action = match.group('prefix')
        toolchain = match.group('toolchain')
        target = match.group('target')
        toolchain_target = f"{toolchain}@{target}"

        if action in ['+', '']:
            self.tgt_dict[toolchain_target] = True
        elif action in ['-']:
            self.tgt_dict[toolchain_target] = False
        else:
            raise RuntimeError(f"Invalid action {action} in {target_str}")

    def inject_targets_from_shared_file(self, name, shared_file, instance_type):
        instance_def_targets = getattr(self, f'{instance_type.upper()}_DEF_TARGETS')
        if name not in instance_def_targets.keys():
            if not os.path.exists(shared_file):
                instance_def_targets[name] = []
            else:
                instance_def_targets[name] = mcux_read_yaml(shared_file).get(f'{instance_type}.toolchains', [])

        for toolchain_target in instance_def_targets[name]:
            self.inject_target(toolchain_target)

    def inject_targets_from_instance_default(self, instance_core, instance_type):
        instance = re.sub(r'@.*$', '', instance_core)
        self.inject_targets_from_shared_file(
            instance_core,
            os.path.join(sdk_root_dir, f"examples/_{instance_type}s/{instance_core.replace('@', '/')}/example.yml"),
            instance_type
        )

        self.inject_targets_from_shared_file(
            instance,
            os.path.join(sdk_root_dir, f"examples/_{instance_type}s/{instance}/example.yml"),
            instance_type
        )

    def inject_targets_from_instance_category(self, instance, category, instance_type):
        return self.inject_targets_from_shared_file(
            f'{instance}@{category}',
            os.path.join(sdk_root_dir, f"examples/_{instance_type}s/{instance}/{category}/example.yml"),
            instance_type
        )

    def inject_targets_from_app_category(self, category, instance_type='board'):
        return self.inject_targets_from_shared_file(
            f'src@{category}',
            os.path.join(sdk_root_dir, f"examples/{category}/example.yml"),
            instance_type
        )

    def inject_targets_from_app(self, app_instance_core_target_delta):
        for toolchain_target in app_instance_core_target_delta:
            self.inject_target(toolchain_target)

    def do_filter(self, input_string: str, in_filter_list: list, exclude_filter_list: list)->bool:
        """Filter the input string with the filter list by exact match or regex match

        Args:
            input_string (str): _description_
            filter_list (list): if member starts with 'r@', it will be treated as regex match with follwing string, else exact match

        Returns:
            bool: True means at least one filter matches the input string. False means no filter matches the input string
        """
        ret = False
        # Filter for the include
        if in_filter_list:
            for filter in in_filter_list:
                if filter.startswith('r@') and re.search(filter[2:], input_string):
                    ret = True
                    break
                elif filter == input_string:
                    ret = True
                    break
        else:
            ret = True
        if not ret:
            # mcux_debug(f'Filtered out {input_string} by include')
            return False
        # Continue to filter for the exclude if not filtered out by the include filter
        if exclude_filter_list:
            for filter in exclude_filter_list:
                if filter.startswith('r@') and re.search(filter[2:], input_string):
                    # mcux_debug(f'Filtered out {input_string} by exclude')
                    return False
                elif filter == input_string:
                    # mcux_debug(f'Filtered out {input_string} by exclude')
                    return False
        return True

    def filter_target(self, target):
        return self.do_filter(target, self.TARGETS_FILTER, self.TARGETS_EXCLUDE_FILTER)

    def filter_toolchain(self, toolchain):
        return self.do_filter(toolchain, self.TOOLCHAINS_FILTER, self.TOOLCHAINS_EXCLUDE_FILTER)

    def filter_board_core(self, board_core):
        return self.do_filter(board_core, self.BOARDS_FILTER, self.BOARDS_EXCLUDE_FILTER)
    
    def filter_device_core(self, device_core):
        return self.do_filter(device_core, self.DEVICES_FILTER, self.DEVICES_EXCLUDE_FILTER)

    def filter_shield(self, shield):
        return self.do_filter(shield, self.SHIELDS_FILTER, self.SHIELDS_EXCLUDE_FILTER)

    def get_app_targets(self, app_example_file: str, is_pick_one_target_for_app=False, validate=False) -> list:
        apps = []
        app_dir = os.path.relpath(os.path.dirname(app_example_file), sdk_root_dir)
        example_data = mcux_read_yaml(app_example_file)
        if validate:
            self._validate_example_data(app_example_file, example_data)

        if not example_data:
            mcux_error(f"Invalid example file {app_example_file}")
            return apps

        for app_name, app_data in example_data.items():
            if app_data.get('skip_build', False):
                continue
            if (boards_data := app_data.get('boards', {})):
                self.get_instance_targets(app_dir, apps, app_name, app_data, boards_data, is_pick_one_target_for_app, 'board')
            elif (devices_data := app_data.get('devices', {})):
                self.get_instance_targets(app_dir, apps, app_name, app_data, devices_data, is_pick_one_target_for_app, 'device')

        return apps

    def get_instance_targets(self, app_dir, apps, app_name, app_data, instance_data, is_pick_one_target_for_app=False, instance_type='board'):
        assert(instance_type in ['board', 'device'])
        if app_name in MCUXAppTargets.INT_EXAMPLE_DATA:
            instance_data = { **instance_data, **MCUXAppTargets.INT_EXAMPLE_DATA[app_name] }
        use_sysbuild = app_data.get('use_sysbuild', False)

        extra_build_args = app_data.get('contents', {}).get('document', {}).get('extra_build_args', [])
        app_toolchains = app_data.get('contents', {}).get('toolchains', [])
        app_category = app_data.get('contents', {}).get('document', {}).get('category', app_dir.replace('\\', '/').split('/')[1])
        # SDKGEN-3118 Currently one example shall be bound with only one shield
        shield = list(app_data['shields'])[0] if app_data.get('shields', {}).keys() else None
        if shield and not self.filter_shield(shield):
            return
        for instance_core, instance_core_delta_data in instance_data.items():
            if not getattr(self, f'filter_{instance_type}_core')(instance_core):
                continue
            self.reset_targets()

            instance, core_id = instance_core.split('@') if '@' in instance_core else (instance_core, '')
            # Parse the targets
            self.inject_targets_from_instance_default(instance_core, instance_type)
            self.inject_targets_from_instance_category(instance, app_category, instance_type)
            self.inject_targets_from_app_category(app_category, instance_type)
            if instance_core_delta_data:
                self.inject_targets_from_app(instance_core_delta_data)
            elif app_toolchains:
                self.inject_targets_from_app(app_toolchains)
            for toolchain_target, is_enabled in self.tgt_dict.items():
                if not is_enabled:
                    continue
                toolchain, target = toolchain_target.split('@')
                if not self.filter_toolchain(toolchain) or not self.filter_target(target):
                    continue
                real_app_name = app_name.replace('${core_id}', core_id)
                apps.append(MCUXProjectData.from_fields(
                    name=real_app_name,
                    board=instance if instance_type=='board' else None,
                    device=instance if instance_type=='device' else None,
                    core_id=core_id,
                    toolchain=toolchain,
                    target=target,
                    project_file=app_dir,
                    category=app_category,
                    use_sysbuild=use_sysbuild,
                    shield=shield,
                    extra_build_args=extra_build_args
                ))
                if is_pick_one_target_for_app:
                    break

    def _validate_example_data(self, example_yml, example_data):
        import jsonschema as js
        example_schema = mcux_read_json((Path(sdk_root_dir) / SCHEMA_DIR / EXAMPLE_YML_SCHEMA).as_posix())
        definition_schema = mcux_read_json((Path(sdk_root_dir) / SCHEMA_DIR / DEFINITION_YAL_SCHEMA).as_posix())
        schema_store = {
            example_schema['$id']: example_schema,
            definition_schema['$id']: definition_schema,
        }
        resolver = js.RefResolver.from_schema(example_schema, store=schema_store)
        try:
            js.Draft7Validator(example_schema, resolver=resolver).validate(example_data)
        except js.ValidationError as e:
            mcux_error(example_yml + ': ' + e.message)

class MCUXRepoProjects(object):

    def __init__(self):
        super().__init__()

    def search_app_targets(
            self,
            app_path,
            board_cores_filter=[],
            shields_filter=[],
            devices_filter=[],
            toolchains_filter=[],
            targets_filter=[],
            is_pick_one_target_for_app=False,
            validate=False):
        matched_apps = []

        # Setup filter
        MCUXAppTargets.config_filter(
            toolchains_filter=toolchains_filter,
            boards_filter=board_cores_filter,
            shields_filter=shields_filter,
            devices_filter=devices_filter,
            targets_filter=targets_filter,
        )

        # Search for app targets
        example_file_pattern = os.path.join(sdk_root_dir, app_path , '**/example.yml')
        expanded_example_files = glob.glob(example_file_pattern, recursive=True)
        #print(expanded_example_files)
        expanded_example_files_filtered = []
        for example_file in expanded_example_files:
            example_category = Path(example_file).relative_to(Path(sdk_root_dir)).parts[1]
            if example_category not in ["_boards", "_devices"]:
                expanded_example_files_filtered.append(example_file)

        # mcux_debug(f"Searching app targets in {example_file_pattern}")
        for example_file in expanded_example_files_filtered:
            #print(example_file)
            mcux_debug(f"Found example file {example_file}")
            app_target_op = MCUXAppTargets()
            matched_apps.extend(app_target_op.get_app_targets(example_file, is_pick_one_target_for_app, validate))
        mcux_debug(f"Found {len(matched_apps)} matched apps in total")

        return matched_apps

    def dump_to_file(self, export_file, apps):
        if export_file and export_file.endswith('.json'):
            mcux_write_json(export_file, [item.as_dict() for item in apps], is_create_dir=True)
            mcux_small_banner(f"Exported {len(apps)} matched apps to {export_file}")
        elif export_file and export_file.endswith('.yml'):
            mcux_write_yaml(export_file, [item.as_dict() for item in apps], is_create_dir=True)
            mcux_small_banner(f"Exported {len(apps)} matched apps to {export_file}")
        elif export_file and export_file.endswith('.robot'):
            with open(export_file, 'w') as file:
                # Write Settings
                file.write('*** Settings ***\n')
                file.write('Library           OperatingSystem\n')
                file.write('Library           Process\n\n')

                # Write Variables
                file.write('*** Variables ***\n')
                file.write(f'${{SDK_ROOT_DIR}}    ' + sdk_root_dir + '\n\n')

                # Write Test Cases
                file.write('*** Test Cases ***\n')
                for app in apps:
                    file.write(f'Test {app.name} Build' + '\n')
                    file.write(f'    [Tags]    {app.name}    {app.board_core}    {app.category}    {app.toolchain}    {app.target}' + '\n')
                    file.write(f'    ${{app_result}}=    Run Process    {app.build_cmd}    shell=True    cwd=${{SDK_ROOT_DIR}}    timeout=5 minutes' + '\n')  # Execute build_cmd in sdk_root_dir
                    file.write('    Log    ${{app_result.stdout}}\n')
                    file.write('    Log    ${{app_result.stderr}}\n')
                    file.write('    Should Be Equal As Integers    ${{app_result.rc}}    0\n\n')
        else:
            mcux_error(f"Invalid export file {export_file}")

    def pretty_print_apps(self, apps):
        for idx, app in enumerate(apps):
            mcux_info(f"[{idx+1:4}][{app.build_cmd}]")

    def silent_print_apps(self, apps):
        for app in apps:
            print(app.build_cmd)
