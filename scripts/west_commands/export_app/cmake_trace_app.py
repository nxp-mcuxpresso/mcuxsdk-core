# Copyright 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import logging
import traceback
import json
import yaml
import copy
import glob
from functools import cached_property
from pathlib import Path
from typing import Union
from .cmake_app import *
from .cmake_parser import *
from .misc import (
    LICENSE_HEAD,
    CONFIG_CHOICE_MAP,
    CONFIG_BLACK_LIST,
    AppType,
    SharedOptions,
    AppOptions,
    match_target,
)
from .misc import is_header_file, timeit_if, is_subpath, is_git_tracked, ADD_LINKER_CMD_PATTERN

logger = logging.getLogger(__name__)

INJECT_BUILD_DIR = "build_tmp"
INJECT_TRACE_FILE = "trace.json"

# Extra cmake options to generate trace file and useful kconfig files
TRACE_OPTIONS = [
    "-DGENERATE_PROMPTLESS_SYMS=y",
    "--trace",
    "--trace-expand",
    "--trace-format=json-v1",
    f"--trace-redirect=${{BINARY_DIR}}/{INJECT_TRACE_FILE}",
]

TARGET_FUNC_PATTERNS = [
    "include",
    "mcux_add_source",
    "mcux_add_include",
]

BYPASS_DIRS = (
    (SDK_ROOT_DIR / "cmake").as_posix(),
    (SDK_ROOT_DIR / "CMakeLists.txt").as_posix(),
)


