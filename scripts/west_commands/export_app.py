import os
import argparse
import platform
import yaml
import logging
import shutil
from subprocess import CalledProcessError, DEVNULL
from copy import deepcopy
from pathlib import Path
from west.commands import WestCommand

_ARG_SEPARATOR = '--'
SCRIPT_DIR = Path(__file__).parent.parent
SDK_ROOT_DIR = SCRIPT_DIR.parent
DOC_URL = 'https://mcuxpresso.nxp.com/mcuxsdk/latest/html/develop/build_system/Build_And_Configuration_System_Based_On_CMake_And_Kconfig.html#freestanding-example'
# VARIABLES_MAP = {
#     '${SdkRootDirPath}': '${PrjRootDirPath}'
#     }
USAGE = '''\
west export_app [-h] [source_dir] [-o OUTPUT_DIR]
'''
logger = logging.getLogger('export_app.misc')

def cmake_func(func):
    def wrapper(cls, func_args):
        if not isinstance(func_args, dict):
            raise InvalidCmakeMethod(func.__name__, 'Invalid function argument type, should be dict.')
        if (cm_func_name := func_args.get('original_name', '').lower()) != func.__name__.replace('cm_', ''):
            raise InvalidCmakeMethod(func.__name__, f'The cmake function name {cm_func_name} is not aligned with class method name.')
        return cmake_statement(func(cls, func_args, ExtensionMap.parser_args(func_args)))
    return wrapper

def cmake_statement(func):
    args = ' '.join([arg.get('value') for arg in func.get('args', [])])
    return f"{func['original_name']}({args})"


class InvalidCmakeMethod(Exception):
    def __init__(self, func_name='undefined', msg=None, *args, **kwargs):
        super().__init__(f'{func_name}: {msg}', *args, **kwargs)

class PlatformNotSupported(Exception):
    def __init__(self, arch, sys_name, msg=None, *args, **kwargs):
        msg = msg or f"""The tool we used to parse cmake file does not support {arch}_{sys_name}, please contact us."""
        super().__init__(msg, *args, **kwargs)

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
        extensions = yaml.load(open(extension_yml, 'r'), yaml.Loader)
        variables = extensions.get('__variables__', {})
        del extensions['__variables__']
        extensions = yaml.dump(extensions)
        for k, v in variables.items():
            extensions = extensions.replace(f"${{{k}}}", v)

        return yaml.load(extensions, yaml.Loader)

    _extensions = extensions()

    @classmethod
    def get_raw_args(cls, func_name):
        options = cls._extensions[func_name].get('options', '').split(' ')
        single_args = cls._extensions[func_name].get('single_value', '').split(' ')
        multi_args = cls._extensions[func_name].get('multi_value', '').split(' ')
        return options, single_args, multi_args

    @classmethod
    def parser_args(cls, func):
        cur_arg = None
        result = {
            'nargs': []
        }
        options, single_args, multi_args = cls.get_raw_args(func['original_name'].lower())

        for cm_arg in func['args']:
            cm_val = cm_arg['value']
            if cm_val in options:
                result['nargs'].append(cm_val)
                continue
            if cm_val in single_args or cm_val in multi_args:
                cur_arg = cm_val
                continue
            if not cur_arg:
                result['nargs'].append(cm_val)
                continue

            cm_val = cls.CM_VAL_MAP.get(cm_val) or cm_val
            if cur_arg in single_args:
                result[cur_arg] = cm_val
                cur_arg = None
            elif cur_arg in multi_args:
                if cur_arg not in result:
                    result[cur_arg] = []
                result[cur_arg].append(cm_val)

        return result

