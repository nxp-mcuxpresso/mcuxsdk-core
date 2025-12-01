# Export App

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
  - Support new option "--bf", this will copy board files to the output directory.
  - User can set "freestanding_copied_folders" in example.yml => example => contents to specify default board copy folders.
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
