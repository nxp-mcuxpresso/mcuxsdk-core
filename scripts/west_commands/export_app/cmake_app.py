# Copyright 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import os
import logging
import yaml
import shutil
import re
import glob
from copy import deepcopy

from pathlib import Path
from .cmake_parser import *
from .cmake_trace_parser import parse_ps_cmake_trace_log
from .misc import LICENSE_HEAD, CONFIG_CHOICE_MAP
from .misc import replace_cmake_variables, process_path, temp_attrs

logger = logging.getLogger(__name__)

INJECT_BUILD_DIR = 'build_tmp'

class NoNeedProcess(Exception):
    pass

def parse_prj_conf(path):
    result = {}
    for line in open(path).read().splitlines():
        if len(conf := line.split('=')) != 2:
            continue
        result[conf[0]] = conf[1]
    return result

class CmakeApp(object):
    def __init__(self, source_dir: Path, output_dir: Path, cmake_variables, extra_variables, app_type='main_app', misc_options={}):
        '''
        Args:
            source_dir (Path): The source directory of the app
            output_dir (Path): The user given output directory root
            cmake_variables (dict): The cmake variables to be used in the app
            extra_variables (dict): The extra variables to be used in the app
            sysbuild (bool): Whether the app is a sysbuild example (linked one)
            target_apps (list): The target app's id in example.yml to be processed
        '''
        self.source_dir = source_dir
        self.main_output_dir = output_dir
        self.current_list_dir = '${SdkRootDirPath}/' + self.source_dir.relative_to(SDK_ROOT_DIR).as_posix()
        self.misc_options = misc_options
        assert app_type in ['main_app', 'linked_app']
        self.app_type = app_type
        if app_type == 'main_app':
            self._parse_example_yml(misc_options.get('target_apps', []))
        else:
            self._parse_example_yml()
        self.output_dir = output_dir
        self.list_file = self.source_dir / 'CMakeLists.txt'
        self.examples_root = SDK_ROOT_DIR / self.source_dir.relative_to(SDK_ROOT_DIR).parts[0]
        self.cmake_variables = cmake_variables
        if app_type == 'linked_app' or self.is_sysbuild:
            self.output_dir = output_dir / self.source_dir.name
        self.dest_list_file = self.output_dir / 'CMakeLists.txt'
        self.extra_variables = extra_variables
        self.cmake_variables.update({
            'SdkRootDirPath': SDK_ROOT_DIR.as_posix(),
            'CMAKE_CURRENT_LIST_DIR': self.source_dir.as_posix(),
            'CMAKE_CURRENT_SOURCE_DIR': self.source_dir.as_posix()
        })
        self.need_copy_board_files = False
        self.process_include = False
        if self.misc_options.get('board_copy_folders'):
            self.process_include = True
            self.board_includes = []
            self.app_copy_folders = self.misc_options['board_copy_folders']
            if self.misc_options.get('freestanding_copied_folders'):
                self.app_copy_folders.extend(self.misc_options['freestanding_copied_folders'])
            self.need_copy_board_files = True
            self.dest_board_dirname = self.cmake_variables['board']
            if self.cmake_variables.get('core_id'):
                self.dest_board_dirname += '_' + self.cmake_variables['core_id']
            self.output_board_dir = self.output_dir / self.dest_board_dirname
            
    def _parse_example_yml(self, target_apps=[]):
        '''
        This function was called in init, so be careful with the variables used here.
        '''
        self.custom_conf_files = []
        self.example_yml = yaml.load(open(self.source_dir / 'example.yml'), yaml.BaseLoader)
        for idx, (k, v) in enumerate(self.example_yml.items()):
            if target_apps and k not in target_apps:
                continue
            if idx == 0:
                self.name = k
                self.example_info = self.example_yml[k]
                self.extra_files = self.example_info.get('contents', {}).get('extra_files', [])
                self.is_sysbuild = self._is_sysbuild()
                if (freestanding_copied_folders := self.example_info.get('contents', {}).get('freestanding_copied_folders', [])):
                    self.misc_options['freestanding_copied_folders'] = freestanding_copied_folders
                continue
            if not (extra_build_args := v.get('contents', {}).get('document', {}).get('extra_build_args')):
                continue
            new_args = []
            for ext_arg in extra_build_args:
                if not ext_arg.startswith('-DCONF_FILE'):
                    new_args.append(ext_arg)
                    continue
                if not (conf_file := SDK_ROOT_DIR / ext_arg.replace('-DCONF_FILE=', '')).exists():
                    logger.warning(f"Cannot find the custom prj.conf file {conf_file.as_posix()}")
                    continue
                self.custom_conf_files.append(conf_file)
                new_args.append(f'-DCONF_FILE={conf_file.name}')
            self.example_yml[k]['contents']['document']['extra_build_args'] = new_args

    def _is_sysbuild(self):
        '''
        Check if the app is a sysbuild example.
        see: https://mcuxpresso.nxp.com/mcuxsdk/latest/html/develop/build_system/Sysbuild.html
        '''
        if self.example_info.get('use_sysbuild'):
            if 'sysbuild.cmake' not in os.listdir(self.source_dir):
                logger.error(f'{self.name}: The app set "use_sysbuild=true" but does not have a "sysbuild.cmake"')
                return False
            else:
                return True
        if 'sysbuild.cmake' in os.listdir(self.source_dir):
            logger.warning(f'{self.name}: The app has a "sysbuild.cmake" but does not set "use_sysbuild=true" in example.yml')
            return True
        return False

    def _should_skip_entry(self, entry, current_board):
        board_condition = entry.get('board')
        if board_condition:
            if isinstance(board_condition, str):
                return board_condition != current_board
            elif isinstance(board_condition, list):
                return current_board not in board_condition
        return False

    def run(self):
        self.output_dir.mkdir(parents=True, exist_ok=True)
        # Do not copy custom application info
        open(self.output_dir / 'example.yml', 'w').write(yaml.dump(self.example_yml))
        for idx, conf_file in enumerate(self.custom_conf_files):
            shutil.copy(conf_file, self.output_dir / conf_file.name)
            self.custom_conf_files[idx] = (self.output_dir / conf_file.name).as_posix()
        if (ide_yml := self.source_dir / 'IDE.yml').exists():
            shutil.copy(ide_yml, self.output_dir / 'IDE.yml')
        self.current_process_file = None
        if self.need_copy_board_files:
            self.output_board_dir.mkdir(parents=True, exist_ok=True)
            if self.app_type == 'main_app':
                self.parse_variables()
        self.dest_list_content = self.parse_cmake_file(self.list_file)
        if not self.need_copy_board_files:
            # Force use \n to avoid multiple line breaks in windows
            open(self.dest_list_file, 'w').write("\n".join(self.dest_list_content))

        if self.extra_files:
            self.copy_extra_files()
        self.combine_prj_conf()
        self.update_kconfig_path()
        if self.is_sysbuild:
            if self.need_copy_board_files and self.app_type == 'main_app':
                self.parse_syubuild_variables()
            self.parse_sysbuild()
        # Apply replacements defined in example.yml
        self.apply_replacements()

        if self.need_copy_board_files:
            self.copy_board_files()
            open(self.dest_list_file, 'w').write("\n".join(self.dest_list_content))

    def copy_extra_files(self):
        variables = {**self.extra_variables, **self.cmake_variables}
        current_board = self.cmake_variables.get('board')
        for entry in self.extra_files:
            if isinstance(entry, str):
                src_path = replace_cmake_variables(entry, variables)
                if not src_path:
                    logger.warning(f"[extra_files] Empty source path in entry: {entry}")
                    continue
                src_file = Path(src_path)
                dest_file = self.output_dir / src_file.relative_to(SDK_ROOT_DIR)

            elif isinstance(entry, dict):
                if self._should_skip_entry(entry, current_board):
                    continue

                src_path = replace_cmake_variables(entry.get('source', ''), variables)
                if not src_path:
                    logger.warning(f"[extra_files] Empty source path in entry: {entry}")
                    continue
                dest_path = entry.get('destination', '')
                src_file = Path(src_path)
                dest_file = self.output_dir / dest_path

            else:
                logger.warning(f"[extra_files] Invalid entry format: {entry}")
                continue

            if src_file.is_file():
                dest_file.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(src_file, dest_file)
            elif src_file.is_dir():
                dest_dir = dest_file if dest_file.suffix == '' else dest_file.parent
                shutil.copytree(src_file, dest_dir, dirs_exist_ok=True)
            else:
                logger.warning(f"[extra_files] File or directory not found: {src_file} (from entry: {entry})")

    def parse_cmake_file(self, cmake_file, target_funcs=[], add_license=True):
        '''
        Pare the app's cmake file and return the new content

        Args:
            cmake_file (Path): The cmake file to parse
            target_funcs (list): The target functions to parse, if empty, all functions will be parsed
        
        Returns:
            list: The new content of the cmake file
        '''
        cmake_content = parse_cmake_file(cmake_file)
        raw_content = [line.strip(os.linesep) for line in open(cmake_file, 'r').readlines()]
        new_cmake_content = []
        if add_license:
            new_cmake_content.extend(LICENSE_HEAD.split(os.linesep))
        if not cmake_content:
            return new_cmake_content
        backup = self.current_process_file
        self.current_process_file = cmake_file
        for func in cmake_content:
            try:
                func_name = func['original_name'].lower()
                if hasattr(self, f'cm_{func_name}'):
                    if target_funcs and func_name not in target_funcs:
                        raise NoNeedProcess
                    result = getattr(self, f'cm_{func_name}')(func)
                    if isinstance(result, list):
                        new_cmake_content.extend(result)
                    elif isinstance(result, str):
                        new_cmake_content.append(result)
                    else:
                        raise NoNeedProcess
                else:
                    raise NoNeedProcess
            except NoNeedProcess:
                logger.debug(f'No special process for {func["line"]}: {func_name}')
                new_cmake_content.extend(raw_content[int(func["line"])-1:int(func["line_end"])])
            except KeyError as exec:
                logger.error(str(exec))
                logger.fatal(f'The cmparser cannot handle the given {cmake_file.as_posix()}')
            except InvalidCmakeMethod as exec:
                logger.error(str(exec))
                logger.fatal(f'Script error, please contact us.')
        self.current_process_file = backup
        return new_cmake_content

    def combine_prj_conf(self):
        '''
        Get the prj.conf from the example search list and combine them into one file
        '''
        example_root_stem = self.examples_root.stem
        # Do not process example out of given example_root folder
        if not self.source_dir.relative_to(SDK_ROOT_DIR).as_posix().startswith(example_root_stem):
            return
        prj_conf = {}
        search_list = []
        example_common = self.source_dir
        while example_common.stem != example_root_stem:
            search_list.insert(0, example_common)
            example_common = example_common.parent
        for s_p in search_list:
            if not (e_conf := (s_p / 'prj.conf')).exists():
                continue
            for k, v in parse_prj_conf(e_conf).items():
                prj_conf[k] = v
        with open(self.output_dir / 'prj.conf', 'w') as f:
            f.write(LICENSE_HEAD)
            for k, v in prj_conf.items():
                f.write(f"{k}={v}\n")

    def update_kconfig_path(self):
        '''
        Update the path in sysbuild's Kconfig
        '''
        for f in self.source_dir.iterdir():
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
                dest_kconfig_path = '"${SdkRootDirPath}/' + (self.source_dir / rel_kconfig_path).resolve().relative_to(SDK_ROOT_DIR).as_posix() + '"'
                kconfig_content[i] = prefix_id + dest_kconfig_path
            open(self.output_dir / f.name, 'w').write(os.linesep.join(kconfig_content))

    def parse_syubuild_variables(self):
        sysbuild_cmd = self.build_cmd(['--cmake-only'], INJECT_BUILD_DIR, True)
        result = subprocess.run(sysbuild_cmd, cwd=SDK_ROOT_DIR.as_posix(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != 0:
            logger.error(f"Failed to run command: {' '.join(sysbuild_cmd)}")
            print(result.stderr.decode('utf-8'))
            return None
        if not (sysbuild_config_path := self.misc_options['main_output'] / INJECT_BUILD_DIR / '.config').exists():
            logger.error(f"Cannot find the .config file {sysbuild_config_path.as_posix()}")
            return None
        sysbuild_config = open(sysbuild_config_path, 'r').read().splitlines()
        self.misc_options['sysbuild_variables'] = {}
        for line in sysbuild_config:
            if not line.startswith('SB_CONFIG_'):
                continue
            if '=' not in line:
                continue
            key = line.split('=')[0]
            self.misc_options['sysbuild_variables'][key] = line.replace(key + '=', '').strip('\'" ')
        if not self.misc_options.get('debug', False):
            shutil.rmtree(self.misc_options['main_output'] / INJECT_BUILD_DIR, ignore_errors=True)

    def parse_sysbuild(self):
        new_sysbuild_content = self.parse_cmake_file(self.source_dir / 'sysbuild.cmake', ['externalzephyrproject_add', 'externalmcuxproject_add', 'include'])
        open(self.output_dir / 'sysbuild.cmake', 'w').write(os.linesep.join(new_sysbuild_content))

    def parse_variables(self):
        if not (trace_log := self._get_trace_log()):
            return
        self.ps_result, self.misc_content = parse_ps_cmake_trace_log(trace_log)
        trace_cmake_dir = self.output_dir / INJECT_BUILD_DIR / 'traced_cmakes'
        trace_cmake_dir.mkdir(parents=True, exist_ok=True)
        open(tmp_misc_cmake := (trace_cmake_dir / 'tmp_misc.cmake'), 'w').write("\n".join(self.misc_content))
        # Get all variables
        self.parse_cmake_file(tmp_misc_cmake)
        # TODO workaround to fix evkbimxrt1050 examples/sdmmc_examples/sdio_freertos
        if 'core_id' not in self.cmake_variables:
            self.cmake_variables['core_id'] = ''

    def copy_board_files(self):
        if self.app_type != 'main_app':
            self.parse_variables()
        if not hasattr(self, 'ps_result'):
            return
        self.parse_cmake_trace_result()
        board_prj_conf, force_selected = self.create_board_prj_conf(self.output_dir/'build_tmp/.config', self.output_dir/'build_tmp/.promptless_config', list(self.ps_result.keys()))
        if force_selected:
            self.create_fake_kconfig(force_selected)
        open(self.output_dir / self.dest_board_dirname / 'prj.conf', 'a', encoding="utf-8").write('\n'.join(board_prj_conf))
        self.update_cmake_file()
        if not self.misc_options.get('debug', False):
            shutil.rmtree(self.output_dir / INJECT_BUILD_DIR)

    def update_cmake_file(self):
        if self.cmake_variables.get('core_id'):
            append_content = '\ninclude("${board}_${core_id}/board_files.cmake")\n'
        else:
            append_content = '\ninclude(${board}/board_files.cmake)\n'
        if self.cmake_variables.get('core_id'):
            prj_conf_dirname = '${board}_${core_id}'
        else:
            prj_conf_dirname = '${board}'
        prepend_content = [f'cmake_path(APPEND conf_file_path ${{CMAKE_CURRENT_LIST_DIR}} {prj_conf_dirname} prj.conf)\n',
                           f'list(APPEND CONF_FILE ${{conf_file_path}})\n']
        insert_index = 0
        for i, line in enumerate(self.dest_list_content):
            line = line.strip()
            if line.startswith('#') or line == '' or line.startswith('cmake_minimum_required'):
                insert_index = i + 1
            else:
                break
        self.dest_list_content = self.dest_list_content[:insert_index] + prepend_content + self.dest_list_content[insert_index:]
        self.dest_list_content.append(append_content)

    def create_board_prj_conf(self, build_config, promptless_config, ps_list):
        board_prj_conf = []
        comp_list = []
        promptless_syms = []
        force_selected = []
        if promptless_config.exists():
            for line in open(promptless_config, 'r').read().splitlines():
                if '=' not in line:
                    continue
                promptless_syms.append(line.split('=')[0])
        else:
            logger.warning(f"Cannot find the promptless config file {promptless_config.as_posix()}, will not process promptless symbols.")
        raw_config = open(build_config, 'r').read().splitlines()
        for c in raw_config:
            # Middleware may cause Kconfig build issues
            if not (match_result := re.match(r'CONFIG_MCUX_(COMPONENT|PRJSEG)[^=]+', c)):
                continue
            if (item := match_result.group(0)) in promptless_syms:
                force_selected.append(item[7:])
                continue
            if item in ps_list:
                continue
            comp_list.append(c)
        board_prj_conf.extend(comp_list)
        for ps in ps_list:
            if ps in promptless_syms:
                continue
            board_prj_conf.append(f'{ps}=n')
            for k, v in CONFIG_CHOICE_MAP.items():
                if re.match(k, ps):
                    board_prj_conf.append(f'{v}=y')
        return board_prj_conf, force_selected

    def create_fake_kconfig(self, force_selected):
        result = [f'config CUSTOM_APP_{self.name.upper()}', '    bool', '    default y']
        result.extend([f'    select {item}' for item in force_selected])
        if (dest_kconfig := self.output_dir / 'Kconfig').exists():
            open(dest_kconfig, 'a', encoding='utf-8').write('\n' + '\n'.join(result) + '\n')
        else:
            result.insert(0, 'rsource "${SdkRootDirPath}/Kconfig.mcuxpresso"')
            open(dest_kconfig, 'w', encoding='utf-8').write('\n'.join(result) + '\n')

    def _get_trace_log(self):
        if not self.cmake_variables.get('board') or not self.cmake_variables.get('CONFIG_TOOLCHAIN'):
            logger.error("Cannot copy board files, please set 'board' and 'toolchain' parameters.")
            return None
        logger.warning(f'{self.name}: Copy board files will take a few seconds, please wait...')
        inject_cmd = self.inject_cmd()
        logger.debug(f"Analyze board files with command: {' '.join(inject_cmd)}")
        result = subprocess.run(inject_cmd, cwd=SDK_ROOT_DIR.as_posix(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != 0:
            logger.error(f"Failed to run command: {' '.join(inject_cmd)}")
            print(result.stderr.decode('utf-8'))
            return None
        if not (trace_log := self.output_dir / INJECT_BUILD_DIR / 'trace.log').exists():
            logger.error(f"Cannot find the trace log file {trace_log.as_posix()}")
            return None
        return trace_log

    def parse_cmake_trace_result(self):
        backup = self.output_dir
        trace_cmake_dir = self.output_dir / INJECT_BUILD_DIR / 'traced_cmakes'
        self.output_dir = self.output_board_dir

        if self.cmake_variables.get('project_board_port_path'):
            self.cmake_variables['project_board_port_path'] = self._replace_cmake_variables(self.cmake_variables['project_board_port_path'])
        board_cmake_content = []
        for _, v in self.ps_result.items():
            self.source_dir = v['file'].parent
            open(tmp_cmake := (trace_cmake_dir / v['file'].name), 'w').write("\n".join(v['content']))
            with temp_attrs(
                self,
                source_dir=v['file'].parent,
                process_include=False,
                current_list_dir='${SdkRootDirPath}/' + v['file'].parent.relative_to(SDK_ROOT_DIR).as_posix()
            ):
                board_cmake_content.extend(self.parse_cmake_file(tmp_cmake, add_license=False))

        board_cmake_content.append("\n# Application reconfig data\n")
        board_cmake_content.extend(self.board_includes)
        open(self.output_dir / 'board_files.cmake', 'a').write("\n".join(board_cmake_content))
        self.output_dir = backup

    def build_cmds(self):
        if not self.app_type == 'main_app':
            logger.error("Do not call this function for a non entry app.")
            return []
        result = [self.build_cmd()]
        for conf_file in self.custom_conf_files:
            result.append(self.build_cmd([f'-DCONF_FILE={conf_file}']))
        return result

    def build_cmd(self, extra_args=[], build_dir='build', repo=False):
        board_var = self.cmake_variables.get('board', "<board_id>")
        if repo:
            source_dir = self.source_dir
        else:
            source_dir = self.output_dir
        cmd_list = ['west', 'build', '-b', board_var, '--toolchain', self.cmake_variables['CONFIG_TOOLCHAIN'],
                    '-p', 'always', source_dir.as_posix(),
                    '-d', (self.misc_options['main_output']/build_dir).as_posix(),
                    ]
        if self.is_sysbuild:
            cmd_list.append('--sysbuild')
        if self.misc_options['cmake_opts']:
            cmd_list.extend(self.misc_options['cmake_opts'])
        if extra_args:
            cmd_list.extend(extra_args)
        return cmd_list
    
    def inject_cmd(self):
        board_var = self.cmake_variables.get('board', "<board_id>")
        cmd_list = ['west', 'build', '-b', board_var, '--toolchain', self.cmake_variables['CONFIG_TOOLCHAIN'],
                    '-p', 'always', self.source_dir.as_posix(),
                    '-d', (self.output_dir/INJECT_BUILD_DIR).as_posix(),
                    '-DGENERATE_PROMPTLESS_SYMS=y',
                    '--cmake-only'
                    ]
        if self.cmake_variables.get('core_id'):
            cmd_list.append(f'-Dcore_id={self.cmake_variables["core_id"]}')
        for folder in self.app_copy_folders:
            cmd_list.extend(['--trace-dir', f'"{folder}"'])
        return cmd_list

    @cmake_func
    def cm_externalzephyrproject_add(self, func: dict, o_func: CMakeFunction) -> dict:
        source_dir = o_func.single_args.get('SOURCE_DIR', '')
        if not source_dir:
            logger.fatal("Cannot find correct SOURCE_DIR from sysbuild.cmake")
        linked_source = self._replace_cmake_variables(source_dir).replace('${APP_DIR}', self.source_dir.as_posix())
        if '${' in linked_source:
            logger.fatal(f"The SOURCE_DIR {source_dir} contains unsupported variables.")
        linked_source = Path(linked_source).resolve()
        if not linked_source.exists():
            logger.fatal(f"Cannot find the sysbuild app dir {linked_source.as_posix()}")
        if self.need_copy_board_files:
            if not self.misc_options.get('sysbuild_variables'):
                self.misc_options['sysbuild_variables'] = {}
            for k, v in o_func.single_args.items():
                if k == 'SOURCE_DIR':
                    continue
                if k == 'toolchain':
                    k = 'CONFIG_TOOLCHAIN'
                self.misc_options['sysbuild_variables'][k] = replace_cmake_variables(v, self.misc_options['sysbuild_variables'])
            linked_variables = self.misc_options['sysbuild_variables']
        else:
            linked_variables = self.cmake_variables
        self.linked_app = CmakeApp(linked_source, self.main_output_dir, linked_variables, self.extra_variables, 'linked_app', self.misc_options)
        self.linked_app.run()
        o_func.single_args['SOURCE_DIR'] = '/'.join(['${APP_DIR}', '..', linked_source.name])
        return o_func

    cm_externalmcuxproject_add = cm_externalzephyrproject_add

    @cmake_func
    def cm_project(self, func: dict, o_func: CMakeFunction) -> dict:
        if o_func.single_args.get('PROJECT_BOARD_PORT_PATH'):
            self.cmake_variables['project_board_port_path'] = o_func.single_args['PROJECT_BOARD_PORT_PATH']
        return o_func

    @cmake_func
    def cm_mcux_set_variable(self, func: dict, o_func: CMakeFunction) -> dict:
        '''
        Set a variable in the cmake file
        '''
        if not (var_name := o_func.nargs[0]):
            logger.error("Cannot find the variable name to set.")
            return o_func
        if len(o_func.nargs) == 1:
            return o_func
        if not (var_value := o_func.nargs[1]):
            logger.error("Cannot find the variable value to set.")
            return o_func

        self.cmake_variables[var_name] = var_value
        return []

    @cmake_func
    def cm_include(self, func: dict, o_func: CMakeFunction) -> dict:
        inc_path = o_func.nargs[0]
        inc_path = inc_path.replace('${CMAKE_CURRENT_LIST_DIR}', self.current_list_dir)
        # Process relative path
        if inc_path.startswith('..') or '${' not in inc_path:
            inc_path = self.current_list_dir + '/' + inc_path
        o_func.nargs[0] = inc_path

        if not self.current_process_file.name == 'sysbuild.cmake':
            resolve_path = self._process_path(src=inc_path)
            if self.process_include and self.need_copy_board_files and resolve_path and resolve_path.exists() and any(p in resolve_path.as_posix() for p in self.app_copy_folders):
                with temp_attrs(
                    self,
                    source_dir=resolve_path.parent,
                    output_dir=self.output_board_dir,
                    current_list_dir='${SdkRootDirPath}/' + resolve_path.parent.relative_to(SDK_ROOT_DIR).as_posix()
                ):
                    include_content = self.parse_cmake_file(resolve_path, add_license=False)
                if include_content:
                    include_content.insert(0, '# from ' + o_func.nargs[0])
                    self.board_includes.extend(include_content)
                    return f'# processed {o_func.nargs[0]}'
            return o_func
        inc_path = replace_cmake_variables(inc_path, {**self.extra_variables, **self.cmake_variables})
        if not (inc_path := Path(inc_path)).exists():
            logger.warning(f"Cannot find the include sysbuild path {inc_path.as_posix()}")
            return o_func
        # Only support one level include in sysbuild.cmake
        new_sysbuild_result = self.parse_cmake_file(inc_path, ['externalzephyrproject_add', 'externalmcuxproject_add'])
        return new_sysbuild_result

    @cmake_func
    def cm_mcux_add_source(self, func: dict, o_func: CMakeFunction) -> dict:
        target_paths, new_result = self._path_preprocess(func, o_func)
        if not target_paths:
            return new_result
        new_paths = []
        for p in target_paths:
            if self.source_dir in p.parents:
                new_paths.append(rel_path := p.relative_to(self.source_dir).as_posix())
                d_src = self.output_dir / rel_path
                os.makedirs(d_src.parent, exist_ok=True)
            else:
                new_paths.append(p.name)
                d_src = self.output_dir / p.name
            shutil.copy(p, d_src)

        new_func = deepcopy(o_func)
        new_func.single_args['BASE_PATH'] = '${CMAKE_CURRENT_LIST_DIR}'
        new_func.multi_args['SOURCES'] = new_paths

        new_result.append(new_func)
        return new_result

    @cmake_func
    def cm_mcux_add_include(self, func: dict, o_func: CMakeFunction) -> dict:
        target_paths, new_result = self._path_preprocess(func, o_func, 'INCLUDES')
        if not target_paths:
            return new_result
        new_paths = []
        for p in target_paths:
            if self.source_dir in p.parents:
                new_paths.append(rel_path := p.relative_to(self.source_dir).as_posix())
                d_src = self.output_dir / rel_path
                os.makedirs(d_src, exist_ok=True)
            else:
                if '.' not in new_paths:
                    new_paths.append('.')
                d_src = self.output_dir
            for f in p.iterdir():
                # Copy all files under include dir except Kconfig as it may break the build
                if f.is_file() and self._filter_include_file_name(f.name) and not (d_src / f.name).exists():
                    shutil.copy(f, d_src / f.name)
        new_func = deepcopy(o_func)
        new_func.single_args['BASE_PATH'] = '${CMAKE_CURRENT_LIST_DIR}'
        new_func.multi_args['INCLUDES'] = new_paths
        new_result.append(new_func)
        return new_result

    def _filter_include_file_name(self, filename):
        filename = filename.lower()
        if 'kconfig' in filename:
            return False
        if filename.endswith('.cmake'):
            return False
        if filename in ['cmakelists.txt', 'prj.conf', 'example.yml']:
            return False
        return True

    @cmake_func
    def cm_target_link_libraries(self, func: dict, o_func: CMakeFunction) -> dict:
        need_update = False
        for i, arg in enumerate(o_func.nargs):
            if not (p := self._process_path(arg)):
                continue
            if self.source_dir in p.parents:
                rel_path = p.relative_to(self.source_dir).as_posix()
                d_src = self.output_dir / rel_path
                os.makedirs(d_src.parent, exist_ok=True)
            else:
                d_src = self.output_dir / p.name
            need_update = True
            o_func.nargs[i] = '${CMAKE_CURRENT_LIST_DIR}/' + d_src.relative_to(self.output_dir).as_posix()
            shutil.copy(p, d_src)
        if need_update:
            return o_func

    def _path_preprocess(self, func: dict, o_func: CMakeFunction, p_type: str='SOURCES'):
        base_path = o_func.single_args.get('BASE_PATH', '')
        target_paths = []
        to_remove = []
        for p in o_func.multi_args.get(p_type):
            if not (processed_path := self._process_path(base_path, p)):
                continue
            if isinstance(processed_path, list):
                target_paths.extend(processed_path)
            else:
                target_paths.append(processed_path)
            to_remove.append(p)
        for p in to_remove:
            o_func.remove_value(p_type, p)

        if not target_paths:
            return None, o_func
        if not o_func.multi_args.get(p_type):
            new_result = []
        else:
            if not base_path:
                o_func.single_args['BASE_PATH'] = '${CMAKE_CURRENT_LIST_DIR}'
            new_result = [o_func]
        return target_paths, new_result

    def replace_var(self, var, bypass_list=[]):
        for k, v in self.cmake_variables.items():
            if k in bypass_list:
                continue
            cmake_var = f"${{{k}}}"
            var = var.replace(cmake_var, v)
        return var

    def _process_path(self, base_path='', src=''):
        '''
        Process a path

        Args:
            base_path (str): (Optional) The base path
            src (str): The source path
        
        Returns:
            str: The processed path
            None: No need to process the path
        '''
        return process_path(self.source_dir, base_path, src, self.cmake_variables)

    def _replace_cmake_variables(self, ori_str=''):
        return replace_cmake_variables(ori_str, self.cmake_variables)

    def apply_replacements(self):
        '''
        Apply replacements defined in example.yml to the files in the output directory.
        The 'replacements' section should look like this in example.yml:
        
        contents:
            ...
            replacements:
            - file: CMakeLists.txt
              replace:
                - from: "original_value"
                  to: "new_value"
        '''
        replacements = self.example_info.get('contents', {}).get('replacements', [])
        current_board = self.cmake_variables.get('board')
        for replacement in replacements:
            if self._should_skip_entry(replacement, current_board):
                continue

            file_path = self.output_dir / replacement['file']
            if not file_path.exists():
                logger.warning(f"[replacements] File not found: {file_path}")
                continue

            with open(file_path, 'r') as f:
                content = f.read()

            for r in replacement['replace']:
                content = content.replace(r['from'], r['to'])

            with open(file_path, 'w') as f:
                f.write(content)

            logger.debug(f"[replacements] Applied replacements to {file_path}")
