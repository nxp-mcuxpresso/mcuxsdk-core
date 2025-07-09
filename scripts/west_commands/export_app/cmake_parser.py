# Copyright 2025 NXP
#
# SPDX-License-Identifier: Apache-2.0

import yaml
import platform
import logging
import subprocess
from pathlib import Path
from jinja2 import Template
from requests.structures import CaseInsensitiveDict
SCRIPT_DIR = Path(__file__).parent.parent.parent
SDK_ROOT_DIR = SCRIPT_DIR.parent
logger = logging.getLogger(__name__)

RENDER_TEMPLATE = '''
{{ func.name }}(
{%- if func.nargs %}
    {{ ' '.join(func.nargs) }}
{%- endif %}
{%- for arg_name, arg_data in func.single_args.items() %}
    {{ arg_name }} {{ arg_data }}
{%- endfor %}
{%- for arg_name, arg_data in func.multi_args.items() %}
    {%- if arg_name in ['SOURCES', 'INCLUDES', 'TARGET_FILES'] %}
    {{ arg_name }} {{ arg_data[0] }}
    {%- for rest in arg_data[1:] %}
    {{ ' ' * (arg_name|length) }} {{ rest }}
    {%- endfor %}
    {%- else %}
    {{ arg_name }} {{ ' '.join(arg_data) }}
    {%- endif %}
{%- endfor %}
)
'''

class PlatformNotSupported(Exception):
    def __init__(self, arch, sys_name, msg=None, *args, **kwargs):
        msg = msg or f"""The tool we used to parse cmake file does not support {arch}_{sys_name}, please contact us."""
        super().__init__(msg, *args, **kwargs)

class InvalidCmakeMethod(Exception):
    def __init__(self, func_name='undefined', msg=None, *args, **kwargs):
        super().__init__(f'{func_name}: {msg}', *args, **kwargs)


def _find_parser():
    arch = platform.machine()
    sys_name = platform.system()
    result = None

    if arch in ['x86_64', 'AMD64']:
        if sys_name == 'Windows':
            result = 'cmparser.exe'
        elif sys_name == 'Linux':
            result = 'cmparser'
        elif sys_name == 'Darwin':
            result = 'cmparser_darwin_x86_64'
    elif arch in ['arm64']:
        if sys_name == 'Darwin':
            result = 'cmparser_darwin_arm64'

    if not result:
        logger.fatal(f'Unsupported platform: {arch}_{sys_name}')
        return None
    result = SCRIPT_DIR / 'resources/cmparser' / result

    if not result.exists():
        logger.fatal(f'{result} does not exist, please check whether your branch is up-to-date.')
        return None
    return result

cmparser = _find_parser()

def parse_cmake_file(list_file: Path):
    '''
    Parse the cmake file and return the function list

    Args:
        list_file (Path): The cmake file to parse

    Returns:
        list: The parsed function list
        None: Invalid cmake file
    '''
    completed_process = subprocess.run(
        [cmparser.as_posix(), list_file.as_posix()],
        capture_output=True,
        text=True
    )
    if completed_process.returncode != 0:
        logger.error(f'Cannot parse {list_file.as_posix()}: {completed_process.stderr}')
        return None
    return yaml.load(completed_process.stdout, yaml.BaseLoader)

def cmake_func(func):
    def wrapper(cls, func_args):
        if not isinstance(func_args, dict):
            raise InvalidCmakeMethod(func.__name__, 'Invalid function argument type, should be dict.')
        if not (ret_func := func(cls, func_args, CMakeFunction(func_args))):
            return None
        if isinstance(ret_func, list):
            return [cmake_statement(r) for r in ret_func]
        else:
            return cmake_statement(ret_func)
    return wrapper

def cmake_statement(func):
    if isinstance(func, str):
        return func
    template = Template(RENDER_TEMPLATE)
    return template.render(func=func)

class CMakeFunction(object):
    def __init__(self, raw):
        self.raw = raw
        self.name = raw['original_name']
        self.nargs = []
        self.single_args = CaseInsensitiveDict()
        self.multi_args = CaseInsensitiveDict()
        self._parse()

    def _parse(self):
        cur_arg = None
        if self.raw['original_name'].lower() not in ExtensionMap._extensions:
            raise KeyError(f'Cannot find {self.raw["original_name"].lower()} in extensions.yml')
        options, single_args, multi_args = ExtensionMap.get_raw_args(self.raw['original_name'].lower())

        for cm_arg in self.raw['args']:
            cm_val = cm_arg['value']
            if cm_val in options:
                self.nargs.append(cm_val)
                continue
            if cm_val in single_args or cm_val in multi_args:
                cur_arg = cm_val
                continue
            if not cur_arg:
                self.nargs.append(cm_val)
                continue

            cm_val = ExtensionMap.CM_VAL_MAP.get(cm_val) or cm_val
            if cur_arg in single_args:
                self.single_args[cur_arg] = cm_val
                cur_arg = None
            elif cur_arg in multi_args:
                if cur_arg not in self.multi_args:
                    self.multi_args[cur_arg] = []
                self.multi_args[cur_arg].append(cm_val)

    def remove_value(self, key, value):
        def remove_value_from_list(lst, value):
            return list(filter(lambda x: x != value, lst))

        if not key:
            self.nargs = remove_value_from_list(self.nargs, value)
        if key in self.single_args:
            del self.single_args[key]
        elif key in self.multi_args:
            self.multi_args[key] = remove_value_from_list(self.multi_args[key], value)
            if not self.multi_args[key]:
                del self.multi_args[key]

class ExtensionMap(object):
    CM_VAL_MAP = {
        'HAS_DSP': 'DSP',
        'HAS_MPU': 'MPU'
    }

    @staticmethod
    def extensions():
        if not (extension_yml := SCRIPT_DIR / 'resources/cmparser/extensions.yml').exists():
            logger.fatal(f'Mandatory resource {extension_yml.as_posix()} does not exist!')
            return {}
        result = {
            'target_link_libraries': {}
        }
        extensions = yaml.load(open(extension_yml, 'r'), yaml.BaseLoader)
        variables = extensions.get('__variables__', {})
        del extensions['__variables__']
        extensions = yaml.dump(extensions)
        for k, v in variables.items():
            extensions = extensions.replace(f"${{{k}}}", v)

        result.update(yaml.load(extensions, yaml.BaseLoader))
        return result

    _extensions = extensions.__func__()

    @classmethod
    def get_raw_args(cls, func_name):
        '''
        Get the raw arguments of the cmake function from the scripts/resources/cmparser/extensions.yml file.

        Args:
            func_name (str): The name of the cmake function.
        Returns:
            tuple: A tuple of three lists, the first list is the options, the second list is the single value arguments,
            and the third list is the multi value arguments.
        '''
        options = cls._extensions[func_name].get('options', '').split(' ')
        single_args = cls._extensions[func_name].get('single_value', '').split(' ')
        multi_args = cls._extensions[func_name].get('multi_value', '').split(' ')
        # Ignore case
        options = [_.lower() for _ in options] + [_.upper() for _ in options]
        single_args = [_.lower() for _ in single_args] + [_.upper() for _ in single_args]
        multi_args = [_.lower() for _ in multi_args] + [_.upper() for _ in multi_args]
        return options, single_args, multi_args
