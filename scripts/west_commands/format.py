# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import os
import pkg_resources
import glob
from pathlib import Path
from west.commands import WestCommand
try:
    from identify.identify import tags_from_path
except ImportError:
    print("Please run 'pip install -U identify'")

# Meta hook config style from pre-commit, add 'dep' for required pip package
DEFAULT_CONFIG = [
    {
        "id": "cmake_format",
        "entry": "cmake-format",
        "dep": "cmakelang",
        "args": ["-i"],
        "types": ["cmake"],
    },
    {
        "id": "clang_format",
        "entry": "clang-format",
        "dep": "clang-format",
        "args": ["-i"],
        "types": ["c", "c++", "cuda"],
    },
    {
        "id": "py_format",
        "entry": "black",
        "dep": "black",
        "types": ["python"]
    },
    {
        "id": "yaml_format",
        "entry": "yamlfix",
        "dep": "yamlfix",
        "types": ["yaml"]
    }
]

FORMAT_USAGE = f"""
west format [-h] [src1, src2 ...]

If no source file given, will format all git staged files under the repository
you run this command.
Currently support following file types:

{', '.join([t for c in DEFAULT_CONFIG for t in c["types"]])}
"""


class Format(WestCommand):
    def __init__(self):
        super().__init__(
            "format",  # gets stored as self.name
            "format source code",  # self.help
            "A wrapper to help developer format source code",
            accepts_unknown_args=False,
        )
        self.args = None
        self.formatter_config = None
        self.main_repo_dir = os.path.dirname(
            os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
        )

    def do_add_parser(self, parser_adder):
        parser = parser_adder.add_parser(
            self.name, help=self.help, description=self.description, usage=FORMAT_USAGE
        )

        # TODO Support user defined file type
        # parser.add_argument('-t', '--type',
        #                     help='''Specify the formatter. For most files, we
        #                     can automatically find suitable formatter according
        #                     to the file name or extension name. So only use this
        #                     argument if the auto method not work.
        #                     ''')
        # TODO Support user defined lint template
        # parser.add_argument('-c', '--config',
        #                     help='''Pass in configuration file if the formatter
        #                     need, use pre-commit config template''')
        parser.add_argument(
            "source", metavar="SOURCE", nargs="*", help="source file or dir path to format"
        )

        return parser

    def do_run(self, args, unkonwn_args):
        self.args = args
        self.formatter_config = DEFAULT_CONFIG
        self._setup_environment()

        if self.args.source:
            self.format_source(self.args.source)
        else:
            self.format_git()

    def format_source(self, sources: list[str]) -> None:
        for source in sources:
            if os.path.isfile(source):
                self.format_file(os.path.abspath(source))
            elif os.path.isdir(source):
                folderContent=glob.glob(source+"**/**",recursive=True)
                for path in folderContent:
                    if os.path.isfile(path):
                        self.format_file(os.path.abspath(path))
            else:
                self.err(f"Skip '{source}': not a valid path.")

    def format_git(self):
        mancur_repo_abspath = Path(self.check_output(
            ['git', 'rev-parse', '--show-toplevel'])[:-1].decode('utf-8')).resolve().as_posix()
        diffs = self.check_output(['git', 'diff', '--name-only', '--cached']).decode('utf-8').split()
        for path in diffs:
            self.format_file(os.path.join(mancur_repo_abspath, path))

    def format_file(self, path: str) -> bool:
        if not os.path.exists(path):
            self.err(f"Invalid file path '{path}'")
            return False

        tags = tags_from_path(path)

        find_formatter = False
        for formatter in self.formatter_config:
            if formatter.get("dep") and formatter["dep"] in self.missing_packs:
                continue
            if not tags & frozenset(formatter["types"]):
                continue
            self.banner(f"start format {path}")
            find_formatter = True
            cmd_list = [formatter["entry"]] + formatter.get("args", []) + [path]
            try:
                completed_process = self.run_subprocess(
                    cmd_list, capture_output=True, text=True
                )
            except PermissionError as e:
                self.err(f"Please check whether {path} is opened with another program.")
                break
            if completed_process.returncode != 0:
                self.err(f"{formatter['id']}: {completed_process.stderr}")
            break
        if not find_formatter:
            self.skip_banner(f"Skip {path}")
        return True

    def _setup_environment(self) -> None:
        installed_packs = {p.project_name for p in pkg_resources.working_set}
        self.missing_packs = []

        for c in self.formatter_config:
            if not c.get("dep"):
                continue
            if c["dep"] not in installed_packs:
                self.missing_packs.append(c["dep"])
                skip_types = " ".join(list(c["types"]))
                self.err(
                    f"{c['dep']} is not installed, will skip file with type: '{skip_types}', please "
                    f"run 'pip install -U {c['dep']}'"
                )
        # if not os.path.exists(os.path.join(self.main_repo_dir, '.pre-commit-config.yaml')):
        #     self.die(f"Missing mandatory .pre-commit-config.yaml under {self.main_repo_dir}")

        # completed_process = self.run_subprocess(
        #     ['pre-commit', 'install'],
        #     capture_output=True,
        #     text=True,
        #     cwd=self.main_repo_dir
        # )
        # if completed_process.returncode != 0:
        #     self.die(f"Cannot perform 'pre-commit install': {completed_process.stderr}")

    def skip_banner(self, msg):
        self.inf(f"=== {msg}")
