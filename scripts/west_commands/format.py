# Copyright 2024-2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import os
import pkg_resources
import glob
import yaml
import subprocess
import re
import signal
from pathlib import Path
from west.commands import WestCommand
import concurrent.futures 
import multiprocessing
import queue
try:
    from identify.identify import tags_from_path
except ImportError:
    print("Please run 'pip install -U identify'")
    exit(1)

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
        "getVersion":["clang","--version"],
        "versionRegex":r'clang version ((\d|\.)*).*$'
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

If no source is given, script will format all git stage area of the current repository.
you run this command.
Currently supports the following file types:

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
        # Shared variable for signaling interruption
        self.stop_event = None

    def do_add_parser(self, parser_adder):
        parser = parser_adder.add_parser(
            self.name, help=self.help, description=self.description, usage=FORMAT_USAGE
        )
        #TODO specify which file types to format
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
        parser.add_argument("--numberThreads", "-t", type=int, default=4, help="Number of parallel jobs to run (default: 4)")

        return parser

    def do_run(self, args, unkonwn_args):
        self.args = args
        self.formatter_config = DEFAULT_CONFIG
        self._setup_environment()
        self.fileStatus={"Files":0,"Formated":0,"Skipped":0,"Error":0}
        filesList=[]
        
        # Create a multiprocessing event for signaling interruption
        manager = multiprocessing.Manager()
        self.stop_event = manager.Event()
        
        # Set up signal handler for Ctrl+C
        original_sigint_handler = signal.getsignal(signal.SIGINT)
        
        def handle_interrupt(sig, frame):
            print("\nReceived interrupt signal. Stopping formatting process gracefully...")
            self.stop_event.set()
            # If pressed again, use the original handler
            signal.signal(signal.SIGINT, original_sigint_handler)
        
        signal.signal(signal.SIGINT, handle_interrupt)
        
        try:
            if self.args.source:
                filesList=self.get_files_from_dir(self.args.source)
            else:
                filesList=self.get_files_from_git()
            
            # Use a regular queue instead of multiprocessing Queue for better interrupt handling
            file_queue = manager.Queue()
            for file in filesList:
                file_queue.put(file)
            
            # Start worker threads
            with concurrent.futures.ThreadPoolExecutor(max_workers=args.numberThreads) as executor:
                futures = []
                for _ in range(min(args.numberThreads, len(filesList) or 1)):
                    futures.append(executor.submit(self.format_file, file_queue))
                
                # Wait for completion or interruption
                while futures and not self.stop_event.is_set():
                    # Check if any futures are done
                    done, not_done = concurrent.futures.wait(
                        futures, timeout=0.5, 
                        return_when=concurrent.futures.FIRST_COMPLETED
                    )
                    
                    # Remove completed futures
                    for future in done:
                        futures.remove(future)
                        # Handle any exceptions
                        try:
                            future.result()
                        except Exception as e:
                            self.err(f"Error in worker thread: {e}")
                
                # If interrupted, cancel remaining futures
                if self.stop_event.is_set():
                    for future in futures:
                        future.cancel()
            
            if self.stop_event.is_set():
                print("\nFormatting process was interrupted.")
            
            print("\nSummary:")
            for key, value in self.fileStatus.items():
                print(f"{key}: {value}")
                
        finally:
            # Restore original signal handler
            signal.signal(signal.SIGINT, original_sigint_handler)
            # Clean up manager
            manager.shutdown()

    def get_files_from_dir(self, sources: list[str]) -> list[Path]:
        filesList=[]
        for source in sources:
            if not os.path.exists(source) and os.path.exists(source[1:]):
                source=source[1:]
            if source==".":
                source=os.getcwd()
            if os.path.isfile(source):
                filesList.append(source)
            elif os.path.isdir(source):
                folderContent=glob.glob(source+"**/**",recursive=True)
                for path in folderContent:
                    if os.path.isfile(path):
                        filesList.append(path)
            else:
                self.err(f"Skip '{source}': not a valid path.")
        return filesList
    
    def get_files_from_git(self):
        mancur_repo_abspath = Path(self.check_output(
            ['git', 'rev-parse', '--show-toplevel'])[:-1].decode('utf-8')).resolve().as_posix()
        diffs = self.check_output(['git', 'diff', '--name-only', '--cached']).decode('utf-8').split()
        filesList=[]
        for path in diffs:
            filesList.append(os.path.join(mancur_repo_abspath, path))
        return filesList

    def format_file(self, file_queue):
        while not self.stop_event.is_set():
            try:
                # Use a timeout to periodically check for stop event
                path = file_queue.get(timeout=0.5)
            except queue.Empty:
                # Queue is empty, exit the thread
                return
                
            if self.stop_event.is_set():
                return
                
            self.fileStatus["Files"]+=1
            if not os.path.exists(path):
                self.err(f"Invalid file path '{path}'")
                self.fileStatus["Skipped"]+=1
                continue

            tags = tags_from_path(path)

            find_formatter = False
            for formatter in self.formatter_config:
                if self.stop_event.is_set():
                    return
                    
                if formatter.get("dep") and formatter["dep"] in self.missing_packs:
                    continue
                if not tags & frozenset(formatter["types"]):
                    continue
                self.banner(f"start format {path}")
                find_formatter = True
                cmd_list = [formatter["entry"]] + formatter.get("args", []) + [path]
                try:
                    unformated=secondRun=open(path,'rb').read()
                    completed_process = self.run_subprocess(
                        cmd_list, capture_output=True, text=True
                    )
                    firstRun=open(path,'rb').read()
                    completed_process = self.run_subprocess(
                        cmd_list, capture_output=True, text=True
                    )
                    secondRun=open(path,'rb').read()
                    if secondRun != firstRun:
                        open(path,'wb').write(unformated)
                        self.skip_banner(f"Cannot format file {path}. Second format is diferent than first format")
                        self.fileStatus["Skipped"]+=1
                    else:
                        self.fileStatus["Formated"]+=1

                except PermissionError as e:
                    self.err(f"Please check whether {path} is opened with another program.")
                    self.fileStatus["Error"]+=1
                    break
                if completed_process.returncode != 0:
                    self.err(f"{formatter['id']}: {completed_process.stderr}")
                    self.fileStatus["Error"]+=1
                break
            if not find_formatter:
                self.skip_banner(f"Skip {path}")
                self.fileStatus["Skipped"]+=1

    def _setup_environment(self) -> None:
        installed_packs = {p.project_name for p in pkg_resources.working_set}
        self.missing_packs = []
        configPath=Path(__file__).parent.absolute().parent.absolute()
        configPath=configPath / "formatter_config.yml"
        if configPath.exists():
            with open(configPath,'r') as file:
                self.formatconfig=yaml.safe_load(file)
        else:
            self.err(f"Config file in {str(configPath)} does not exist")
            exit(1)
        for c in self.formatter_config:
            if not c.get("dep"):
                continue
            if c["dep"] not in installed_packs and "getVersion" not in c.keys():
                self.missing_packs.append(c["dep"])
                skip_types = " ".join(list(c["types"]))
                self.err(
                    f"{c['dep']} is not installed, will skip file with type: '{skip_types}', please "
                    f"run 'pip install -U {c['dep']}'"
                )
            if "getVersion" in c.keys() and f"{c['id']}-version"in self.formatconfig:
                versionCmdOutput=subprocess.check_output(c["getVersion"],text=True)
                versionObject=re.match(c["versionRegex"],versionCmdOutput,re.MULTILINE)
                if versionObject is not None:
                    version=versionObject.group(1)
                    if not version==self.formatconfig[f"{c['id']}-version"]:
                        skip_types = " ".join(list(c["types"]))
                        self.err(f"{c['id']} version ({version}) doesnt match the expected version ({self.formatconfig[c['id']+'-version']}), will skip file with type: '{skip_types}")

                else:
                    skip_types = " ".join(list(c["types"]))
                    self.err(f"Couldnt check version of {c['id']}, will skip file with type: '{skip_types}")
                
    def skip_banner(self, msg):
        self.inf(f"=== {msg}")
