# Copyright 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

from dataclasses import dataclass
import re, os
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Set, Any, DefaultDict
from collections import defaultdict
from .misc import process_path
from .cmake_parser import parse_cmake_file

# ---------- precompiled regex ----------
# /abs/path/to.cmake(123):  <code...>
TRACE_LN_RE = re.compile(r'^(?P<path>.+?)\((?P<lineno>\d+)\):\s*(?P<code>.*)$', re.S)

# if (CONFIG_MCUX_xxx)
MCUX_IF_RE = re.compile(r'if\s*\(\s*(?P<cond>CONFIG_MCUX_[^\s]*)\s*\)', re.I)

INCLUDE_RE = re.compile(r'^\s*include\s*\(\s*(?P<file>[^\s\)]+)\s*', re.I)

# commands that "enable" picking for the current block
TARGET_FN = ("mcux_add_source", "mcux_add_include")

MISC_CONTENT_FN = ('mcux_set_variable')

# We cannot process ps which was defined in other locations
PS_BLACK_LIST = [
    'CONFIG_MCUX_PRJSEG_config.arm.shared',
    'CONFIG_MCUX_PRJSEG_module.board.suite',
    'CONFIG_MCUX_PRJSEG_module.device.suite',
]

def parse_line(s: str):
    if not (m := TRACE_LN_RE.match(s.rstrip("\n"))):
        return None
    return m.group("path"), int(m.group("lineno")), m.group("code")

def filter_trace_log(trace_path: str, filter_patterns: List[str], bypass_codes=['mcux_set_variable']) -> List[str]:
    expected_lines = []
    for line in open(trace_path, 'r').readlines():
        if not (parsed_ln := parse_line(line)):
            continue
        path, _lineno, code = parsed_ln
        if not any(re.search(re.compile(p), path) for p in filter_patterns):
            if not any(c in code for c in bypass_codes):
                continue
        expected_lines.append(line)
    return expected_lines

def parse_ps_cmake_trace_log(trace_path: str) -> Tuple[Dict[str, Dict[str, Any]], List[str]]:

    result: Dict[str, Dict[str, Any]] = {}
    misc_content: List[str] = []

    cur_ps: Optional[str] = None
    cur_ps_content: List[str] = []
    cur_file = None
    path: Optional[str] = None
    need_pick: bool = False

    def flush():
        """Emit current block to result if it is valid and then reset state."""
        nonlocal cur_ps, cur_ps_content, need_pick
        if need_pick and cur_ps and cur_ps not in PS_BLACK_LIST and cur_ps_content:
            result[cur_ps] = {
                'file': Path(cur_file),
                'content': cur_ps_content[:],
            }
        # Reset current block state
        cur_ps = None
        cur_ps_content = []
        need_pick = False

    for line in open(trace_path, 'r', encoding='utf-8'):
        if not (parsed_ln := parse_line(line)):
            continue
        path, _lineno, code = parsed_ln

        if code.startswith(MISC_CONTENT_FN):
            misc_content.append(code)

        if not cur_file == path:
            flush()
            cur_file = path

        # Guard start: if (CONFIG_MCUX_PRJSEG_xxx)
        if m_if := MCUX_IF_RE.match(code):
            # starting a new guard: flush any previous one, then open a new one
            flush()
            cond_name = m_if.group('cond')
            if cond_name.startswith('CONFIG_MCUX_PRJSEG'):
                cur_ps = cond_name
            continue
        
        if not cur_ps:
            continue

        cur_ps_content.append(code)

        if code.startswith(TARGET_FN):
            need_pick = True

    return result, misc_content

def parse_inc_cmake_trace_log(
    trace_path: str,
    source_list_file: Path,
    cmake_vars: Dict[str, str],
    prefixes: List[str] = [],
) -> List[Dict]:
    def _is_target_file(file_path: str, cur_file: Path):
        cmake_vars['CMAKE_CURRENT_LIST_DIR'] = cur_file.as_posix()
        cmake_vars['CMAKE_CURRENT_SOURCE_DIR'] = cur_file.as_posix()
        path = process_path(cur_file, '', file_path, cmake_vars)
        if not path:
            return None
        path = path.as_posix()
        # TODO use absolute path and startswith will be more accurate
        if any([p in path for p in prefixes]):
            return path
        return None
    
    def _find_func(list_content, lineno):
        for statement in list_content:
            if int(statement["line"]) == lineno:
                return statement
        return None

    result = []
    cur_inc = None
    cur_inc_parsed = None
    cur_inc_raw = None
    copied_line = 0
    search_list = [source_list_file.as_posix()]
    for line in open(trace_path, "r", encoding="utf-8"):
        if not (parsed_ln := parse_line(line)):
            continue
        path, lineno, code = parsed_ln

        if m := INCLUDE_RE.match(code):
            if path not in search_list:
                continue
            if not (inc_file := _is_target_file(m.group('file'), Path(path).parent)):
                continue
            if cur_inc and copied_line-1 < len(cur_inc_raw):
                result.extend(cur_inc_raw[copied_line-1:])
            cur_inc = inc_file
            copied_line = 0
            cur_inc_parsed = parse_cmake_file(Path(cur_inc))
            cur_inc_raw = [line.strip(os.linesep) for line in open(cur_inc, 'r').readlines()]
            search_list.append(cur_inc)
            continue

        if not cur_inc:
            continue
        if copied_line and copied_line < lineno - 1:
            result.extend(cur_inc_raw[copied_line:lineno-1])
            copied_line = lineno
        if (cur_inc == path) and (stat := _find_func(cur_inc_parsed, lineno)):
            copied_line = int(stat["line_end"])
            result.extend(cur_inc_raw[int(stat["line"])-1:int(stat["line_end"])])

    if cur_inc and copied_line-1 < len(cur_inc_raw):
        result.extend(cur_inc_raw[copied_line-1:])

    return search_list[1:], result
