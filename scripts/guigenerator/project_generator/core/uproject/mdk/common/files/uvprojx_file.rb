# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../internal/mdk/files/_uvprojx_file'


module Mdk
module Common

    class UvprojxFile < Internal::Mdk::UvprojxFile

        attr_reader :deviceTab
        attr_reader :targetTab
        attr_reader :outputTab
        attr_reader :listingTab
        attr_reader :userTab
        attr_reader :compilerTab
        attr_reader :assemblerTab
        attr_reader :linkerTab
        attr_reader :propertiesTab

        def initialize(*args, **kwargs)
            super(*args, **kwargs)
        # create shared "operations" instance
            @operations = DocumentOperations.new(@xml, logger: @logger)
        # create tab instances
            @deviceTab = DeviceTab.new(@operations)
            @targetTab = TargetTab.new(@operations)
            @outputTab = OutputTab.new(@operations)
            @listingTab = ListingTab.new(@operations)
            @userTab = UserTab.new(@operations)
            @propertiesTab = PropertiesTab.new(@operations)
        end

        def save(*args, **kargs) super end
        def add_source(*args, **kargs) super end
        def set_source_alwaysBuild(*args, **kargs) super end
        def clear_sources!(*args, **kargs) super end
        def clear_flashDriver!(*args, **kargs) super end
        def get_target_name(*args, **kwargs) super end
        def set_target_name(*args, **kwargs) super end
        def targets(*args, **kargs) super end
        def clear_unused_targets!(*args, **kargs) super end
        def project_name(*args, **kargs) super end
        def enable_batchbuild(*args, **kargs) super end
        def set_compiler_assembler(*args) super end
        def add_rte_component(*args) super end

        class DeviceTab < DeviceTab
            def device(*args, **kargs) super end
            def vendor(*args, **kargs) super end
            def cpu_type(*args, **kargs) super end
            def set_cpu_fpu(*args, **kargs) super end
        end

        class TargetTab < TargetTab
            def big_endian(*args, **kargs) super end
            def secure(*args, **kargs) super end
        end

        class OutputTab < OutputTab
            def browse_info(*args, **kargs) super end
            def debug_info(*args, **kargs) super end
            def executable_name(*args, **kargs) super end
            def folder(*args, **kargs) super end
            def create_executable(*args, **kargs) super end
            def create_library(*args, **kargs) super end
            def browse_info(*args, **kargs) super end
            def create_hex_file(*args, **kargs) super end
        end

        class ListingTab < ListingTab
            def folder(*args, **kargs) super end
            def assembler_listing(*args, **kargs) super end
            def assembler_cross_reference(*args, **kargs) super end
            def compiler_listing(*args, **kargs) super end
            def preprocessor_listing(*args, **kargs) super end
            def linker_listing(*args, **kargs) super end
            def linker_memory_map(*args, **kargs) super end
            def linker_callgraph(*args, **kargs) super end
            def linker_symbols(*args, **kargs) super end
            def linker_cross_reference(*args, **kargs) super end
            def linker_size_info(*args, **kargs) super end
            def linker_total_info(*args, **kargs) super end
            def linker_unused_sections(*args, **kargs) super end
            def linker_veneers_info(*args, **kargs) super end
        end

        class UserTab < UserTab
            def before_compilation_run_1(*args, **kargs) super end
            def before_compilation_command_1(*args, **kargs) super end
            def before_compilation_dos_1(*args, **kargs) super end
            def before_compilation_run_2(*args, **kargs) super end
            def before_compilation_command_2(*args, **kargs) super end
            def before_compilation_dos_2(*args, **kargs) super end
            def before_make_run_1(*args, **kargs) super end
            def before_make_command_1(*args, **kargs) super end
            def before_make_dos_1(*args, **kargs) super end
            def before_make_run_2(*args, **kargs) super end
            def before_make_command_2(*args, **kargs) super end
            def before_make_dos_2(*args, **kargs) super end
            def after_make_run_1(*args, **kargs) super end
            def after_make_command_1(*args, **kargs) super end
            def after_make_dos_1(*args, **kargs) super end
            def after_make_run_2(*args, **kargs) super end
            def after_make_command_2(*args, **kargs) super end
            def after_make_dos_2(*args, **kargs) super end
            def before_compile_run_1(*args, **kargs) super end
            def before_compile_command_1(*args, **kargs) super end
            def before_compile_run_2(*args, **kargs) super end
            def before_compile_command_2(*args, **kargs) super end
        end

        class CompilerTab < CompilerTab
            def interworking(*args, **kargs) super end
            def add_define(*args, **kargs) super end
            def clear_defines!(*args, **kargs) super end
            def optimization(*args, **kargs) super end
            def optimize_for_time(*args, **kargs) super end
            def split_load_store_multiple(*args, **kargs) super end
            def one_elf_section_per_function(*args, **kargs) super end
            def strict_ansi(*args, **kargs) super end
            def enum_is_always_int(*args, **kargs) super end
            def plain_char_is_signed(*args, **kargs) super end
            def no_auto_includes(*args, **kargs) super end
            def warnings(*args, **kargs) super end
            def c99_mode(*args, **kargs) super end
            def all_mode(*args, **kargs) super end
            def add_include(*args, **kargs) super end
            def clear_include!(*args, **kargs) super end
            def add_misc_control(*args, **kargs) super end
            def clear_misc_controls!(*args, **kargs) super end
            def add_misc_flag(*args, **kargs) super end
            def turn_warnings_into_errors(*args, **kargs) super end
            def clear_misc_flags!(*args, **kargs) super end
            def add_misc_sysinclude(*args, **kargs) super end
            def clear_misc_sysinclude!(*args, **kargs) super end
            def lto(*args, **kargs) super end
            def ro_independent(*args, **kargs) super end
            def rw_independent(*args, **kargs) super end
            def short_enums_wchar(*args, **kargs) super end
            def use_rtti(*args, **kargs) super end
            def all_mode_cpp(*args, **kargs) super end
        end

        class AssemblerTab < AssemblerTab
            def interworking(*args, **kargs) super end
            def add_define(*args, **kargs) super end
            def clear_defines!(*args, **kargs) super end
            def thumb(*args, **kargs) super end
            def no_warnings(*args, **kargs) super end
            def split_load_store_multiple(*args, **kargs) super end
            def no_auto_includes(*args, **kargs) super end
            def add_include(*args, **kargs) super end
            def clear_include!(*args, **kargs) super end
            def add_misc_control(*args, **kargs) super end
            def clear_misc_controls!(*args, **kargs) super end
            def add_misc_flag(*args, **kargs) super end
            def clear_misc_flags!(*args, **kargs) super end
            def add_cpreproc_define(*args, **kargs) super end
            def clear_cpreproc_defines!(*args, **kargs) super end
            def ro_independent(*args, **kargs) super end
            def rw_independent(*args, **kargs) super end
        end

        class LinkerTab < LinkerTab
            def use_memory_layout_from_dialog(*args, **kargs) super end
            def dont_search_standard_lib(*args, **kargs) super end
            def report_might_fail(*args, **kargs) super end
            def add_disable_warning(*args, **kargs) super end
            def clear_disable_warnings!(*args, **kargs) super end
            def scatter_file(*args, **kargs) super end
            def add_misc_control(*args, **kargs) super end
            def clear_misc_controls!(*args, **kargs) super end
            def add_misc_flag(*args, **kargs) super end
            def clear_misc_flags!(*args, **kargs) super end
            def add_library(*args, **kargs) super end
            def clear_libraries!(*args, **kargs) super end
        end

        class PropertiesTab < PropertiesTab
            def exclude_building(*args, **kargs) super end
        end
    end
end
end

