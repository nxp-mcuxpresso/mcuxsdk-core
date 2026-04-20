# MCUXpresso SDK Build Dashboard

`dashboard.py` processes an MCUXpresso SDK build directory and generates a
self-contained, multi-page HTML dashboard that consolidates build
information, memory usage, Kconfig configuration, and ELF section
statistics into a single browsable report.

This tool is an MCUXpresso SDK port of the Zephyr dashboard tool. The
Zephyr device-tree and sys-init pages have no analogue in the SDK build
flow and are omitted here.

## Dashboard Pages

| Page | Description |
|------|-------------|
| **Build Summary** | Board name, application path, build command, SDK version, toolchain, ELF/binary sizes, and a high-level memory breakdown (text, rodata, rwdata, bss) |
| **Memory Report** | Hierarchical tree view of RAM, ROM, and combined memory usage by symbol, with Plotly sunburst charts and a top-10 largest symbols table |
| **Kconfig** | Searchable table of all Kconfig symbols showing their value, type, source (default / assigned / selected / implied), and the file/line where the value originates |
| **ELF Stats** | `objdump`-style section header listing generated from the application ELF |

## How It Works

1. **Build metadata** — Metadata (board, application source directory,
   build command, workspace top directory) is passed on the command line
   by the CMake target; no `build_info.yml` is required.

2. **ELF parsing** — The application `.elf` is parsed with `pyelftools`
   to produce a high-level memory summary (text, rodata, rwdata, bss,
   other) and an on-the-fly ELF section table for the ELF Stats page.

3. **Kconfig trace** — `.config-trace.pickle` (already produced by the
   mcuxsdk `traceconfig` CMake module) is loaded and converted into
   `KconfigSymbol` objects that carry the symbol name, value, type, and
   the source that set the value.

4. **Memory reports** — If the output directory does not already contain
   up-to-date `ram_report.json` and `rom_report.json`, the script invokes
   `scripts/footprint/size_report` to generate them. A combined
   `all_report.json` is synthesized on the Python side by wrapping the
   two trees under a "Root → ROM / RAM" node; each leaf symbol is tagged
   with its location so the Top Ten list can show whether a symbol lives
   in RAM or ROM. This step can be skipped with `--skip-memory-report`
   for faster iteration.

5. **HTML rendering** — Jinja2 templates in `templates/` are rendered
   with the collected data and written to the output directory. Static
   assets (Bootstrap, custom CSS/JS, icon font, NXP logo) are copied
   from `static/` into the output.

## Directory Structure

```
scripts/dashboard/
├── dashboard.py        # Main script
├── icons.json          # Fontello configuration for the custom icon font
├── static/...          # Static assets copied into every generated dashboard
└── templates/...       # Jinja2 HTML templates
```

## Usage

The primary entry point is the `dashboard` CMake target, which matches
the Zephyr invocation:

```bash
west build -t dashboard
```

The target is defined in `cmake/extension/reports/CMakeLists.txt` and
automatically passes the board, application source directory, and
workspace top directory based on the current build.

You can also invoke the script directly:

```
python scripts/dashboard/dashboard.py [<build_dir>] [options]
```

| Argument | Description |
|----------|-------------|
| `build_dir` | Path to the mcuxsdk build directory (default: `build/`) |
| `--output <dir>` | Output directory for the generated HTML (default: `<build>/dashboard`) |
| `--sdk-base <dir>` | MCUXpresso SDK base directory (default: current directory) |
| `--bin-name <name>` | Application binary name without extension (required) |
| `--board <name>` | Target board name, shown on the Build Summary page |
| `--app-source-dir <path>` | Application source directory, shown on the Build Summary page |
| `--topdir <path>` | West workspace top directory (default: `--sdk-base`) |
| `--command <text>` | Original build command string, shown on the Build Summary page |
| `--skip-memory-report` | Skip the memory report generation step for faster output |
| `--no-clean` | Keep temporary `{ram,rom,all}_report.json` files in the output directory |
| `-v`, `--verbose` | Print extra debugging information |
| `-q`, `--quiet` | Suppress all console output |
| `--open` | Open the generated dashboard in the default web browser when done |

**Example:**

```bash
python scripts/dashboard/dashboard.py build \
    --sdk-base . \
    --bin-name pcal6524_interrupt_demo_cm7 \
    --board imx95lpd5evk19 \
    --open
```

## Python Dependencies

| Package | Purpose |
|---------|---------|
| `jinja2` | HTML template rendering |
| `pyelftools` | ELF file parsing |
| `pygments` | Syntax highlighting (pygments CSS for text viewer) |
| `plotly` *(optional)* | Sunburst memory charts; without it the Memory Report still renders as trees |

Install required packages:

```bash
pip install jinja2 pyelftools pygments
# Optional, for memory charts:
pip install plotly
```

## Notes on `size_report` Integration

The mcuxsdk `scripts/footprint/size_report` tool accepts a single target
(`rom`, `ram`, or `all`) per invocation and uses `--json` as a literal
output path. When invoked with target `all` together with `--json`, it
internally loops over rom then ram but writes both to the same path,
leaving only the second result on disk. The dashboard works around this
by invoking `size_report` twice — once for `rom`, once for `ram` — and
synthesizing the combined tree on the Python side.

## Bootstrap & Icons

Bootstrap CSS/JS are trimmed copies (`bootstrap-chop.css`,
`bootstrap-chop.js`) so the generated dashboard works fully offline at
a reasonable size. Icons come from a size-optimized
[Bootstrap Icons](https://icons.getbootstrap.com/) bundle built with
[fontello.com](https://fontello.com); the `icons.json` at the root of
this directory is the fontello project configuration. See the Zephyr
dashboard README for the full procedure to regenerate
`bootstrap-chop.css` via PurgeCSS or to add new icons via fontello.

## License

Copyright 2026 NXP
Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.

SPDX-License-Identifier: Apache-2.0
