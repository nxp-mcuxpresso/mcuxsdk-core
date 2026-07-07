# Copyright 2026 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import subprocess
import textwrap
from pathlib import Path


def test_mcux_add_custom_command_preserves_semicolon_arguments(tmp_path):
    sdk_root = Path(__file__).resolve().parents[2]
    function_cmake = (sdk_root / "cmake" / "extension" / "function.cmake").as_posix()
    source_dir = tmp_path / "source"
    build_dir = tmp_path / "build"
    source_dir.mkdir()

    (source_dir / "CMakeLists.txt").write_text(
        textwrap.dedent(
            f"""
            cmake_minimum_required(VERSION 3.20)
            project(McuxCustomCommandSemicolon NONE)

            function(log_debug)
            endfunction()

            set(CMAKE_BUILD_TYPE release)
            set(CONFIG_TOOLCHAIN iar)
            set(MCUX_SDK_PROJECT_NAME app)
            include("{function_cmake}")

            add_custom_target(app)
            set(CMAKE_OBJCOPY ielftool)
            mcux_add_custom_command(
                TARGETS release
                TOOLCHAINS iar
                BUILD_EVENT POST_BUILD
                BUILD_COMMAND
                    ${{CMAKE_OBJCOPY}} "\\\"--fill=0xFF;0x02000000-0x02055FFF\\\""
                    input.elf
                    output.elf
            )
            """
        ),
        encoding="utf-8",
    )

    subprocess.run(
        ["cmake", "-S", str(source_dir), "-B", str(build_dir), "-G", "Ninja"],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )

    build_ninja = (build_dir / "build.ninja").read_text(encoding="utf-8")

    assert "--fill=0xFF;0x02000000-0x02055FFF" in build_ninja
    assert "--fill=0xFF 0x02000000-0x02055FFF" not in build_ninja