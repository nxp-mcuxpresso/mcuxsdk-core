# Export App

## [26.06.00]

- Bug Fixes
  - Add selector-based workaround policy matching for example, board, and core, and log matched policies during trace app init.
  - Fix `board_files.cmake` include order: adjust insertion index by `prepend_content` offset so board includes come after SDK includes, preserving correct header search order.

- New Features
  - Support `mcux_add_library`: stage prebuilt libraries (`.a` / `.lib`) referenced via `LIBS` into the freestanding tree alongside sources and headers.
  - Filter `mcux_add_source` / `mcux_add_include` / `mcux_add_library` / `mcux_project_remove_source` trace calls by `CORES` / `CORE_IDS` / `BOARDS` / `DEVICE_IDS` against the current build's `CONFIG_MCUX_HW_*` values read from `build_tmp/.config`, mirroring the runtime AND IN_LIST early-return in `cmake/extension/function.cmake`. Calls whose condition list excludes the current build are dropped at trace time so per-device/per-board files and libraries are not over-copied.
  - Add `contents.freestanding_extra_args` in `example.yml`: a list of cmake args (e.g. `-DCONFIG_X=y`, `-DCONFIG_Y=n`) applied to the export_app trace cmake invocation.
  - Add `--copy-all-linker-files` option to copy all linker file variants (ram/flash/ddr) from the cmake trace into a `linker_files/` subdirectory. Also configurable via `west config export_app.copy_all_linker_files true`.

- Improvements
  - Support CMake 4.3+'s new trace output format, see <https://cmake.org/cmake/help/latest/release/4.3.html#other-changes>
  - If output dir contains space, wrap the output dir and build dir with double quotes in console log.

## [26.03.00]

- New Features
  - Support copy example readme.md to output directory. If using `--bf`, it will automatically merge the copied board readme file.

## [25.12.00]

- New Features
  - If user input board/core variable, the extension will run a cmake configuration step to get accurate cmake trace result. This may use more time to finish the export process, but it would be more accurate.
  - Support `include`, `mcux_project_remove_source`, `mcux_add_xxx_linker_script` commands.
  - Add option `--debug` to enable debug log output.

- Improvements
  - Refactor the cmake trace logic to support more complex sdk examples.
  - Improve output structure.
  - Normalize Windows drive case in path.

## [25.09.00]

- New Features
  - Support new option `--bf`, this will copy board files to the output directory.
  - User can set `freestanding_copied_folders` in example.yml => example => contents to append board copy folders.
  - Support set output_dir and clean_output_dir in west config file.

- Improvements
  - Make build command an instance function of CMakeApp.

## [25.06.00]

- New Features
  - Support export common app without board/core variable.
  - Support dsp examples which include another sysbuild.cmake in example root's one.
  - Support export custom_application with custom CONF_FILE.
  - Use Jinja2 to format generated cmake file (The original used cmake-format may cause build issues as it will remove all redundant spaces).

- Improvements
  - Drop the usage of PrjRootDirPath. Now the extension will directly copy all example sources to the given output directory for non-sysbuild application. For sysbuild ones, the extension will create sub directories for each one in the output directory.
  - Refactor the extension, split application parser to seperated library.
  - Update the path process logic now it can cover all SDK examples.

- Bug Fixes
  - Fixed failured builds case by case.

## [25.03.00]

- The initial version.
