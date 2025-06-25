# Copyright 2025 NXP
#
# SPDX-License-Identifier: Apache-2.0

import os
import logging
import yaml
import shutil
import re
import glob
from copy import deepcopy
from datetime import datetime
from pathlib import Path
from export_app.cmake_parser import *

LICENSE_HEAD = f'''
# Copyright {datetime.now().year} NXP
#
# SPDX-License-Identifier: Apache-2.0
'''

logger = logging.getLogger(__name__)

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
    def __init__(self, source_dir: Path, output_dir: Path, cmake_variables, extra_variables, sysbuild=False, target_apps=[]):
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
        self.target_apps = target_apps
        self.current_list_dir = '${SdkRootDirPath}/' + self.source_dir.relative_to(SDK_ROOT_DIR).as_posix()
        self._parse_example_yml()
        self.output_dir = output_dir
        self.list_file = self.source_dir / 'CMakeLists.txt'
        self.examples_root = SDK_ROOT_DIR / self.source_dir.relative_to(SDK_ROOT_DIR).parts[0]
        self.cmake_variables = cmake_variables
        if sysbuild or self.is_sysbuild:
            self.output_dir = output_dir / self.source_dir.name
        self.dest_list_file = self.output_dir / 'CMakeLists.txt'
        self.extra_variables = extra_variables
        self.cmake_variables.update({
            'SdkRootDirPath': SDK_ROOT_DIR.as_posix(),
            'CMAKE_CURRENT_LIST_DIR': self.source_dir.as_posix(),
            'CMAKE_CURRENT_SOURCE_DIR': self.source_dir.as_posix()
        })

    def _parse_example_yml(self):
        self.custom_conf_files = []
        self.example_yml = yaml.load(open(self.source_dir / 'example.yml'), yaml.BaseLoader)
        for idx, (k, v) in enumerate(self.example_yml.items()):
            if self.target_apps and k not in self.target_apps:
                continue
            if idx == 0:
                self.name = k
                self.example_info = self.example_yml[k]
                self.extra_files = self.example_info.get('contents', {}).get('extra_files', [])
                self.is_sysbuild = self._is_sysbuild()
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
        new_cmake_content = self.parse_cmake_file(self.list_file)
        # Force use \n to avoid multiple line breaks in windows
        open(self.dest_list_file, 'w').write("\n".join(new_cmake_content))
        for entry in self.extra_files:
            if isinstance(entry, str):
                src_path = self._replace_cmake_variables(entry, {**self.extra_variables, **self.cmake_variables})
                src_file = Path(src_path)
                dest_file = self.output_dir / src_file.relative_to(SDK_ROOT_DIR)
            elif isinstance(entry, dict):
                src_path = self._replace_cmake_variables(entry.get('source', ''), {**self.extra_variables, **self.cmake_variables})
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
                logger.warning(f"[extra_files] File or directory not found: {src_file}")

        self.combine_prj_conf()
        self.update_kconfig_path()
        if self.is_sysbuild:
            self.parse_sysbuild()
        # Apply replacements defined in example.yml
        self.apply_replacements()


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

    def parse_sysbuild(self):
        new_sysbuild_content = self.parse_cmake_file(self.source_dir / 'sysbuild.cmake', ['externalzephyrproject_add', 'externalmcuxproject_add', 'include'])
        open(self.output_dir / 'sysbuild.cmake', 'w').write(os.linesep.join(new_sysbuild_content))

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
        self.linked_app = CmakeApp(linked_source, self.main_output_dir, self.cmake_variables, self.extra_variables, True)
        self.linked_app.run()
        o_func.single_args['SOURCE_DIR'] = '/'.join(['${APP_DIR}', '..', linked_source.name])
        return o_func

    cm_externalmcuxproject_add = cm_externalzephyrproject_add

    @cmake_func
    def cm_include(self, func: dict, o_func: CMakeFunction) -> dict:
        inc_path = o_func.nargs[0]
        inc_path = inc_path.replace('${CMAKE_CURRENT_LIST_DIR}', self.current_list_dir)
        # Process relative path
        if inc_path.startswith('..') or '${' not in inc_path:
            inc_path = self.current_list_dir + '/' + inc_path
        o_func.nargs[0] = inc_path 
        if not self.current_process_file.name == 'sysbuild.cmake':
            return o_func
        inc_path = self._replace_cmake_variables(inc_path, {**self.extra_variables, **self.cmake_variables})
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
                if f.is_file() and 'kconfig' not in f.name.lower() and not (d_src / f.name).exists():
                    shutil.copy(f, d_src / f.name)
        new_func = deepcopy(o_func)
        new_func.single_args['BASE_PATH'] = '${CMAKE_CURRENT_LIST_DIR}'
        new_func.multi_args['INCLUDES'] = new_paths
        new_result.append(new_func)
        return new_result

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
        try:
            if src == '/.':
                # /. may cause permission issue in windows
                logger.warning("The path '/.' is not safe, please use './' instead.")
                src = './'
            s_src = Path(self._replace_cmake_variables(os.path.join(base_path, src)))
            if '${' in s_src.as_posix():
                return None
            if not s_src.is_absolute():
                s_src = self.source_dir / s_src
            if any(wildcard in s_src.as_posix() for wildcard in ['*', '?', '[', ']']):
                result = []
                for f in glob.glob(s_src.as_posix()):
                    result.append(Path(f).resolve())
                return result
            if (s_src.exists()):
                return s_src.resolve()
            else:
                return None
        except Exception:
            return None

    def _replace_cmake_variables(self, ori_str='', var_dict={}):
        if '${' not in ori_str:
            return ori_str
        if not var_dict:
            var_dict = self.cmake_variables
        for k, v in var_dict.items():
            ori_str = re.sub(rf'\$\{{{re.escape(k)}}}', v, ori_str, re.IGNORECASE)
        return ori_str

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
        for replacement in replacements:
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
