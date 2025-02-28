import os, sys
import argparse
import platform
import yaml
import logging
import shutil
import re
from subprocess import CalledProcessError, DEVNULL
from copy import deepcopy
from pathlib import Path
from west.commands import WestCommand

SCRIPT_DIR = Path(__file__).parent.parent
sys.path.append(SCRIPT_DIR.as_posix())
from misc import sdk_project_target

_ARG_SEPARATOR = '--'
SDK_ROOT_DIR = SCRIPT_DIR.parent
BOARD_DIR_NAME = '_boards'
DOC_URL = 'https://mcuxpresso.nxp.com/mcuxsdk/latest/html/develop/build_system/Build_And_Configuration_System_Based_On_CMake_And_Kconfig.html#freestanding-example'
# VARIABLES_MAP = {
#     '${SdkRootDirPath}': '${PrjRootDirPath}'
#     }
USAGE = f'''\
west export_app [-h] [source_dir] [-b board_id] [-DCMAKE_VAR=VAL] [-o OUTPUT_DIR] [--build]
You can use -Dcore_id=xxx to export multi-core example.
To know what is freestanding example and how it works, see
{DOC_URL}
'''

logger = logging.getLogger('export_app.misc')

def cmake_func(func):
    def wrapper(cls, func_args):
        if not isinstance(func_args, dict):
            raise InvalidCmakeMethod(func.__name__, 'Invalid function argument type, should be dict.')
        if (cm_func_name := func_args.get('original_name', '').lower()) != func.__name__.replace('cm_', ''):
            raise InvalidCmakeMethod(func.__name__, f'The cmake function name {cm_func_name} is not aligned with class method name.')
        ret_func = func(cls, func_args, ExtensionMap.parser_args(func_args)) or func_args
        if isinstance(ret_func, list):
            return [cmake_statement(r) for r in ret_func]
        else:
            return cmake_statement(ret_func)
    return wrapper

def cmake_statement(func):
    if isinstance(func, str):
        return func
    args = ' '.join([arg.get('value') for arg in func.get('args', [])])
    return f"{func['original_name']}({args})"

