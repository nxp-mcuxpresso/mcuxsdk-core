# frozen_string_literal: true
require_relative './CMSIS_consts'
# ********************************************************************
# Copyright 2018 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

# ####################################################################
# RELEASE CONFIG YML constants
# ####################################################################
#
# ********************************************************************
# Name of output type attribute in release_config.YML ################
RELCFG_OUTPUT_ATTR = 'output'
# Name of input type attribute in release_config.YML ################
RELCFG_INPUT_ATTR = 'input'
# Name of "version" attribute in release_config.YML ################
RELCFG_VERSION_ATTR = 'version'
# The location of the file records environment information for docker.
# See the destination location in Dockerfile.
SDKGEN_DOCKER_ENV_INFO_PATH = '/sdkgen/info.yml'
# Name of 'directory' attribute in release_config.YML. This can be used both in 'output' and 'input' sections
RELCFG_DIRECTORY_ATTR = 'directory'
RELCFG_LOG_ATTR = 'log_path'
# Name of 'type' attribute in release_config.YML. This can be used both in 'output' and 'input' sections
RELCFG_TYPE_ATTR = 'type'
# SDK data version
RELCFG_INPUT_SDK_DATA_VERSION = 'sdk_data_version'
# Default SDK data verion
DEFAULT_SDK_DATA_VERSION = 'v3'
# [String] Newest SDK version version
SDK_NEWEST_VERSION = '2.15.000'
# [String] Default SDK version version
SDK_DEFAULT_VERSION = '2.15.000'
# [String] Latest SDK version which does not need separate exteranl doc zip.
SDK_NO_EXTERNAL_DOC_VERSION = '2.11.0'
# Output types specific in release config, all lowercase
OUTPUT_TYPE_SUPERSET = 'superset'
OUTPUT_TYPE_SUPERSET_TEST = 'superset test'
OUTPUT_TYPE_MANIFEST = 'manifest'
OUTPUT_TYPE_WEBDATA = 'webdata'
OUTPUT_TYPE_DATATABLE = 'datatable'
OUTPUT_TYPE_CMSIS_PACK = 'cmsis pack'
OUTPUT_TYPE_SDK_PACKAGE = 'sdk package zip'
OUTPUT_TYPE_SDK_PACKAGE_RAW = 'sdk package raw'
OUTPUT_TYPE_DOCUMENTATION = 'docs'
OUTPUT_TYPE_DATA_VALIDATION = 'data validation'
# Array of all supported output types
OUTPUT_TYPES = [OUTPUT_TYPE_SUPERSET, OUTPUT_TYPE_MANIFEST, OUTPUT_TYPE_CMSIS_PACK,
                OUTPUT_TYPE_SDK_PACKAGE, OUTPUT_TYPE_SDK_PACKAGE_RAW, OUTPUT_TYPE_DOCUMENTATION, OUTPUT_TYPE_WEBDATA, OUTPUT_TYPE_DATATABLE, OUTPUT_TYPE_DATA_VALIDATION, OUTPUT_TYPE_SUPERSET_TEST].freeze
# Array of outputs need MIR
NEED_MIR_OUTPUT_TYPES = [OUTPUT_TYPE_SUPERSET, OUTPUT_TYPE_MANIFEST, OUTPUT_TYPE_CMSIS_PACK, OUTPUT_TYPE_SDK_PACKAGE,
                         OUTPUT_TYPE_SDK_PACKAGE_RAW, OUTPUT_TYPE_WEBDATA, OUTPUT_TYPE_DATATABLE, OUTPUT_TYPE_SUPERSET_TEST].freeze
# Array of package
OUTPUT_MANIFEST_GENERATED = [OUTPUT_TYPE_SDK_PACKAGE, OUTPUT_TYPE_SDK_PACKAGE_RAW, OUTPUT_TYPE_MANIFEST,
                             OUTPUT_TYPE_SUPERSET, OUTPUT_TYPE_SUPERSET_TEST].freeze
# Array of output types that requre output dir
OUTPUT_DIR_REQUIRED = [OUTPUT_TYPE_SUPERSET, OUTPUT_TYPE_SDK_PACKAGE_RAW, OUTPUT_TYPE_SDK_PACKAGE,
                       OUTPUT_TYPE_CMSIS_PACK, OUTPUT_TYPE_DOCUMENTATION, OUTPUT_TYPE_DATA_VALIDATION, OUTPUT_TYPE_SUPERSET_TEST].freeze
# Array of output types that do not need to set os
OUTPUT_NO_OS = [OUTPUT_TYPE_SUPERSET, OUTPUT_TYPE_DOCUMENTATION, OUTPUT_TYPE_WEBDATA, OUTPUT_TYPE_DATATABLE,
                OUTPUT_TYPE_DATA_VALIDATION, OUTPUT_TYPE_SUPERSET_TEST].freeze
# Array of output types that must specify input type as git repo
OUTPUT_FROM_GIT_REPO = [OUTPUT_TYPE_CMSIS_PACK, OUTPUT_TYPE_DOCUMENTATION, OUTPUT_TYPE_DATA_VALIDATION].freeze
# Array of output types that need web-requires
OUTPUT_WITH_WEB_REQUIRES = [OUTPUT_TYPE_SUPERSET, OUTPUT_TYPE_DATATABLE, OUTPUT_TYPE_WEBDATA,
                            OUTPUT_TYPE_SUPERSET_TEST].freeze
