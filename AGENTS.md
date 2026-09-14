<!--
Copyright 2026 NXP
SPDX-License-Identifier: BSD-3-Clause
-->

# MCUXpresso SDK core: instructions for AI coding agents

A concise guide for changes to this repository, `mcuxsdk-core`, as checked out in a west workspace. It supplements
`docs/develop/build_system/` (components, configuration, IDE projects), `docs/develop/sdk/` (example, board, device
development) and `docs/gsd/` (workspace setup); documentation wins on conflict. A separate manifest repository assembles
the workspace, and every other repository in it is reviewed independently, so nothing here overrides their conventions.
None of it applies to an SDK archive generated from a workspace: that has no west metadata and a flattened tree.

## The tree is many repositories

west assembles this workspace from dozens of repositories and `mcuxsdk-core` owns only part of it. Resolve ownership
before staging: `git -C <path> rev-parse --show-toplevel`, or `west list`.

- Owned here: `drivers/`, `arch/` (except `arch/arm/CMSIS`), `cmake/`, `scripts/`, `share/`, architecture-level
  `devices/` files, glue for `middleware/{cadence,canopennode,mstp-lib}/`, and root files.
- Elsewhere, each with its own pull request: `examples/`, `components/`, `docs/`, `test/`, `devices/<family>/`, and
  nested projects under `rtos/`, `svd/`, `ecosystem/`, `firmware/` and most of `middleware/`. A workspace may hold
  further projects that this list does not name; resolve a path with the commands above rather than from the list.
- One logical change may span repositories: driver, feature flag, example and test. Use one pull request per repository,
  cross-reference Jira IDs, state dependencies, and do not treat a core-only build as proof for the others.

## Rules for agents

### Agent workflow

- A human must review every change before merge and AI-assisted review comments, code-review feedback and tracker
  comments before posting. State which builds, tests, hardware, toolchains and reproducers were or were not checked;
  never imply unperformed verification.
- Existing code is not automatically a valid template: older files may predate current requirements, static-analysis
  rules or style guidance. Verify copied patterns against current documentation and neighboring code.
- Follow the conventions already used in the directory being modified, including naming for new APIs, types, enums and
  macros. When a convention is unclear, consult current documentation and recent history (`git log --oneline -20 --
  <path>`) before introducing a new pattern.
- Do not flash, reset, run or debug a board (`west flash`, `west debug`) unless asked for that specific action. Hardware
  here may be shared or mid-experiment.
- Every commit carries one `Signed-off-by:` matching the `Author:` name and e-mail (`git commit -s`); never sign off
  for another person or remove an existing sign-off. Record AI involvement with one
  `Assisted-by: <Agent>:<model-version>` trailer, replacing rather than stacking it. No "Generated with ...", session
  links or `Co-authored-by:` for a tool.
- Commit messages, comments, Kconfig help and docs describe the tree as it is, tersely: no prompts, plans, sessions,
  "the rework", "as requested". No emoji.
- Keep changes focused. Leave unrelated refactoring, renames, API reshaping, formatting updates and cleanups out of
  this change; track them separately under their own tracker IDs. Format your own hunks only; a whole-driver reformat
  is its own change with its own Jira ID.

## Build and test

For driver changes, build an example that selects the affected component in a west workspace (`docs/gsd/repo_setup.md`).