def current_list_dir_context(func):
    def wrapper(self, source_dir: Path):
        backup = self.current_list_dir
        self.current_list_dir = '${SdkRootDirPath}/' + source_dir.relative_to(SDK_ROOT_DIR).as_posix()
        ret = func(self, source_dir)
        self.current_list_dir = backup
        return ret
    return wrapper

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
        extensions = yaml.load(open(extension_yml, 'r'), yaml.BaseLoader)
        variables = extensions.get('__variables__', {})
        del extensions['__variables__']
        extensions = yaml.dump(extensions)
        for k, v in variables.items():
            extensions = extensions.replace(f"${{{k}}}", v)

        return yaml.load(extensions, yaml.BaseLoader)

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
            f'Create a freestanding application.',
            accepts_unknown_args=True
        )
        self.cmparser = None
        self.sysbuild = False
        self.current_list_dir = None
        self.core_id = None

    def do_add_parser(self, parser_adder):
        parser = parser_adder.add_parser(
            self.name,
            help=self.help,
            formatter_class=argparse.RawDescriptionHelpFormatter,
            description=self.description,
            usage=USAGE)
        parser.add_argument('-b', '--board', nargs=None, default=None, help="board id like mimxrt700evk", required=True)
        parser.add_argument('--toolchain', dest='toolchain', action='store',
                           default='armgcc', help='Specify toolchain')
        parser.add_argument('-o', '--output-dir', required=True,
                            help='output directory to hold the freestanding project')
        parser.add_argument('--build', action="store_true", default=False, help="Build the project after creating.")
        return parser
    
    def do_run(self, args, remainder):
        self.args = args
        # To align with west build usage
        self._parse_remainder(remainder)
        self._sanity_precheck()
        self._app_precheck()
        self._find_parser()
        self.output_dir.mkdir(exist_ok=True)
        self.dest_list_file = self.parse_app(self.source_dir)
        self.dest_prj_conf = self.dest_list_file.parent  / 'prj.conf'
        self.banner(f'Successfully create the freestanding project, see {self.dest_list_file}.')
        if self.args.build:
            self.banner('Start building the project')
            self.run_subprocess(self.build_cmd_list, cwd=SDK_ROOT_DIR.as_posix())
        else:
            self.banner('you can use following command to build it.')
        print(self.build_cmd)

    @current_list_dir_context
    def parse_app(self, source_dir):
        dest_list_file = self.output_dir / source_dir.relative_to(SDK_ROOT_DIR) / 'CMakeLists.txt'
        shutil.copytree(source_dir, dest_list_file.parent)
        example_yml = yaml.load(open(source_dir / 'example.yml'), yaml.BaseLoader)
        _, example_info = next(iter(example_yml.items()))

        list_file = source_dir / 'CMakeLists.txt'
        list_content = self._parse_list_file(list_file)
        new_list_content = []
        for func in list_content:
            try:
                func_name = func['original_name'].lower()
                if hasattr(self, f'cm_{func_name}'):
                    result = getattr(self, f'cm_{func_name}')(func)
                    if isinstance(result, list):
                        new_list_content.extend(result)
                    elif isinstance(result, str):
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
        open(dest_list_file, 'w').write(os.linesep.join(new_list_content))
        self.format_listfile(dest_list_file)
        self.combine_prj_conf(source_dir)
        self.update_kconfig_path(source_dir)

        if example_info.get('use_sysbuild'):
            self.sysbuild = True
            self.parse_linked_app(source_dir)

        return dest_list_file

    def parse_linked_app(self, source_dir):
        self.check_force(
            'sysbuild.cmake' in os.listdir(source_dir),
            "{} doesn't contain a sysbuild.cmake".format(source_dir))
        
        sysbuild_content = self._parse_list_file(source_dir / 'sysbuild.cmake')
        for func in sysbuild_content:
            if func['original_name'].lower() not in ['externalzephyrproject_add', 'externalmcuxproject_add']:
                continue
            linked_source = None
            for arg in func.get('args', []):
                if arg['value'].upper() == 'SOURCE_DIR':
                    linked_source = True
                    continue
                if linked_source:
                    linked_source = arg['value']
                    break
            self.check_force(
                isinstance(linked_source, str),
                "Cannot find correct SOURCE_DIR from sysbuild.cmake")
            linked_source = Path(linked_source.replace('${APP_DIR}', source_dir.as_posix())).resolve()
            self.check_force(
                linked_source.exists(),
                f"Cannot find the sysbuild app dir {linked_source.as_posix()}")
            self.parse_app(linked_source)

    def combine_prj_conf(self, source_dir):
        example_root_stem = self.examples_root.stem
        prj_conf = {}
        search_list = []
        example_common = source_dir
        while example_common.stem != example_root_stem:
            search_list.insert(0, example_common)
            example_common = example_common.parent
        example_common_len = len(search_list)
        example_specific = SDK_ROOT_DIR / example_root_stem / BOARD_DIR_NAME / self.board / source_dir.relative_to(self.examples_root)
        if self.core_id:
            example_specific = example_specific / self.core_id
        while example_specific.stem != self.board:
            search_list.insert(example_common_len, example_specific)
            example_specific = example_specific.parent
        for s_p in search_list:
            if not (e_conf := (s_p / 'prj.conf')).exists():
                continue
            for k, v in ExportApp.parse_prj_conf(e_conf).items():
                prj_conf[k] = v
        with open(self.output_dir / source_dir.relative_to(SDK_ROOT_DIR) / 'prj.conf', 'w') as f:
            for k, v in prj_conf.items():
                f.write(f"{k}={v}\n")

    def update_kconfig_path(self, source_dir):
        for f in source_dir.iterdir():
            if not f.stem.startswith('Kconfig'):
                continue
            kconfig_content = open(f, 'r').read().splitlines()
            for i, line in enumerate(kconfig_content):
                if not 'source' in line:
                    continue
                line = self.replace_var(line, ['SdkRootDirPath'])
                prefix_id = re.search(r'[ro]*source\s*', line).group(0)
                rel_kconfig_path = line.replace(prefix_id, '').replace('"', '').replace("'", '').strip()
                # Only process rsource
                if '${SdkRootDirPath}' in rel_kconfig_path or 'rsource' not in prefix_id:
                    kconfig_content[i] = line
                    continue
                dest_kconfig_path = '"${SdkRootDirPath}/' + (source_dir / rel_kconfig_path).resolve().relative_to(SDK_ROOT_DIR).as_posix() + '"'
                kconfig_content[i] = prefix_id + dest_kconfig_path
            open(self.output_dir / source_dir.relative_to(SDK_ROOT_DIR) / f.name, 'w').write(os.linesep.join(kconfig_content))

    def _parse_list_file(self, list_file):
        completed_process = self.run_subprocess(
            [self.cmparser.as_posix(), list_file.as_posix()],
            capture_output=True,
            text=True
        )
        self.check_force(completed_process.returncode == 0, f'Cannot parse {list_file.as_posix()}: {completed_process.stderr}')
        return yaml.load(completed_process.stdout, yaml.BaseLoader)

    @property
    def build_cmd_list(self):
        cmd_list = ['west', 'build', '-b', self.board, '--toolchain', self.args.toolchain,
                    '-p', 'always', self.dest_list_file.parent.as_posix(),
                    f'-DPrjRootDirPath={self.output_dir.as_posix()}',
                    '-d', (self.output_dir/'build').as_posix(),
                    ]
        if self.sysbuild:
            cmd_list.append('--sysbuild')
        if self.args.cmake_opts:
            cmd_list.extend(self.args.cmake_opts)
        return cmd_list

    @property
    def build_cmd(self):
        return ' '.join(self.build_cmd_list)

    @staticmethod
    def parse_prj_conf(path):
        result = {}
        for line in open(path).read().splitlines():
            if len(conf := line.split('=')) != 2:
                continue
            result[conf[0]] = conf[1]
        return result

    def format_listfile(self, list_file: Path):
        try:
            # cmake-format can be used only by cli due to license
            self.check_call(['cmake-format', '-v'], stdout=DEVNULL)

            cmd = ['cmake-format', '--in-place']
            if (default_config_file := (SDK_ROOT_DIR / 'cmake_format_config.yml')).exists():
                cmd.extend(['-c', default_config_file.as_posix()])
            cmd.extend(['--', list_file.as_posix()])
            self.run_subprocess(cmd)
        except (CalledProcessError, FileNotFoundError):
            self.wrn('Please run "pip install -U cmake-format" to get a formatted CMakeLists.txt')
            return False

        return True

    @cmake_func
    def cm_include(self, func: dict, argv: dict) -> dict:
        for arg in func.get('args'):
            arg['value'] = arg['value'].replace('${CMAKE_CURRENT_LIST_DIR}', self.current_list_dir)

    @cmake_func
    def cm_project(self, func: dict, argv: dict) -> dict:
        if 'PROJECT_BOARD_PORT_PATH' not in argv:
            return
        new_result = [func]
        ExportApp.remove_arg(func, argv, 'PROJECT_BOARD_PORT_PATH')
        project_board_port_path = argv['PROJECT_BOARD_PORT_PATH']
        self.cmake_variables['project_board_port_path'] = project_board_port_path
        new_result.append(f'mcux_set_variable(project_board_port_path {project_board_port_path})')
        return new_result

    @cmake_func
    def cm_mcux_add_source(self, func: dict, argv: dict) -> dict:
        base_path = argv.get('BASE_PATH')
        keep_in_repo_paths = []
        for src in argv.get('SOURCES'):
            processed_path = self._process_path(base_path, src)
            if processed_path.startswith('${SdkRootDirPath}/'):
                keep_in_repo_paths.append(processed_path.replace('${SdkRootDirPath}/', ''))
                ExportApp.remove_func_val(func, src)
            else:
                ExportApp.update_func_val(func, src, processed_path)
        if base_path:
            ExportApp.update_func_val(func, base_path, base_path.replace('${SdkRootDirPath}', '${PrjRootDirPath}'))
        
        if not keep_in_repo_paths:
            return
        if not (new_argv := ExtensionMap.parser_args(func)).get('SOURCES'):
            new_result = []
        else:
            new_result = [func]
        src_str = ' '.join(keep_in_repo_paths)
        new_result.append(f'mcux_add_source(BASE_PATH ${{SdkRootDirPath}} {src_str})')
        return new_result

    @cmake_func
    def cm_mcux_add_include(self, func: dict, argv: dict) -> dict:
        base_path = argv.get('BASE_PATH')
        keep_in_repo_paths = []
        for inc in argv.get('INCLUDES'):
            processed_path = self._process_path(base_path, inc, 'inc')
            if processed_path.startswith('${SdkRootDirPath}/'):
                keep_in_repo_paths.append(processed_path.replace('${SdkRootDirPath}/', ''))
                ExportApp.remove_func_val(func, inc)
            else:
                ExportApp.update_func_val(func, inc, processed_path)
        if base_path:
            ExportApp.update_func_val(func, base_path, base_path.replace('${SdkRootDirPath}', '${PrjRootDirPath}'))

        if not keep_in_repo_paths:
            return
        if not (new_argv := ExtensionMap.parser_args(func)).get('INCLUDES'):
            new_result = []
        else:
            new_result = [func]
        src_str = ' '.join(keep_in_repo_paths)
        new_result.append(f'mcux_add_source(BASE_PATH ${{SdkRootDirPath}} INCLUDES {src_str})')
        return new_result

    def check_force(self, cond, msg):
        if not cond:
            self.die(msg)

    @staticmethod
    def remove_arg(func, argv, key):
        for i, arg in enumerate(func.get('args', []).copy()):
            if arg['value'] == key:
                del func['args'][i]
                if func['args'][i]['value'] in argv[key]:
                    del func['args'][i]

    # TODO this is not safe
    @staticmethod
    def update_func_val(func, old_val, new_val):
        for arg in func.get('args', []):
            if arg['value'] == old_val:
                arg['value'] = new_val

    @staticmethod
    def remove_func_val(func, val):
        for i, arg in enumerate(func.get('args', [])):
            if arg['value'] == val:
                del func['args'][i]

    def replace_var(self, var, bypass_list=[]):
        for k, v in self.cmake_variables.items():
            if k in bypass_list:
                continue
            cmake_var = f"${{{k}}}"
            var = var.replace(cmake_var, v)
        return var

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
            # Need add special variables case by case
            if '${board_root}' in s_src.as_posix():
                result = '${SdkRootDirPath}/' + s_src.relative_to(SDK_ROOT_DIR).as_posix()
        elif not (d_src := (self.output_dir / s_src.relative_to(SDK_ROOT_DIR))).exists():
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
        self.args.cmake_opts = None
        self.cmake_variables = {'CONFIG_TOOLCHAIN': self.args.toolchain}

        try:
            # Only one source_dir is allowed, as the first positional arg
            if remainder[0] != _ARG_SEPARATOR:
                self.args.source_dir = remainder[0]
                remainder = remainder[1:]
            # Only the first argument separator is consumed, the rest are
            # passed on to CMake
            if remainder[0] == _ARG_SEPARATOR:
                remainder = remainder[1:]
            if remainder:
                self.args.cmake_opts = remainder
                for opt in self.args.cmake_opts:
                    if not opt.startswith('-D'):
                        continue
                    _ = opt.replace('-D', '').split('=')
                    if len(_) == 1:
                        self.cmake_variables[_[0]] = ''
                    else:
                        self.cmake_variables[_[0]] = opt.replace(f'-D{_[0]}=', '')
                    
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
        self.check_force(
            'example.yml' in os.listdir(app),
            "{} doesn't contain a example.yml".format(app))
        out = self.args.output_dir
        self.check_force(
            (not os.path.isdir(out)) or (len(os.listdir(out)) == 0),
            f'Output directory {out} is not empty, please remove it first')

        self.source_dir = Path(app).resolve()
        self.output_dir = Path(out).resolve()
        self.examples_root = SDK_ROOT_DIR / self.source_dir.relative_to(SDK_ROOT_DIR).parts[0]

    def _app_precheck(self):
        # NOTE do not support internal examples yet
        op = sdk_project_target.MCUXRepoProjects()
        self.board = self.args.board
        if 'core_id' in self.cmake_variables:
            self.core_id = self.cmake_variables['core_id']
        board_core = self.board
        if self.core_id:
            board_core = board_core + '@' + self.core_id
        matched_app = op.search_app_targets(app_path=self.source_dir.as_posix(), board_cores_filter=[board_core])
        self.check_force(matched_app,
                         f'Cannot find any app match your input, please ensure following command can get a valid output\
                          {os.linesep}west list_project -p {self.source_dir} -b {board_core}')

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

