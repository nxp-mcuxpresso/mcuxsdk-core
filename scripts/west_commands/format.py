# Copyright 2024-2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import os
import pkg_resources
import glob
import yaml
import subprocess
import re
from pathlib import Path
from west.commands import WestCommand
import multiprocessing
import format_mp
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
        parser.add_argument("--timeout", type=int, default=60, help="Timeout for each formatting run in seconds(default: 60)")
        parser.add_argument("--numberThreads", "-t", type=int, default=4, help="Number of parallel jobs to run (default: 4)")
        parser.add_argument('-f', '--formatTypes',help='''Specify file types to format.Provide a comma-separated list of file types (e.g., "cpp,python,yaml,all"").(default:all supported filetypes)''')


        return parser

    def do_run(self, args, unkonwn_args):
        format_types=[]
        if args.formatTypes:
            if not args.formatTypes.lower() == 'all':
                format_types = args.formatTypes.split(',')
            format_types = args.formatTypes.split(',')
        self.args = args
        self.formatter_config = DEFAULT_CONFIG
        self._setup_environment()
        #self.fileStatus={"Files":0,"Formated":0,"Skipped":0,"Error":0}
        filesList=[]
        if self.args.source:
            filesList=self.get_files_from_dir(self.args.source)
        else:
            filesList=self.get_files_from_git()
        manager=multiprocessing.Manager()
        mutex=manager.Lock()
        filesFinished=multiprocessing.Value('i',0)
        filesFormated=multiprocessing.Value('i',0)
        filesSkipped=multiprocessing.Value('i',0)
        filesError=multiprocessing.Value('i',0)
        filesTimeout=multiprocessing.Value('i',0)
        filesCount=len(filesList)
        file_queue=manager.Queue()
        for file in filesList:
            file_queue.put(file)
        #with concurrent.futures.ProcessPoolExecutor(max_workers=args.numberThreads) as pool:
        #    futures = [pool.submit(format_mp.format_file,self.formatter_config,self.missing_packs,file_queue,filesFinished,filesFormated,filesSkipped,filesError,filesCount,mutex) for i in range(args.numberThreads)]
        #result=concurrent.futures.as_completed(futures)    
        processes=[]
        for i in range(args.numberThreads):
            processes.append(multiprocessing.Process(target=format_mp.format_file, args=(self.formatter_config,self.missing_packs,file_queue,filesFinished,filesFormated,filesSkipped,filesError,filesTimeout,filesCount,format_types,mutex,args.timeout,)))
            processes[i].start()
        for proces in processes:
            proces.join()
        #for key,value in self.fileStatus.items():
        #   print(f"{key}: {value}")
        print(f"Total Files: {filesCount}")
        print(f"Finished Files: {filesFinished.value}")
        print(f"Formatted Files: {filesFormated.value}")
        print(f"Skipped Files: {filesSkipped.value}")
        print(f"Error Files: {filesError.value}")
        print(f"Timeout Files: {filesTimeout.value}")
        

    def get_files_from_dir(self, sources: list[str]) -> list[Path]:
        filesList=[]
        for source in sources:
            if not os.path.exists(source) and os.path.exists(source[1:]):
                source=source[1:]
            if source==".":
                source=os.getcwd()
            if os.path.isfile(source):
                filesList.append(source)#self.format_file(os.path.abspath(source))
            elif os.path.isdir(source):
                folderContent=glob.glob(source+"**/**",recursive=True)
                for path in folderContent:
                    if os.path.isfile(path):
                        filesList.append(path)
                        #self.format_file(os.path.abspath(path))
            else:
                self.err(f"Skip '{source}': not a valid path.")
        return filesList
    
    def get_files_from_git(self):
        mancur_repo_abspath = Path(self.check_output(
            ['git', 'rev-parse', '--show-toplevel'])[:-1].decode('utf-8')).resolve().as_posix()
        diffs = self.check_output(['git', 'diff', '--name-only', '--cached']).decode('utf-8').split()
        filesList=[]
        for path in diffs:
            filesList.append(os.path.join(mancur_repo_abspath, path))#self.format_file(os.path.join(mancur_repo_abspath, path))
        return filesList

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
