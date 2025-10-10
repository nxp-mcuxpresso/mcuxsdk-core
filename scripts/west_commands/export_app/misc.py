# Copyright 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import os
import re
import logging
import glob
import datetime
import time
import inspect
import subprocess
from functools import wraps
from pathlib import Path
from datetime import datetime
from contextlib import contextmanager
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional, List, Union, Dict, Iterable

logger = logging.getLogger(__name__)

_SENTINEL = object()

LICENSE_HEAD = f"""
# Copyright {datetime.now().year} NXP
#
# SPDX-License-Identifier: Apache-2.0
"""

CONFIG_CHOICE_MAP = {
    "CONFIG_MCUX_PRJSEG_module.board.clock": "CONFIG_MCUX_PRJSEG_module.board.clock_customize_folder",
    "CONFIG_MCUX_PRJSEG_module.board.pinmux": "CONFIG_MCUX_PRJSEG_module.board.pinmux_customize_folder",
    r"CONFIG_MCUX_PRJSEG_module.use_.*_peripheral": "CONFIG_MCUX_PRJSEG_module.use_customize_peripheral",
    r"CONFIG_MCUX_PRJSEG_project.hw_(core|app|project)": "CONFIG_MCUX_PRJSEG_project.hw_app_customize_folder",
}

CONFIG_BLACK_LIST = [
    "CONFIG_MCUX_PRJSEG_config.arm.shared",
    "CONFIG_MCUX_PRJSEG_module.board.suite",
    "CONFIG_MCUX_PRJSEG_module.device.suite",
    # Hardcode for ps which have valid kconfig variables
    "CONFIG_MCUX_PRJSEG_module.board.lvgl",
]

# examples/eiq_examples/tflm_label_image_ext_mem: tflite
HEADER_EXTS = {".h", ".hpp", ".hh", ".hxx", ".inc", ".bin", ".tflite", ".mex"}

ADD_LINKER_CMD_PATTERN = re.compile(r"^mcux_add_(.*)_linker_script$")


def is_header_file(path: Union[str, Path]) -> bool:
    """Return True if the file path looks like a C/C++ header or shall be put into include dir."""
    return Path(path).suffix.lower() in HEADER_EXTS


def match_target(s, patterns):
    """
    Check if string s matches any pattern in patterns

    Args:
        s (str): String to be matched
        patterns (list): List of patterns to be matched, can be exact string or regex
    Returns:
        bool: True if s matches any pattern in patterns, False otherwise
    """
    for pat in patterns:
        if s == pat or re.search(pat, s):
            return True
    return False


def is_subpath(child: Path, parent: Path) -> bool:
    try:
        child.relative_to(parent)
        return True
    except ValueError:
        return False


def is_git_tracked(path: str) -> bool:
    p = os.path.abspath(path)
    cwd = os.path.dirname(p) or "."
    name = os.path.basename(p)
    r = subprocess.run(
        ["git", "-C", cwd, "ls-files", "--error-unmatch", "--", name],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return r.returncode == 0


class AppType(Enum):
    main_app = "main_app"
    linked_app = "linked_app"


@dataclass
class AppOptions:
    app_type: AppType.main_app
    source_dir: Path
    output_dir: Path
    cmake_opts: List[str] = None
    cmake_variables: Dict[str, str] = None
    name: Optional[str] = None
    trace_data: dict = None


@dataclass
class SharedOptions:
    source_dir: Path
    output_dir: Path
    cmake_opts: List[str] = field(default_factory=list)
    cmake_variables: Dict[str, str] = field(default_factory=dict)
    build: bool = False
    debug: bool = False

    board: Optional[str] = None
    core_id: Optional[str] = None
    board_core: Optional[str] = None
    target_apps: List[str] = field(default_factory=list)
    board_copy_folders: List[str] = field(default_factory=list)
    default_trace_folders: List[str] = field(default_factory=list)

    domains: Dict[str, str] = field(default_factory=dict)


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


def replace_cmake_variables(ori_str: str = "", var_dict: Optional[Dict[str, str]] = None) -> str:
    """Replace ${VAR} occurrences in ori_str with values from var_dict (case-insensitive)."""
    if not ori_str:
        return ori_str
    if not var_dict:
        return ori_str
    if "${" not in ori_str:
        return ori_str
    new_str = ori_str
    for k, v in var_dict.items():
        # Use case-insensitive pattern for variable name
        pattern = re.compile(rf"\$\{{{re.escape(k)}\}}", flags=re.IGNORECASE)
        new_str = pattern.sub(str(v), new_str)
    return new_str


def process_path(
    source_dir: Path, base_path: str = "", src: str = "", variables: Optional[Dict[str, str]] = None
) -> Union[None, Path, List[Path]]:
    """
    Resolve a possibly relative, templated, or globbed path against source_dir.

    - Replaces ${VAR} using variables (case-insensitive)
    - Resolves relative paths under source_dir
    - Expands globs and returns a list of Paths if needed
    - Returns None when the path cannot be resolved
    """
    variables = variables or {}
    try:
        if src == "/.":
            # '/.' may cause permission issues in Windows; normalize to './'
            logger.warning("The path '/.' is not safe, please use './' instead.")
            src = "./"
        s_src = Path(replace_cmake_variables(os.path.join(base_path or "", src), variables))
        if "${" in s_src.as_posix():
            return None
        if not s_src.is_absolute():
            s_src = source_dir / s_src
        # Glob expansion
        if any(wildcard in s_src.as_posix() for wildcard in ["*", "?", "[", "]"]):
            result: List[Path] = []
            for f in glob.glob(s_src.as_posix()):
                result.append(Path(f).resolve())
            return result
        if s_src.exists():
            return s_src.resolve()
        return None
    except Exception:
        return None


def should_skip_entry(entry: dict, current_board: Optional[str]) -> bool:
    """Return True if an entry with optional 'board' selector should be skipped."""
    board_condition = entry.get("board")
    if board_condition:
        if isinstance(board_condition, str):
            return board_condition != current_board
        elif isinstance(board_condition, list):
            return current_board not in board_condition
    return False


def timeit_if(attr="profile_enabled", flag_fn=None):
    """
    Decorator: profile only if enabled.
    - attr: attribute name on self or class, e.g., 'profile_enabled'
    - flag_fn: optional callable (args, kwargs) -> bool to decide dynamically
    """

    def deco(func):
        is_coro = inspect.iscoroutinefunction(func)

        def enabled(args, kwargs):
            if flag_fn:
                return bool(flag_fn(args, kwargs))
            obj = args[0] if args else None
            if obj is None:
                return False
            # check instance attr, then class attr
            return bool(getattr(obj, attr, getattr(type(obj), attr, False)))

        @wraps(func)
        async def aw(*args, **kwargs):
            if not enabled(args, kwargs):
                return await func(*args, **kwargs)
            t = time.perf_counter()
            try:
                return await func(*args, **kwargs)
            finally:
                print(f"{func.__qualname__} took {time.perf_counter() - t:.6f}s")

        @wraps(func)
        def sw(*args, **kwargs):
            if not enabled(args, kwargs):
                return func(*args, **kwargs)
            t = time.perf_counter()
            try:
                return func(*args, **kwargs)
            finally:
                print(f"{func.__qualname__} took {time.perf_counter() - t:.6f}s")

        return aw if is_coro else sw

    return deco


@contextmanager
def timeit_block(enabled, label="block"):
    """Context manager to profile arbitrary code blocks when enabled is True."""
    if not enabled:
        yield
        return
    t = time.perf_counter()
    try:
        yield
    finally:
        print(f"{label} took {time.perf_counter() - t:.6f}s")