- Run discovery commands from this repository's root. Do not guess a board, config or core id: `west list_project -p
  examples/demo_apps/hello_world` prints valid commands (`-t <toolchain>` filters); configs are board-specific.
- For build-affecting changes, ask the human which boards, examples, targets and toolchains to validate; do not invent
  extra builds. Build only that approved scope. If a necessary validation target falls outside it, explain why and ask
  before expanding the scope.
- armgcc alone does not prove a driver change when that scope names other targets. DSC is a 16-bit target without
  `uint64_t`, so widen-then-check overflow guards that pass on Arm fail there; `tool.yml` holds qualified toolchain
  versions.
- Drivers run on real hardware only: there is no host or simulated driver execution here. With no board, say the change
  is unverified.
- Every commit in a series must be self-contained and build successfully on its own. Do not rely on later commits to fix
  build failures introduced earlier; number the series in the subject (`[MCUX-90059][FlexCAN][1/3] ...`).

## Checks to run before pushing

There is no local commit-message or compliance linter — no checkpatch, gitlint or `check_compliance` script. The
formatters and the builds you run are the available local gates.

- `west format` with no arguments formats the *staged* files of the repository containing your cwd; pass paths to format
  specific files. `scripts/formatter_config.yml` declares `clang-format-version: "16.0.0"`, but `west format` does not
  enforce it. Check `clang-format --version` and format only with 16.0.0; if unavailable, do not use another version
  without asking the human.
- Do not reformat third-party or generated code. If the ownership or the generated status of a file is unclear, ask the
  human before formatting it.
- Driver changes are held to MISRA and CERT static-analysis rules; many commits in this tree exist only to fix such
  findings. Running that analysis is the human's step, not yours.
- Stage explicit paths; never `git add -A`, `git add .` or `commit -a`. Before committing, check staged paths with
  `git diff --cached --stat`; before pushing, check the commit with `git show --stat HEAD`.

## Commits and pull requests

    [MCUX-12345][lpuart] Imperative summary, no trailing period

    Body: what the change does, why this approach, which assumptions were
    made and how it was tested. Never empty.

    Assisted-by: Claude:claude-opus-5
    Signed-off-by: Full Name <email@example.com>

- Use `[<JIRA-ID>][<module>] <imperative summary>` for MCUX SDK commit subjects; do not use the Zephyr-style area
  prefix such as `drivers: <ip>:`. Use `git log --format=%s -20 -- <path>` only to match module capitalization. Never
  invent tracker IDs (`MCUX-`, `SDKGEN-`, `MCUCM-`, `ZEP-`); ask the human if none is available.
- One logical change per commit; static-analysis fixes are separate commits that name the checker and rule.
- Keep fixup, squash and merge commits out of final PR history; fold fixes into their owning commit. In Bash:
  `git commit --fixup=<sha>` then `GIT_SEQUENCE_EDITOR=true GIT_EDITOR=true git rebase -i --autosquash <base>`.
  The first setting accepts Git's generated autosquash todo unchanged; the second leaves generated commit messages
  unchanged, so neither editor opens. Update a branch by rebasing on `main`, never by merging `main` into it.
- The remote you push to is not necessarily the URL the manifest lists for this repository; read `git remote -v` rather
  than assuming either one. Reviewers are the maintainers and collaborators of the areas the change touches; ask the
  human who they are. Never push, and never open or update a pull request, unless the human asked for that specific
  action.

## Driver changes

A change to `drivers/<ip>/` must synchronize each component's version in:

1. `fsl_<component>.h` (`FSL_<COMPONENT>_DRIVER_VERSION`);
2. `drivers/<ip>/CMakeLists.txt` (`mcux_component_version()` in that component's `CONFIG_MCUX_COMPONENT` block);
3. `drivers/<ip>/doxygen/ChangeLog_<component>.md` (new version section with applicable change groups).

Version the main driver file and each DMA companion separately (for example, `fsl_lpuart.c` and
`fsl_lpuart_edma.c`); use a patch level for a fix and a minor level for new API or behavior.

Then, in the file itself:

- For silicon differences that affect upper-layer APIs, types, enum items or configuration options, use feature macros
  instead of register or bitmask macros. Gate affected header declarations and corresponding source code with the same
  feature guard. For a new feature, require a defined, nonzero flag; for a legacy feature being removed, exclude it
  only when the flag is explicitly zero (old SoC headers may omit it):
  ```c
  #if defined(FSL_FEATURE_FOO_HAS_BAR) && (FSL_FEATURE_FOO_HAS_BAR != 0)
  /* Newly added BAR feature code */
  #endif
  #if !(defined(FSL_FEATURE_FOO_HAS_BAR) && (FSL_FEATURE_FOO_HAS_BAR == 0))
  /* Legacy BAR feature code */
  #endif
  ```
  Feature flags live in
  `devices/<portfolio>/<series>/<device>/<device>_features.h`; a new flag needs a device-repository pull request.
- Differences confined to function implementation, with no upper-layer impact, need no new feature macro. If register
  presence distinguishes the hardware, register macros may be used there. Follow the
  [feature-macro coding rules](https://confluence.sw.nxp.com/pages/viewpage.action?pageId=69374165).
- No unbounded `while` waiting on a hardware flag: give it a timeout and report timeout failures. Verify the timeout
  survives the slowest expected clock, not just the default.
- Match the surrounding file for API naming (`LPUART_Init`, `lpuart_config_t`, `kLPUART_TxIdle`, `s_lpuartBases`),
  Doxygen depth, `FSL_COMPONENT_ID` and comment style.

## Kconfig and CMake components

A component has sources, `Kconfig` and `CMakeLists.txt`. Drivers self-register; a new middleware directory needs
`mcux_add_cmakelists(... OPTIONAL)` in the root `CMakeLists.txt` and an `osource` in `Kconfig.mcuxpresso`. Do not mix
these symbol families:

- `MCUX_HW_IP_DriverType_<IP>` — set by the device repository in its `Kconfig.chip`; the SoC has the IP.
- `MCUX_HAS_COMPONENT_driver.<name>` — availability, no prompt, `default y if` the hardware and any prerequisite
  `MCUX_HAS_COMPONENT_` symbols.
- `MCUX_COMPONENT_driver.<name>` — the selectable component: a prompt string, `select` for what it pulls in,
  `depends on MCUX_HAS_COMPONENT_driver.<name>`.

CMake and C see these with a `CONFIG_` prefix, and every referenced `CONFIG_` symbol must be defined somewhere in the
tree. Guard each component with `if(CONFIG_MCUX_COMPONENT_driver.<name>)` and use the `mcux_*` API (`mcux_add_source`,
`mcux_add_include`, `mcux_add_macro`, `mcux_add_configuration`, `mcux_component_version`, the per-toolchain
`mcux_add_<tc>_*`) rather than raw `target_*` commands; `cmake/extension/function.cmake` defines them and
`docs/develop/build_system/Software_Componentization.md` explains the model. Preset values come from `prj.conf` merged
across device, board, shield and example.

## Copyright headers

- New original files start with two lines in the file's comment syntax: `Copyright <current year> NXP`, then
  `SPDX-License-Identifier: BSD-3-Clause` (the top of this file shows the Markdown form). No `(c)`, no "All rights
  reserved." Do not copy a year from a reference file.
- Modifying a pre-existing file: leave its header style alone and only extend the NXP year. Legacy
  `Copyright (c) ... Freescale Semiconductor, Inc.` and `All rights reserved.` lines stay, and year-list spelling varies
  between files (`2016-2022, 2025-2026`, `2019-2021,2025-2026`) — follow the file. Edit the year by hand in the files
  you are changing; never run a tree-wide header rewrite.