# Input types specific in release config, all lowercase
INPUT_TYPE_GIT_REPO = 'git repo'
INPUT_TYPE_SUPERSET = 'superset'
# The output types that requires manifest to be generated
MANIFEST_REQUIRED_OUTPUT = [OUTPUT_TYPE_MANIFEST, OUTPUT_TYPE_SUPERSET, OUTPUT_TYPE_SDK_PACKAGE,
                            OUTPUT_TYPE_SDK_PACKAGE_RAW, OUTPUT_TYPE_SUPERSET_TEST].freeze
# The output type that supports one mainset to have more than one subset
MULTI_SUBDEVICE_OUTPUT = [OUTPUT_TYPE_SUPERSET, OUTPUT_TYPE_CMSIS_PACK, OUTPUT_TYPE_DOCUMENTATION,
                          OUTPUT_TYPE_SUPERSET_TEST].freeze
# YAML component type: flash algorithm for CMSIS
COMP_TYPE_CMSIS_FLASH_ALG = 'flash_algorithm'

# File extensions to be ignored during EOL conversion
EOL_IGNORED_EXTENSIONS = %w[.0 .1 .2 .5 .6 .7 .16 .a .apk .bin .bmp .cache .cat .cfx .crt
                            .cs .csproj .db .der .dll .doc .docx .dsn .dylib .exe .FLM .gif .ico .img
                            .jar .jpg .js .lib .mex .mp4 .msg .pdf .pmp .png .pyd .rc
                            .rc2 .resx .sb .settings .sh .so .swp .tflite .ui .cfg .go
                            .vpp .vsd .wav .xls .xlsx .zip].freeze

# Files without extensions to be ignored during EOL conversion
EOL_IGNORED_FILES = %w[erpcgen blhost erpcsniffer elftosb elftosb-gui Thread_Shell imgutil
                       imgutil64 Python sdphost DevPartDef].freeze

# File extensions to be converted during EOL conversion
EOL_CONVERT_EXTENSIONS = %w[.3des .bts .BSD .Doxyfile .GPL .INVALID
                            .PNG .S .aes128 .aes192 .aes256
                            .ai .bat .bd .board .c .cbp .cc
                            .cert_type .clang-format .cmake .cmd
                            .cocci .cpp .cproject .csr .css .dni
                            .csv .data .dbgconf .default .des .dot
                            .doxyfile .ds .dsp .dsw .enc .energyblue
                            .eps .erpc .ewd .ewp .eww .example .expected
                            .filters .fmt .function .gdb .git
                            .gitignore .gradle .h .hdr .hex
                            .hhc .hhk .hhp .hpp .htm .html
                            .icf .in .inf .ini .input .java
                            .jlinkscript .JLinkScript .json .key .key_usage
                            .ku-ct .l .launch .layout .ld
                            .ldt .lin .LGPL .log .mac .manifest .map .md .md4
                            .md5 .meta .MINPACK .mk .MPL2 .orig .out .pbxproj
                            .pdsc .pe .pem .pl .prefs .pro
                            .project .properties .psk .pub
                            .pubkey .py .rb .readme .README .rst
                            .rules .s .scf .sct .scss .sha1 .sha224
                            .sha256 .sha384 .sha512 .shtml .sln
                            .srec .svg .tcl .templ .template .terms .test
                            .tm .tmpl .ttf .txt .url .user .uvmpw
                            .uvoptx .uvproj .uvprojx .vcproj
                            .vcxproj .xccheckout .xcworkspacedata
                            .xml .xsd .xxproject .y .yml .include .asm .mem].freeze

# Files without extensions to be converted during EOL conversion
EOL_CONVERT_FILES = %w[COPYING-BSD-3].freeze

# CMSIS related SCR
CMSIS_SCR = %w[cmsis cmsis_gpio]

# Product status
SUCCESS = 0
WARN = 1
ERROR = 2
FATAL = 3
ABORT = 7
UNKNOWN = -100
NOTRUN = -200

# Product type
KEX = 'kex_package'
CMSIS = 'cmsis_pack'
BSP_TYPE = 'BSP'
SBSP_TYPE = 'sBSP'
V3_PRODUCTS = [KEX, CMSIS]

# v3 set folder
V3_SET_DIR = 'bin/generator/records_v3'

# v3 set type
V3_SET_TYPES = %i[board kit device middleware component CMSIS CMSIS_DSP_Lib]

OPEN_CMSIS_SUPPORTED_TOOLCHAINS = %w[iar mdk armgcc]

ADDED_KEX_DEVICE_BOARD_DEPENDENCY_OPTION_ATTRIBUTE = :device_board_dependency

DSP_CORE_TYPES = %w[dsp56800ex dsp56800ef dsp]

ALL_SUPPORTED_OS = %w[linux windows mac]

module SDKGenerator
  VERSION = "3.0.0.dev".freeze
  ENTRY_DIR = __dir__.freeze
  SDKGEN_DIR = File.expand_path("../../", __dir__).freeze
end

# ********************************************************************
# EOF
# ********************************************************************
