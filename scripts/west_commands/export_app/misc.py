# Copyright 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import os
import re
import logging
import glob
from pathlib import Path
from datetime import datetime
from contextlib import contextmanager

logger = logging.getLogger(__name__)

_SENTINEL = object()

LICENSE_HEAD = f'''
# Copyright {datetime.now().year} NXP
#
# SPDX-License-Identifier: Apache-2.0
'''

CONFIG_CHOICE_MAP = {
    'CONFIG_MCUX_PRJSEG_module.board.clock': 'CONFIG_MCUX_PRJSEG_module.board.clock_customize_folder',
    'CONFIG_MCUX_PRJSEG_module.board.pinmux': 'CONFIG_MCUX_PRJSEG_module.board.pinmux_customize_folder',
    r"CONFIG_MCUX_PRJSEG_module.use_.*_peripheral": 'CONFIG_MCUX_PRJSEG_module.use_customize_peripheral',
    r'CONFIG_MCUX_PRJSEG_project.hw_(core|app|project)': 'CONFIG_MCUX_PRJSEG_project.hw_app_customize_folder'
}

@contextmanager
def temp_attrs(obj, **updates):
    """Temporarily set attributes on an object, then restore them."""
    saved = {}
    try:
        for k, v in updates.items():
            saved[k] = getattr(obj, k, _SENTINEL)
            setattr(obj, k, v)
        yield
    finally:
        for k, old in saved.items():
            if old is _SENTINEL:
                try:
                    delattr(obj, k)
                except AttributeError:
                    pass
            else:
                setattr(obj, k, old)


def replace_cmake_variables(ori_str='', var_dict={}):
    if '${' not in ori_str:
        return ori_str
    for k, v in var_dict.items():
        ori_str = re.sub(rf'\$\{{{re.escape(k)}}}', v, ori_str, re.IGNORECASE)
    return ori_str

def process_path(source_dir, base_path='', src='', vars={}):
    '''
    Process a path

    Args:
        source_dir (Path): The source directory, usually be CMAKE_CURRENT_LIST_DIR
        base_path (str): (Optional) The base path
        src (str): The source path
        vars (dict): The variables to replace in the path
    
    Returns:
        str: The processed path
        None: No need to process the path
    '''
    try:
        if src == '/.':
            # /. may cause permission issue in windows
            logger.warning("The path '/.' is not safe, please use './' instead.")
            src = './'
        s_src = Path(replace_cmake_variables(os.path.join(base_path, src), vars))
        if '${' in s_src.as_posix():
            return None
        if not s_src.is_absolute():
            s_src = source_dir / s_src
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