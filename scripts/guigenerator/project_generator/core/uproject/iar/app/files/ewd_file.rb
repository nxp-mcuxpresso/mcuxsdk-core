# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../internal/iar/files/_ewd_file'


module Iar
module App

    class EwdFile < Internal::Iar::EwdFile

        attr_reader :setupTab
        attr_reader :downloadTab
        attr_reader :multicoreTab
        attr_reader :imagesTab
        attr_reader :extraoptionTab
        attr_reader :debuggercmsisdapTab

        def initialize(*args, **kwargs)
            super
            @operations = DocumentOperations.new(@xml)
            @setupTab = SetupTab.new(@operations)
            @downloadTab = DownloadTab.new(@operations)
            @multicoreTab = MulticoreTab.new(@operations)
            @imagesTab = ImagesTab.new(@operations)
            @extraoptionTab = ExtraOptionTab.new(@operations)
            @debuggercmsisdapTab = DebuggerCmsisDapTab.new(@operations)
        end

        def save(*args, **kwargs) super end
        def targets(*args, **kwargs) super end
        def get_target_name(*args, **kwargs) super end
        def set_target_name(*args, **kwargs) super end

        class SetupTab < SetupTab
            def driver(*args, **kwargs) super end
            def run_to(*args, **kwargs) super end
        end

        class DownloadTab < DownloadTab
            def attach_to_running(*args, **kwargs) super end
            def verify_download(*args, **kwargs) super end
            def suppress_download(*args, **kwargs) super end
            def use_flash_loaders(*args, **kwargs) super end
            def board_file(*args, **kwargs) super end
            def macro_file(*args, **kwargs) super end
        end
        
        class MulticoreTab < MulticoreTab
            def multicore_master_mode(*args) super end
            def slave_workspace(*args) super end
            def slave_project(*args) super end
            def slave_configuration(*args) super end
            def slave_multicore_attach(*args) super end
        end

        class ImagesTab < ImagesTab
            def download_extra_image(*args) super end
            def image_path(*args) super end
            def offset(*args) super end
            def debug_info_only(*args) super end
        end

        class ExtraOptionTab < ExtraOptionTab
            def use_command_line_options(*args) super end
            def set_command_line_options(*args) super end
            def set_debugger_extra_options(*args) super end
        end

        class DebuggerCmsisDapTab < DebuggerCmsisDapTab

            def interface_probeconfig(*args) super end
            def cmsisdap_multicpu_enable(*args) super end
            def cmsisdap_multitarget_enable(*args) super end
            def cmsisdap_resetlist(*args) super end

        end

    end

    class EwdFile_9_32_1 < EwdFile
        def set_project_version(*args, **kargs)
            super
        end
    end

    class EwdFile_9_32_2 < EwdFile_9_32_1
    end

    class EwdFile_9_40_1 < EwdFile_9_32_2
        def initialize(*args, **kwargs)
            super
            @version_map.each {|k,v| @version_map[k] = v+1}
        end
    end
end
end

