# Copyright 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
import multiprocessing
import queue
import os
import subprocess
import concurrent.futures
from identify.identify import tags_from_path

def format_file(formatter_config,skip_packs,file_queue,filesFinished,filesFormated,filesSkipped,filesError,filesCount,mutex):
    while True:
        try:
            path = file_queue.get(timeout=1)
        except  queue.Empty:
            return
        with mutex:
            filesFinished.value += 1#self.fileStatus["Files"]+=1
        if not os.path.exists(path):
            print(f"ERROR: Invalid file path '{path}'")#self.err(f"Invalid file path '{path}'")
            with mutex:
                filesSkipped.value += 1#self.fileStatus["Skipped"]+=1
            return False

        tags = tags_from_path(path)

        find_formatter = False
        for formatter in formatter_config:
            if formatter.get("dep") and formatter["dep"] in skip_packs:
                continue
            if not tags & frozenset(formatter["types"]):
                continue
            print(f"===start format {path} (Finished: {filesFinished.value}/{filesCount})")#self.banner(f"start format {path}")
            find_formatter = True
            cmd_list = [formatter["entry"]] + formatter.get("args", []) + [path]
            try:
                unformated=open(path,'rb').read()
                #completed_process = self.run_subprocess(
                completed_process=subprocess.run(cmd_list, capture_output=True, text=True)
                #)
                firstRun=open(path,'rb').read()
                completed_process=subprocess.run(cmd_list, capture_output=True, text=True)
                #completed_process = self.run_subprocess(
                #    cmd_list, capture_output=True, text=True
                #)
                
                secondRun=open(path,'rb').read()
                if secondRun != firstRun:
                    open(path,'wb').write(unformated)
                    print(f"==Cannot format file {path}. Second format is diferent than first format")
                    with mutex:
                        filesSkipped.value += 1 #self.fileStatus["Skipped"]+=1
                else:
                    with mutex:
                        filesFormated.value += 1#self.fileStatus["Formated"]+=1

            except PermissionError as e:
                print(f"ERROR: Please check whether {path} is opened with another program.")#self.err(f"Please check whether {path} is opened with another program.")
                with mutex:
                    filesError.value += 1#self.fileStatus["Errror"]+=1
                break
            if completed_process.returncode != 0:
                print(f"ERROR: {formatter['id']}: {completed_process.stderr}")
                with mutex:
                    filesError.value += 1#self.fileStatus["Error"]+=1
            break
        if not find_formatter:
            print(f"==Skip {path} (Finished: {filesFinished.value}/{filesCount})")
            with mutex:
                filesSkipped.value += 1 #self.fileStatus["Skipped"]+=1