class ExportApp(WestCommand):
    def __init__(self):
        super().__init__(
            'export_app',
            'Create a freestanding application',
            f'Create a freestanding application. For more info about freestanding app, see {DOC_URL}',
            accepts_unknown_args=True
        )
        self.cmparser = None

    def do_add_parser(self, parser_adder):
        parser = parser_adder.add_parser(
            self.name,
            help=self.help,
            formatter_class=argparse.RawDescriptionHelpFormatter,
            description=self.description,
            usage=USAGE)
        # Hidden option for backwards compatibility
        parser.add_argument('-o', '--output-dir',
                            help='output directory to hold the freestanding project')
        return parser
    
    def do_run(self, args, remainder):
        self.args = args
        # To align with west build usage
        self._parse_remainder(remainder)
        self._sanity_precheck()
        self._find_parser()
        self.parse_app()
        self.format_listfile()
        self.banner(f'Successfully create the freestanding project, see {self.dest_list_file.as_posix()}')

    def parse_app(self):
        self.output_dir.mkdir(exist_ok=True)
        self.dest_list_file = self.output_dir / self.source_dir.relative_to(SDK_ROOT_DIR) / 'CMakeLists.txt'
        shutil.copytree(self.source_dir, self.output_dir / self.dest_list_file.parent)
        list_file = self.source_dir / 'CMakeLists.txt'
        completed_process = self.run_subprocess(
            [self.cmparser.as_posix(), list_file.as_posix()],
            capture_output=True,
            text=True
        )
        self.check_force(completed_process.returncode == 0, f'Cannot parse {list_file.as_posix()}: {completed_process.stderr}')
        io_content = completed_process.stdout
        list_content = yaml.load(io_content, yaml.Loader)
        new_list_content = []
        for func in list_content:
            try:
                func_name = func['original_name'].lower()
                if hasattr(self, f'cm_{func_name}'):
                    result = getattr(self, f'cm_{func_name}')(func)
                    new_list_content.append(result)
                else:
                    self.dbg(f'No special process for {func_name}')
                    new_list_content.append(cmake_statement(func))
            except KeyError as exec:
                print(str(exec))
                self.die(f'The cmparser cannot handle the given CMakeLists.txt.')
            except InvalidCmakeMethod as exec:
                print(str(exec))
                self.die(f'Script error, please contact us.')
        open(self.dest_list_file, 'w').write(os.linesep.join(new_list_content))

    def format_listfile(self):
        try:
            # cmake-format can be used only by cli due to license
            self.check_call(['cmake-format', '-v'], stdout=DEVNULL)

            cmd = ['cmake-format', '--in-place']
            # if (default_config_file := (SDK_ROOT_DIR / 'cmake_format_config.yml')).exists():
            #     cmd.extend(['-c', default_config_file.as_posix()])
            cmd.extend(['--', self.dest_list_file.as_posix()])
            self.run_subprocess(cmd)
        except CalledProcessError:
            self.wrn('Please run "pip install cmake-format" to get a formatted CMakeLists.txt')
            return False

        return True

    @cmake_func
    def cm_mcux_add_source(self, func: dict, argv: dict) -> dict:
        base_path = argv.get('BASE_PATH')
        updated_func = deepcopy(func)
        for src in argv.get('SOURCES'):
            ExportApp.update_func_val(updated_func, src, self._process_path(base_path, src))
        if base_path:
            ExportApp.update_func_val(updated_func, base_path, base_path.replace('${SdkRootDirPath}', '${PrjRootDirPath}'))
        return updated_func

    @cmake_func
    def cm_mcux_add_include(self, func: dict, argv: dict) -> dict:
        base_path = argv.get('BASE_PATH')
        updated_func = deepcopy(func)
        for inc in argv.get('INCLUDES'):
            ExportApp.update_func_val(updated_func, inc, self._process_path(base_path, inc, 'inc'))
        if base_path:
            ExportApp.update_func_val(updated_func, base_path, base_path.replace('${SdkRootDirPath}', '${PrjRootDirPath}'))
        return updated_func

    def check_force(self, cond, msg):
        if not cond:
            self.die(msg)

    # TODO this is not safe
    @staticmethod
    def update_func_val(func, old_val, new_val):
        for arg in func.get('args', []):
            if arg['value'] == old_val:
                arg['value'] = new_val

    def _process_path(self, base_path=None, src='', type='file'):
        result = src
        if base_path:
            s_src = SDK_ROOT_DIR / base_path.replace('${SdkRootDirPath}', '') / src
        else:
            if '${SdkRootDirPath}/' in src:
                s_src = SDK_ROOT_DIR / src.replace('${SdkRootDirPath}', '') 
                result = src.replace('${SdkRootDirPath}', '${PrjRootDirPath}') 
            else:
                s_src = self.source_dir / src
        if not s_src.exists():
            self.err(f'Cannot handle path {s_src}')
        else:
            d_src = (self.output_dir / s_src.relative_to(SDK_ROOT_DIR))
            if type == 'file':
                os.makedirs(d_src.parent, exist_ok=True)
                shutil.copy(s_src, d_src)
            elif type == 'inc':
                os.makedirs(d_src, exist_ok=True)
                for f in s_src.iterdir():
                    if f.is_file():
                        shutil.copy(f, d_src / f.name)
        return result

    def _parse_remainder(self, remainder):
        self.args.source_dir = None

        try:
            # Only one source_dir is allowed, as the first positional arg
            if remainder[0] != _ARG_SEPARATOR:
                self.args.source_dir = remainder[0]
        except IndexError:
            pass

    def _sanity_precheck(self):
        app = self.args.source_dir
        self.check_force(
            os.path.isdir(app),
            'source directory {} does not exist'.format(app))
        self.check_force(
            'CMakeLists.txt' in os.listdir(app),
            "{} doesn't contain a CMakeLists.txt".format(app))
        out = self.args.output_dir
        self.check_force(
            (not os.path.isdir(out)) or (len(os.listdir(out)) == 0),
            f'Output directory {out} is not empty, please remove it first')

        self.source_dir = Path(app).resolve()
        self.output_dir = Path(out).resolve()
            
    def _find_parser(self):
        arch = platform.machine()
        sys_name = platform.system()
        try:
            if arch in ['x86_64', 'AMD64']:
                if sys_name == 'Windows':
                    self.cmparser = 'cmparser.exe'
                elif sys_name == 'Linux':
                    self.cmparser = 'cmparser'
                else:
                    raise PlatformNotSupported(arch, sys_name)
            elif arch in ['arm64']:
                if sys_name == 'Darwin':
                    self.cmparser = 'cmparser_darwin_arm64'
                else:
                    raise PlatformNotSupported(arch, sys_name)
            else:
                raise PlatformNotSupported(arch, sys_name)
        except PlatformNotSupported as exec:
            print(str(exec))
            self.die('Not able to parse CMake file.')
        self.cmparser = SCRIPT_DIR / 'resources/cmparser' / self.cmparser

        if not self.cmparser.exists():
            self.die(f'{self.cmparser} does not exist, please check whether your branch is up-to-date.')

