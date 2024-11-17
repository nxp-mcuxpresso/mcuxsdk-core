# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import os

from example_list import ExampleList

os.environ["SdkRootDirPath"] = "E:/sdk_next/mcu-sdk-3.0"
os.environ["board"] = "frdmk64f"
os.environ["core_id"] = ""
os.environ["example_name"] = "freertos_hello"
os.environ["toolchain"] = "armgcc"

example_list = ExampleList()
example_list.get_example_list()