class CmakeTraceApp(CmakeApp):
    def __init__(self, shared_options: SharedOptions, app_options: AppOptions):
        super().__init__(shared_options, app_options)
        self.file_cache = {}
        self.project_remove_sources = []
        self.processed_headers = []
        self.processed_files = []
        self.headers_map = {}
        self.sources_map = {}
        self.recorded_headers = []
        self.recorded_source_dirs = []
        self.dest_board_dirname = self.options.cmake_variables["board"]
        self.all_sources = {}
        if is_subpath(self.source_dir, SDK_ROOT_DIR):
            self.example_root = (SDK_ROOT_DIR / self.source_dir.relative_to(SDK_ROOT_DIR).parts[0]).as_posix()
        else:
            self.example_root = (SDK_ROOT_DIR / "examples").as_posix()
        if self.shared_options.core_id and self.options.cmake_variables.get("core_id"):
            self.dest_board_dirname += "_" + self.options.cmake_variables["core_id"]
        self.output_board_dir = self.output_dir / self.dest_board_dirname
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.output_board_dir.mkdir(parents=True, exist_ok=True)
        self.app_files = [self.source_list_file.as_posix()]
        self.trace_files = []
        # receiver contexts hold staged data while reconstructing cmake
        self.app_receiver = {
            "result": [],
            "mcux_add_include": [],
            "mcux_add_source": [],
            "idx": 0,
            "output_dir": self.output_dir,
            "skip_line": 0,
            "skip_file": None,
        }
        self.trace_receiver = {
            "result": [],
            "mcux_add_include": [],
            "mcux_add_source": [],
            "output_dir": self.output_board_dir,
            "ps_list": [],
            "cur_ps": None,
            "cur_ps_file": None,
            "skip_line": 0,
            "skip_file": None,
        }
        if self.options.app_type == AppType.linked_app:
            self.app_id = self.options.name
        if self.shared_options.core_id:
            self.cmake_trace_dir = "${board}_${core_id}"
        else:
            self.cmake_trace_dir = "${board}"

    def run(self):
        logger.debug("Export board specific freestanding example for " + self.source_list_file.as_posix())
        try:
            self.process_misc_files()
            if self.options.app_type == AppType.main_app:
                if not (result := self.get_trace_result()):
                    return False
                if self.is_sysbuild:
                    self.analyze_sysbuild(result)
                self.options.trace_data = result[self.app_id]

            if self.is_sysbuild or self.options.app_type == AppType.linked_app:
                self.build_dir = Path(self.shared_options.domains[self.app_id]["build_dir"])
            else:
                self.build_dir = self.shared_options.output_dir / INJECT_BUILD_DIR
            self.board_root = Path(self.options.cmake_variables["SdkRootDirPath"]) / Path(
                self.options.cmake_variables.get("board_root", "examples/_boards")
            )
            self.y_selecting_ps = []
            if (force_selected_ps := self.build_dir / ".force_selected_ps").exists():
                self.y_selecting_ps = open(force_selected_ps, "r").read().splitlines()
            self.preinclude_files = [os.path.basename(f) for f in glob.glob(f"{self.build_dir.as_posix()}/*.h")]
            self.analyze_trace_json(self.app_id, self.options.trace_data)
            self.dump_result()
            self.combine_prj_conf()
            if self.replacements:
                self.apply_replacements(self.replacements)
            if not self.shared_options.debug:
                shutil.rmtree(self.options.output_dir / INJECT_BUILD_DIR, ignore_errors=True)
        except Exception as e:
            if self.shared_options.debug:
                print(e)
                traceback.print_exc()
            return False
        return True

    def process_example_yml(self, target_apps=[]):
        """
        Update board fields in example.yml to only keep exported boards

        This is used for more accurate list_project command

        Args:
            target_apps (list): List of target apps to be processed
        Returns:
            dict: Processed example.yml data
        """
        result = super().process_example_yml(target_apps)
        example_name, example_data = next(iter(result[0].items()))
        # Ensure list_project only catch exported boards
        if filtered := {
            k: v
            for k, v in example_data.get("boards", {}).items()
            if k.startswith(self.options.cmake_variables["board"])
        }:
            result[0][example_name]["boards"] = filtered
        else:
            result[0][example_name]["boards"] = {}

        return result

    @timeit_if(flag_fn=opt_debug)
    def get_trace_result(self):
        """
        Run the inject command, collect and filter CMake trace output, and return per-app/domain results.
        Behavior:
        - Logs and executes the configured inject command in SDK_ROOT_DIR.
        - Expects a trace JSON at <output_dir>/<INJECT_BUILD_DIR>/<INJECT_TRACE_FILE>.
        - If sysbuild:
            - Adds a "sysbuild" entry using the top-level trace.
            - Reads domains.yaml to map build directories to domain names.
            - Adds one entry per domain using each domain's trace file.
        - If not sysbuild:
            - Adds a single entry keyed by the app name.
        Failure handling:
        - If the inject command fails or the expected trace file is missing, logs an error,
            prints the command's stderr, and returns None.
        Side effects:
        - Runs a subprocess.
        - Logs debug/error messages.
        - Prints stderr on failure.
        - Reads trace JSON and (for sysbuild) domains.yaml.
        - Delegates trace filtering to self.filter_trace_json().
                dict[str, dict] | None: Mapping from app/domain name to filtered trace data,
                or None if generation/loading fails.
        """

        logger.debug(f"Analyze trace files with command:")
        logger.debug(" ".join(self.inject_cmd))
        result = {}
        status = subprocess.run(
            self.inject_cmd,
            cwd=SDK_ROOT_DIR.as_posix(),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if status.returncode != 0:
            logger.error(f"Failed to run inject command: {' '.join(self.inject_cmd)}")
            print(status.stderr.decode("utf-8"))
            return None
        if not (trace_json_path := self.shared_options.output_dir / INJECT_BUILD_DIR / INJECT_TRACE_FILE).exists():
            logger.error(f"Cannot find the trace file {trace_json_path.as_posix()}, something must be wrong.")
            return None
        if self.is_sysbuild:
            result["sysbuild"] = self.filter_trace_json(trace_json_path)
            domains = yaml.safe_load(open(self.shared_options.output_dir / INJECT_BUILD_DIR / "domains.yaml"))
            for domain in domains.get("domains", {}):
                result[domain["name"]] = self.filter_trace_json(Path(domain["build_dir"]) / INJECT_TRACE_FILE)
                if (src := Path(domain["source_dir"]).resolve().as_posix()) == self.source_dir.as_posix():
                    self.app_id = domain["name"]
                domain["source_dir"] = src
                self.shared_options.domains[domain["name"]] = domain
        else:
            self.app_id = self.app_name
            result[self.app_id] = self.filter_trace_json(trace_json_path)
        return result

    @timeit_if(flag_fn=opt_debug)
    def filter_trace_json(self, trace_json_path):
        bypass_dirs = [
            (SDK_ROOT_DIR / "cmake").as_posix(),
            (SDK_ROOT_DIR / "CMakeLists.txt").as_posix(),
            trace_json_path.parent.as_posix(),
        ]

        def check_path(path):
            # TODO bypass sysbuild example source dir
            if path.startswith(self.source_dir.as_posix()):
                return True
            if self.shared_options.default_trace_folders and not any(
                [path.startswith(p) for p in self.shared_options.default_trace_folders]
            ):
                return False
            if any([path.startswith(p) for p in bypass_dirs]):
                return False
            return True

        # Preprocess line by line to avoid large memory usage
        filtered_result = []
        filtered_paths = [self.source_list_file.as_posix()]
        if self.shared_options.board_copy_folders:
            filtered_paths.extend(self.shared_options.board_copy_folders)
        with open(trace_json_path) as f:
            for line in f:
                j_line = json.loads(line)
                if not (p_file := j_line.get("file")):
                    continue
                # Record all sources to avoid multiple declaration
                if j_line.get("cmd") == "mcux_add_source":
                    self.get_all_path(j_line)
                elif j_line.get("cmd") == "mcux_project_remove_source":
                    self.trace_mcux_project_remove_source(j_line, True)
                if check_path(p_file):
                    del j_line["time"]
                    if (
                        j_line.get("cmd") in ["mcux_set_variable", "set", "mcux_set_list"]
                        and len(j_line.get("args", [])) >= 2
                    ):
                        self.options.cmake_variables[j_line["args"][0]] = j_line["args"][1]
                    filtered_result.append(j_line)
        if self.shared_options.debug:
            with open(trace_json_path.parent / "trace_filtered.json", "w") as f:
                for item in filtered_result:
                    f.write(json.dumps(item) + "\n")
        return filtered_result

    def analyze_sysbuild(self, result):
        sysbuild_trace = result["sysbuild"]
        sysbuild_cmakes = {}
        sysbuild_path_map = {}
        for j in sysbuild_trace:
            try:
                p_file, g_frame, cmd, args = (
                    j["file"],
                    j["global_frame"],
                    j["cmd"].lower(),
                    j["args"],
                )
            except KeyError:
                continue
            if cmd == "include":
                inc_path = Path(args[0]).resolve().as_posix()
                if p_file not in sysbuild_cmakes:
                    if p_file not in self.file_cache:
                        self.file_cache[p_file] = open(p_file, "r").readlines()
                    if not any(inc_path == t.get("file") for t in sysbuild_trace):
                        self._write_raw(j, sysbuild_cmakes.setdefault(p_file, []))
                if p_file not in sysbuild_path_map:
                    sysbuild_path_map[p_file] = []
                sysbuild_path_map[p_file].append(inc_path)
                continue
            if any(parent := [k for k, v in sysbuild_path_map.items() if p_file in v]):
                key = parent[0]
            else:
                key = p_file
            if key not in sysbuild_cmakes:
                sysbuild_cmakes[key] = []
            if cmd in ["externalzephyrproject_add", "externalmcuxproject_add"]:
                sysbuild_cmakes[key].append(self.trace_externalmcuxproject_add(j, result))
            else:
                # examples/wireless_examples/zigbee/router/freertos/sysbuild.cmake
                if cmd == "if":
                    continue
                if p_file not in self.file_cache:
                    self.file_cache[p_file] = open(p_file, "r").readlines()
                self._write_raw(j, sysbuild_cmakes[key])
        for k, v in sysbuild_cmakes.items():
            if not v:
                continue
            self.write_cmake_file(self.shared_options.output_dir / Path(k).parent.name / Path(k).name, v)

    # Internal helper to write raw lines while normalizing ${CMAKE_CURRENT_LIST_DIR}
    def _write_raw(self, j, result_list):
        try:
            raw = []
            if j.get("line_end"):
                lines = self.file_cache[j["file"]][j["line"] - 1 : j["line_end"]]
                formatted_lines = []
                indent = len(lines[0]) - len(lines[0].lstrip())
                if not indent:
                    raw.extend(lines)
                else:
                    for line in lines:
                        if len(line) - len(line.lstrip()) >= indent:
                            formatted_lines.append(line[indent:])
                        else:
                            formatted_lines.append(line)
                    raw.extend(formatted_lines)
            else:
                raw = [self.file_cache[j["file"]][j["line"] - 1].lstrip()]
            for i, line in enumerate(raw):
                if "${CMAKE_CURRENT_LIST_DIR}" not in line:
                    continue
                raw[i] = line.replace(
                    "${CMAKE_CURRENT_LIST_DIR}",
                    "${SdkRootDirPath}/" + Path(j["file"]).parent.relative_to(SDK_ROOT_DIR).as_posix(),
                )
            result_list.extend(raw)
            result_list.append("\n")
        except Exception:
            if self.shared_options.debug:
                traceback.print_exc()
            logger.error(f"Failed to write line {j.get('line')} of file {j.get('file')}")

    def check_include_path(self, path):
        if any([path.startswith(p) for p in BYPASS_DIRS]):
            return False
        # Hardcode for non --bf mode, skip reconfig.cmake and files out of example root
        if not self.shared_options.board_copy_folders and (
            path.endswith("reconfig.cmake") or not path.startswith(self.example_root)
        ):
            return False
        if self.shared_options.board_copy_folders and not match_target(path, self.shared_options.board_copy_folders):
            return False
        return True

    @timeit_if(flag_fn=opt_debug)
    def analyze_trace_json(self, name, trace_data):
        logger.debug(f"Process trace data for {name}")
        # For traced files
        self.trace_files = []

        def check_trace_file(p_file):
            if (p_file not in self.app_files) and (p_file not in self.trace_files):
                if self.shared_options.board_copy_folders and match_target(
                    p_file, self.shared_options.board_copy_folders
                ):
                    logger.debug(f"Add board cmake file {p_file}")
                    self.trace_files.append(p_file)
                else:
                    return False
            # Avoid IO multiple times
            if p_file not in self.file_cache:
                self.file_cache[p_file] = open(p_file, "r").readlines()
            return True

        for i, j in enumerate(trace_data):
            if not (p_file := j.get("file")):
                continue
            if not check_trace_file(p_file):
                continue

            if p_file in self.app_files:
                if self.app_receiver["skip_file"] != p_file:
                    self.app_receiver["skip_line"] = 0
                    self.app_receiver["skip_file"] = None
                if self.app_receiver["skip_line"] and j["line"] < self.app_receiver["skip_line"]:
                    continue
                self.process_app_context(i, j, trace_data)
            else:
                if self.trace_receiver["skip_file"] != p_file:
                    self.trace_receiver["skip_line"] = 0
                    self.trace_receiver["skip_file"] = None
                if self.trace_receiver["skip_line"] and j["line"] < self.trace_receiver["skip_line"]:
                    continue
                self.process_trace_context(i, j, trace_data)

    def write_raw_if(self, content, receiver, line):
        receiver.append(content[line - 1])
        compansated_endif = 1
        while compansated_endif != 0:
            _cmd = content[line].lstrip()
            if _cmd.startswith("if"):
                compansated_endif += 1
            elif _cmd.startswith("endif"):
                compansated_endif -= 1
            self.app_receiver["result"].append(content[line])
            line += 1
        self.app_receiver["result"].append("\n")
        return line + 1

    def process_app_context(self, i, j, trace_data=None):
        p_file, cmd, args = (j["file"], j["cmd"].lower(), j["args"])
        if cmd in ["mcux_add_include", "mcux_add_source"]:
            if (ret := getattr(self, f"trace_{cmd}")(j, self.app_receiver["output_dir"])) == 0:
                self._write_raw(j, self.app_receiver["result"])
            else:
                self.app_receiver["result"].extend(ret)
        elif ADD_LINKER_CMD_PATTERN.match(cmd):
            if not (ret := self.trace_mcux_add_linker_script(j, self.app_receiver["output_dir"])):
                self._write_raw(j, self.app_receiver["result"])
            else:
                self.app_receiver["result"].append(ret)
        elif cmd == "include":
            path = Path(args[0])
            if not path.is_absolute():
                path = Path(p_file).parent / path
            path = path.resolve()
            if self.check_include_path(path.as_posix()):
                if path.name == "reconfig.cmake":
                    logger.debug(f"Add app reconfig cmake file {path.as_posix()}")
                    # Put reconfig.cmake in board_files.cmake may cause examples/wireless_examples/zigbee/coordinator_ble_wuart/bm fail
                    # self.app_files.append(path.as_posix())
                else:
                    logger.debug(f"Add app include cmake file {path.as_posix()}")
                self.app_files.append(path.as_posix())
            else:
                self._write_raw(j, self.app_receiver["result"])
            if path.as_posix() == BYPASS_DIRS[1]:
                self.app_receiver['idx'] = len(self.app_receiver["result"])
        elif hasattr(self, f"trace_{cmd}"):
            self.app_receiver["result"].extend(getattr(self, f"trace_{cmd}")(j))
        elif cmd == "if":
            if i == len(trace_data) - 1:
                return
            if trace_data[i + 1].get("cmd") == "if" or trace_data[i + 1].get("file") != p_file:
                return
            self.app_receiver["skip_line"] = self.write_raw_if(
                self.file_cache[p_file], self.app_receiver["result"], j["line"]
            )
            self.app_receiver["skip_file"] = p_file
        elif cmd in ExtensionMap.source_related_extensions() and "BASE_PATH" not in args:
            j["args"][:0] = [
                "BASE_PATH",
                "${SdkRootDirPath}/" + (Path(p_file).parent).relative_to(SDK_ROOT_DIR).as_posix(),
            ]
            self.app_receiver["result"].append(CMakeFunction(j))
        else:
            self._write_raw(j, self.app_receiver["result"])

    def process_trace_context(self, i, j, trace_data):
        p_file, cmd, args = (j["file"], j["cmd"].lower(), j["args"])
        if cmd == "if":
            self.trace_receiver["cur_ps"] = None
            if args[0].startswith("CONFIG_MCUX_PRJSEG_"):
                if args[0] in self.y_selecting_ps:
                    logger.error(f"{args[0]} is y-selected by other symbols, so it will not be processed.")
                # elif args[0].startswith("CONFIG_MCUX_PRJSEG_module.board.wireless"):
                #     pass
                elif args[0] in CONFIG_BLACK_LIST:
                    pass
                else:
                    self.trace_receiver["cur_ps"] = args[0]
                    self.trace_receiver["cur_ps_file"] = p_file
            return
        if not (self.trace_receiver["cur_ps"] or p_file.endswith("reconfig.cmake")):
            return
        if cmd in ["mcux_add_include", "mcux_add_source"]:
            if (ret := getattr(self, f"trace_{cmd}")(j, self.trace_receiver["output_dir"])) == 0:
                self._write_raw(j, self.trace_receiver["result"])
            else:
                self.trace_receiver["result"].extend(ret)
        elif ADD_LINKER_CMD_PATTERN.match(cmd):
            if not (ret := self.trace_mcux_add_linker_script(j, self.trace_receiver["output_dir"])):
                self._write_raw(j, self.trace_receiver["result"])
            else:
                self.trace_receiver["result"].append(ret)
        elif cmd == "include":
            path = Path(args[0]).resolve()
            if not path.is_absolute():
                path = Path(p_file).parent / path
            if self.check_include_path(path.as_posix()):
                self.trace_files.append(path.as_posix())
                logger.debug(f"Add trace include cmake file {path.as_posix()}")
            else:
                self._write_raw(j, self.trace_receiver["result"])
        elif hasattr(self, f"trace_{cmd}"):
            self.trace_receiver["result"].extend(getattr(self, f"trace_{cmd}")(j))
        elif cmd == "if":
            if trace_data[i + 1].get("cmd") == "if" or trace_data[i + 1].get("file") != p_file:
                return
            self.trace_receiver["skip_line"] = self.write_raw_if(
                self.file_cache[p_file], self.trace_receiver["result"], j["line"]
            )
            self.trace_receiver["skip_file"] = p_file
        elif cmd in ExtensionMap.source_related_extensions() and "BASE_PATH" not in args:
            j["args"][:0] = [
                "BASE_PATH",
                "${SdkRootDirPath}/" + (Path(p_file).parent).relative_to(SDK_ROOT_DIR).as_posix(),
            ]
            self.trace_receiver["result"].append(CMakeFunction(j))
        else:
            self._write_raw(j, self.trace_receiver["result"])
        if (
            p_file == self.trace_receiver["cur_ps_file"]
            and self.trace_receiver["cur_ps"] not in self.trace_receiver["ps_list"]
        ):
            logger.debug(f"Add processed ps {self.trace_receiver['cur_ps']} from {p_file}")
            self.trace_receiver["ps_list"].append(self.trace_receiver["cur_ps"])

    def dump_result(self):
        self.update_kconfig_path()
        if self.shared_options.board_copy_folders:
            if mex_file := next((f for f in os.listdir(self.output_board_dir) if f.endswith(".mex")), None):
                add_mex_statement = f"mcux_add_config_mex_path( PATH {self.cmake_trace_dir} )"
                self.app_receiver["result"].append(add_mex_statement)
            self.write_cmake_file(
                self.output_dir / self.dest_board_dirname / "board_files.cmake",
                self.trace_receiver["result"],
            )
            self.trace_receiver["ps_list"] = list(set(self.trace_receiver["ps_list"]))
            board_prj_conf, force_selected = self.create_board_prj_conf(
                self.build_dir,
                self.trace_receiver["ps_list"],
            )
            if force_selected:
                self.update_app_kconfig(force_selected)
            open(self.trace_receiver["output_dir"] / "prj.conf", "a", encoding="utf-8").write(
                "\n".join(board_prj_conf)
            )
            self.update_cmake_file()
        self.write_cmake_file(self.output_dir / "CMakeLists.txt", self.app_receiver["result"])

    def write_cmake_file(self, path, result):
        with open(path, "w") as f:
            f.write(LICENSE_HEAD + "\n")
            for line in result:
                if isinstance(line, CMakeFunction):
                    f.write(line.to_cmake() + "\n")
                else:
                    f.write(line)

    def get_all_path(self, j):
        parsed_func = CMakeFunction(j)
        cur_dir = Path(j["file"]).parent
        base_path = (
            Path(parsed_func.single_args.get("BASE_PATH")) if parsed_func.single_args.get("BASE_PATH") else None
        )
        r_sources = list(
            set(
                [
                    p
                    for s in parsed_func.multi_args.get("SOURCES", [])
                    for p in self._resolve_src_path(cur_dir, base_path, Path(s))
                ]
            )
        )
        for r_source in r_sources:
            if not r_source.exists():
                continue
            r_source_str = r_source.as_posix()
            if r_source_str not in self.all_sources:
                self.all_sources[r_source_str] = []
            if j["file"] not in self.all_sources[r_source_str]:
                self.all_sources[r_source_str].append(j["file"])

    def _resolve_include_path(self, cur_dir: Path, base_path: Union[Path, None], path: Path) -> Path:
        r_path = cur_dir / path
        if base_path:
            r_path = base_path / path
        elif path.is_absolute():
            r_path = path
        return r_path.resolve()

    def _resolve_src_path(self, cur_dir: Path, base_path: Union[Path, None], path: Path) -> Path:
        result = []
        r_path = cur_dir / path
        if base_path:
            r_path = base_path / path
        elif path.is_absolute():
            r_path = path
        if any(wildcard in r_path.as_posix() for wildcard in ["*", "?", "[", "]"]):
            result = []
            for f in glob.glob(r_path.as_posix()):
                result.append(Path(f).resolve())
        else:
            result = [r_path.resolve()]
        return result

    def _in_output_dir(self, path: Path) -> bool:
        return is_subpath(path, self.shared_options.output_dir)

    def _finalize_cmake_args(self, parsed_func, cur_dir, success_items, failed_items, key):
        ret = []
        if success_items:
            success_func = copy.deepcopy(parsed_func)
            if success_func.single_args.get("BASE_PATH"):
                del success_func.single_args["BASE_PATH"]
            success_func.multi_args[key] = sorted(success_items)
            ret.append(success_func)
        if failed_items:
            failed_func = copy.deepcopy(parsed_func)
            if not failed_func.single_args.get("BASE_PATH"):
                failed_func.single_args["BASE_PATH"] = cur_dir.as_posix()
            failed_func.single_args["BASE_PATH"] = failed_func.single_args["BASE_PATH"].replace(
                SDK_ROOT_DIR.as_posix(), "${SdkRootDirPath}"
            )
            failed_func.multi_args[key] = sorted(failed_items)
            ret.append(failed_func)
        return ret

    def check_multiple_declare_source(self, path, loc):
        """
        Checks whether the given source file path and its location meet specific criteria.
        Args:
            path (str): The source file path to check.
            loc (str): The location associated with the source file.
        Returns:
            bool: True if the source file and its locations satisfy the required conditions,
                  False otherwise.
        The method verifies:
            - If the only location for the path is `loc`, returns True.
            - If `shared_options.board_copy_folders` is set, ensures each location for the path
              contains any of the specified board copy folders.
            - If `shared_options.board_copy_folders` is not set, ensures each location starts
              with `example_root`.
        """

        locs = self.all_sources.get(path, [])
        if locs == [loc]:
            return True
        for f in locs:
            if self.shared_options.board_copy_folders:
                if not match_target(f, self.shared_options.board_copy_folders):
                    return False
            else:
                # NOTE hardcode
                if not f.startswith(self.example_root):
                    return False
        return True

    def get_target_path(self, inc):
        if is_subpath(inc, self.source_dir):
            return inc.relative_to(self.source_dir).as_posix()
        if inc.as_posix() in self.headers_map:
            return self.headers_map[inc.as_posix()]
        parts = list(inc.parts)
        key = parts[-1]
        i = 2
        while key in self.headers_map.values() and i <= len(parts):
            key = "_".join(parts[-i:])
            i += 1
        return f"{key}"

    def trace_mcux_add_source(self, j, output_dir):
        parsed_func = CMakeFunction(j)
        failed_sources = []
        sources = []
        cur_dir = Path(j["file"]).parent
        base_path = Path(bp) if (bp := parsed_func.single_args.get("BASE_PATH")) else None

        simple_src = set(parsed_func.single_args) <= {"BASE_PATH"} and set(parsed_func.multi_args) == {"SOURCES"}
        for s in parsed_func.multi_args.get("SOURCES", []):
            for r_source in self._resolve_src_path(cur_dir, base_path, Path(s)):
                if self._in_output_dir(r_source):
                    return 0
                if not r_source.exists():
                    continue
                r_source_str = r_source.as_posix()
                if not self.check_multiple_declare_source(r_source_str, j["file"]):
                    logger.debug(f"Skip out of tree source file {r_source_str}")
                    continue
                if r_source_str in self.project_remove_sources:
                    logger.debug(f"Skip removed source file {r_source_str}")
                    continue
                target_dir = self.get_target_path(r_source.parent)
                if is_header_file(r_source):
                    if r_source.parent.as_posix() in self.headers_map:
                        target_dir = self.headers_map[r_source.parent.as_posix()]
                    else:
                        self.headers_map[r_source.parent.as_posix()] = target_dir
                if r_source_str in self.sources_map:
                    logger.debug(f"Skip already processed source file {r_source_str}")
                    if simple_src:
                        continue
                if r_source.name in self.preinclude_files:
                    continue
                target_src = output_dir / target_dir / r_source.name
                if target_src.exists() and r_source.name.endswith((".S", ".s")):
                    target_src = output_dir / target_dir / r_source.parent.name / r_source.name
                self.recorded_source_dirs.append(target_src.relative_to(self.output_dir).parent.as_posix())
                self.sources_map[r_source_str] = target_src
                self.sources_map[r_source_str].parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(r_source, self.sources_map[r_source_str])
                sources.append(self.sources_map[r_source_str].relative_to(output_dir).as_posix())

        return self._finalize_cmake_args(parsed_func, cur_dir, sources, failed_sources, "SOURCES")

    def trace_mcux_add_include(self, j, output_dir):
        parsed_func = CMakeFunction(j)
        failed_includes = []
        includes = []
        simple_inc = set(parsed_func.single_args) <= {"BASE_PATH"} and set(parsed_func.multi_args) == {"INCLUDES"}

        cur_dir = Path(j["file"]).parent
        base_path = Path(bp) if (bp := parsed_func.single_args.get("BASE_PATH")) else None
        for inc in parsed_func.multi_args.get("INCLUDES", []):
            if inc in ["/","/.", "\\", "\\."]:
                inc = "."
            r_include = self._resolve_include_path(cur_dir, base_path, Path(inc))
            if self._in_output_dir(r_include):
                return 0
            if not r_include.exists():
                failed_includes.append(inc)
                continue
            r_include_str = r_include.as_posix()
            if r_include_str in self.processed_headers:
                continue
            if r_include_str in self.headers_map:
                target_dir = self.headers_map[r_include_str]
            else:
                target_dir = self.headers_map[r_include_str] = self.get_target_path(r_include)
            (output_dir / target_dir).mkdir(parents=True, exist_ok=True)
            # Formal sdk example shall record all header files through mcux_add_source
            for item in r_include.iterdir():
                if item.is_file() and is_header_file(item.as_posix()) and item.name not in self.preinclude_files:
                    if item.name.endswith(".mex"):
                        target_header = output_dir / item.name
                    else:
                        target_header = output_dir / self.headers_map[r_include_str] / item.name
                    if target_header.exists():
                        logger.debug(f"{j['file']}: {item.name} already exists, skip copying.")
                    else:
                        logger.debug(f"Copy header file {item.as_posix()}")
                        shutil.copy(
                            item,
                            target_header,
                        )

            # if self.headers_map[r_include_str] in self.processed_headers:
            #     continue
            # for examples/edgefast_bluetooth_examples/wifi_cli_over_ble_wu
            if "TARGET_FILES" not in parsed_func.multi_args:
                self.processed_headers.append(self.headers_map[r_include_str])
            self.recorded_headers.append((output_dir / target_dir).relative_to(self.output_dir).as_posix())
            includes.append(self.headers_map[r_include_str])

        includes = list(set(includes))  # Remove duplicates
        failed_includes = list(set(failed_includes))
        return self._finalize_cmake_args(parsed_func, cur_dir, includes, failed_includes, "INCLUDES")

    def trace_mcux_add_linker_script(self, j, output_dir):
        parsed_func = CMakeFunction(j)
        cur_dir = Path(j["file"]).parent
        base_path = Path(bp) if (bp := parsed_func.single_args.get("BASE_PATH")) else None
        if not (linker := self._resolve_src_path(cur_dir, base_path, Path(parsed_func.single_args["LINKER"]))):
            logger.warning(f'{j["file"]}: Cannot resolve linker script path {parsed_func.single_args["LINKER"]}')
            return None
        linker = linker[0]
        linker_str = linker.as_posix()
        if not linker.exists():
            # Linker file maybe generated during build
            logger.debug(f'{j["file"]}: Cannot find linker file {linker_str}')
            return None
        if not is_git_tracked(linker_str):
            # For generated linker script, do not copy
            return None
        if parsed_func.single_args.get("BASE_PATH"):
            del parsed_func.single_args["BASE_PATH"]
        parsed_func.single_args["LINKER"] = f"{linker.name}"
        target_linker = output_dir / linker.name
        target_linker.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(linker, target_linker)
        return parsed_func

    def trace_mcux_project_remove_source(self, j, preprocess=False):
        if not preprocess:
            return []
        parsed_func = CMakeFunction(j)
        cur_dir = Path(j["file"]).parent
        base_path = Path(bp) if (bp := parsed_func.single_args.get("BASE_PATH")) else None
        r_sources = list(
            set(
                [
                    p
                    for s in parsed_func.multi_args.get("SOURCES", [])
                    for p in self._resolve_src_path(cur_dir, base_path, Path(s))
                ]
            )
        )
        for r_source in r_sources:
            if self._in_output_dir(r_source):
                continue
            r_source_str = r_source.as_posix()
            if r_source_str not in self.project_remove_sources:
                self.project_remove_sources.append(r_source_str)
        return []

    def trace_externalmcuxproject_add(self, j, result):
        """
        Handle ExternalMcuxProject_Add/ExternalZephyrProject command in sysbuild.cmake
        """
        parsed_func = CMakeFunction(j)
        source_dir = parsed_func.single_args.get("SOURCE_DIR", "")
        if not source_dir:
            logger.fatal("Cannot find correct SOURCE_DIR from sysbuild.cmake")
        source_dir = Path(source_dir).resolve()
        if (app_name := parsed_func.single_args.get("APPLICATION")) not in result:
            logger.fatal(
                f"Cannot find correct APPLICATION {parsed_func.single_args.get('APPLICATION')} from sysbuild.cmake"
            )
        sysbuild_app_options = AppOptions(
            name=app_name,
            app_type=AppType.linked_app,
            source_dir=source_dir,
            output_dir=self.shared_options.output_dir / source_dir.name,
            cmake_variables=self.shared_options.cmake_variables,
            trace_data=result[app_name],
        )
        for k, v in parsed_func.single_args.items():
            # Update cmake variables except SOURCE_DIR and APPLICATION
            if k not in ["SOURCE_DIR", "APPLICATION"]:
                sysbuild_app_options.cmake_variables[k] = v
        sysbuild_app = CmakeTraceApp(self.shared_options, sysbuild_app_options)
        if not sysbuild_app.run():
            logger.fatal(f"Failed to process linked app {sysbuild_app_options.name} in sysbuild.cmake")
        parsed_func.single_args["SOURCE_DIR"] = "/".join(["${APP_DIR}", "..", source_dir.name])
        return parsed_func

    def create_board_prj_conf(self, build_dir, ps_list):
        """
        Create board specific prj.conf based on the .config and .promptless_config under build dir
        1. Keep all CONFIG_MCUX_COMPONENT_xxx and CONFIG_MCUX_PRJSEG_xxx from build .config
        2. Disable all CONFIG_MCUX_PRJSEG_xxx not in ps_list
        3. Enable all CONFIG_MCUX_PRJSEG_xxx in CONFIG_CHOICE_MAP
        4. If any symbol in ps_list is in .promptless_config, force select it

        Args:
            build_dir (Path): Path to the build directory
            ps_list (list): List of promptless symbols to be enabled
        Returns:
            board_prj_conf (list): List of lines to be written to board specific prj.conf
            force_selected (list): List of symbols to be force selected in app Kconfig
        """
        board_prj_conf = []
        comp_list = []
        promptless_syms = []
        force_selected = []

        try:
            promptless_syms = open(promptless_config := build_dir / ".promptless_config", "r").read().splitlines()
            raw_config = open(build_config := build_dir / ".config", "r").read().splitlines()
        except Exception as e:
            logger.fatal(
                f"Cannot read build config files {build_config.as_posix()} or {promptless_config.as_posix()}, error: {e}"
            )
            return board_prj_conf, force_selected

        for c in raw_config:
            # Middleware may cause Kconfig build issues
            if not (match_result := re.match(r"CONFIG_MCUX_(COMPONENT|PRJSEG)[^=]+", c)):
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
            board_prj_conf.append(f"{ps}=n")
            for k, v in CONFIG_CHOICE_MAP.items():
                if re.match(k, ps):
                    board_prj_conf.append(f"{v}=y")
        return board_prj_conf, force_selected

    def update_app_kconfig(self, force_selected):
        """
        Update the freestanding app Kconfig to force select promptless symbols
        1. If Kconfig exists, append to the end of the file
        2. If Kconfig not exists, create one with rsource SdkRootDirPath/Kconfig.mcuxpresso
        3. Add a new config CUSTOM_APP_<APP_NAME> to indicate this is a freestanding app
        4. Force select promptless symbols

        Args:
            force_selected (list): List of symbols to be force selected
        """
        result = [
            f"config CUSTOM_APP_{self.app_id.upper()}",
            "    bool",
            "    default y",
        ]
        result.extend([f"    select {item}" for item in force_selected])
        if (dest_kconfig := self.output_dir / "Kconfig").exists():
            open(dest_kconfig, "a", encoding="utf-8").write("\n" + "\n".join(result) + "\n")
        else:
            result.insert(0, 'rsource "${SdkRootDirPath}/Kconfig.mcuxpresso"')
            open(dest_kconfig, "w", encoding="utf-8").write("\n".join(result) + "\n")

    def update_cmake_file(self):
        if self.shared_options.core_id:
            trace_cmake = '\ninclude("${board}_${core_id}/board_files.cmake")\n'
        else:
            trace_cmake = "\ninclude(${board}/board_files.cmake)\n"
        prepend_content = [
            f"cmake_path(APPEND conf_file_path ${{CMAKE_CURRENT_LIST_DIR}} {self.cmake_trace_dir} prj.conf)\n",
            f"list(APPEND CONF_FILE ${{conf_file_path}})\n",
        ]
        insert_index = 0
        for i, line in enumerate(self.app_receiver["result"]):
            line = line.strip()
            if line.startswith("#") or line == "" or line.startswith("cmake_minimum_required"):
                insert_index = i + 1
            else:
                break
        self.app_receiver["result"] = (
            self.app_receiver["result"][:insert_index] + prepend_content + self.app_receiver["result"][insert_index:]
        )
        missing_includes = []
        self.recorded_headers = list(set(self.recorded_headers))
        self.recorded_source_dirs = list(set(self.recorded_source_dirs))
        for s in self.recorded_source_dirs:
            if s in self.recorded_headers:
                continue
            missing_includes.append(s)
        if self.app_receiver["idx"]:
            self.app_receiver["result"].insert(self.app_receiver["idx"], trace_cmake)
        else:
            self.app_receiver["result"].append(trace_cmake)
        if missing_includes:
            append_func = f"\nmcux_add_include(INCLUDES {' '.join(missing_includes)})\n"
            self.app_receiver["result"].append(append_func)

    @cached_property
    def inject_cmd(self):
        """
        Cmake configuration command to generate trace file
        """
        if self.options.app_type != AppType.main_app:
            return []
        cmd_list = [
            "west",
            "build",
            "-b",
            self.options.cmake_variables["board"],
            "-p",
            "always",
            self.source_dir.as_posix(),
            "-d",
            (self.shared_options.output_dir / INJECT_BUILD_DIR).as_posix(),
            "--cmake-only",
        ]
        if self.is_sysbuild:
            cmd_list.append("--sysbuild")
        cmd_list.append("--")
        if self.shared_options.core_id:
            cmd_list.append(f"-Dcore_id={self.shared_options.core_id}")
        trace_parameters = deepcopy(TRACE_OPTIONS)
        trace_parameters[-1] = trace_parameters[-1].replace(
            "${BINARY_DIR}",
            (self.shared_options.output_dir / INJECT_BUILD_DIR).as_posix(),
        )
        cmd_list.extend(trace_parameters)
        if self.is_sysbuild:
            cmd_list.append(f"-DCMAKE_SYSBUILD_OPTIONS='{';'.join(TRACE_OPTIONS)}'")
        return cmd_list
