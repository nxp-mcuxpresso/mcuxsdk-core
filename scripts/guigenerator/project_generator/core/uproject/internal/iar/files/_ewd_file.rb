# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../internal/_xml_utils'
require_relative '../../../../../../utils/_assert'
require 'nokogiri'
require 'logger'


module Internal
module Iar


    class EwdFile

        attr_reader :xml
        attr_reader :logger
        attr_reader :operations

        def initialize(template, *args, logger: nil, **kwargs)
            @xml    = XmlUtils.load(template)
            @logger = logger ? logger : Logger.new(STDOUT)
            @version_map = {
              "/project/fileVersion" => 3,
              "./settings[name=\"C-SPY\"]/data/version" => 32,
            }
        end

        private

        def save(path, *args, **kwargs)
            Core.assert(path.is_a?(String) && !path.empty?) do
                "param must be non-empty string"
            end
            @logger.debug("generate file: #{path}")
            XmlUtils::save(@xml, path)
        end

        def targets(*args, **kwargs)
            return @operations.targets
        end

        def get_target_name(target, *args, **kwargs)
            return @operations.get_target_name(target)
        end

        def set_target_name(target, value, *args, **kwargs)
            return @operations.set_target_name(target, value)
        end

        def clear_unused_targets!(*args, **kwargs)
            @operations.clear_unused_targets!()
        end

        def set_project_version(target, version, *args, **kargs)
            @version_map.each do |path, value|
                if path == '/project/fileVersion'
                    @operations.set_node_value("/project/fileVersion", value)
                else
                    @operations.set_state_node(target, path, value, used: true)
                end
            end
        end

        private

        class DocumentOperations

            attr_reader :xml
            attr_reader :targets

            def initialize(xml, *args, **kwargs)
                @xml, @targets = xml, {}
                nodes = @xml.xpath('project/configuration')
                nodes.each do | target_node |
                    name_node = target_node.at_xpath("name")
                    Core.assert(!name_node.nil?) do
                        "missing '<name>' node"
                    end
                    target = name_node.content.strip.downcase
                    name_node.content = target
                    @targets[ target ] = { 'node'  => target_node, 'used'  => false }
                end
            end

            # return target node
            def target_node(target, *args, **kwargs)
                Core.assert(target.is_a?(String) && !target.empty?) do
                    "param must be non-empty string"
                end
                target = target.strip.downcase
                Core.assert(@targets.has_key?(target)) do
                    "target '#{target}' is not present. use one of: #{@targets.keys} "
                end
                Core.assert(!@targets[ target ][ 'node' ].nil?) do
                    "name '#{target}' does not exist"
                end
                @targets[ target ][ 'used' ] = true
                return @targets[ target ][ 'node' ]
            end

            # remove all unused targets by 'used' flags
            def clear_unused_targets!(*args, **kwargs)
                @targets.each do | target_key, target_item |
                    if (target_item[ 'used' ] == false)
                        target_item[ 'node' ].remove
                        @targets.delete(target_key)
                    end
                end
            end

            # get list of available targets
            def targets(*args, **kwargs)
                return @targets.keys
            end

            def get_target_name(target, *args, **kwargs)
                name_node = target_node(target).at_xpath("name")
                Core.assert(!name_node.nil?) do
                    "missing '<name>' node"
                end
                return name_node.content
            end

            def set_target_name(target, value, *args, **kwargs)
                name_node = target_node(target).at_xpath("name")
                Core.assert(!name_node.nil?) do
                    "missing '<name>' node"
                end
                name_node.content = value
            end

            def set_node_value(path, value)
                return unless value
                state_node = @xml.at_xpath(path)
                return if state_node.nil?
                state_node.content = value
            end

            # set value to existing "<state>" node by xpath
            def set_state_node(target, xpath, value, *args, **kwargs)
                Core.assert(target.is_a?(String) && !target.empty?) do
                    "param must be non-empty string"
                end
                Core.assert(xpath.is_a?(String) && !xpath.empty?) do
                    "param must be non-empty string"
                end
                state_node = target_node(target).at_xpath(xpath)
                if state_node.nil?
                  puts "nodeset does not exist '#{xpath}'"
                  return
                end
                state_node.content = value.to_s
            end

            def state_node_exist?(target, xpath)
                state_node = target_node(target).at_xpath(xpath)
                if state_node.nil?
                    false
                else
                    true
                end
            end

            def create_option_node(target, xpath, name, state, *args, **kwargs)
                Core.assert(target.is_a?(String) && !target.empty?) do
                    "param must be non-empty string"
                end
                Core.assert(xpath.is_a?(String) && !xpath.empty?) do
                    "param must be non-empty string"
                end
                data_node = target_node(target).at_xpath(xpath)
                Core.assert(!data_node.nil?) do
                    "nodeset does not exist '#{xpath}'"
                end
                option_node = Nokogiri::XML::Node.new("option", @xml)
                name_node = Nokogiri::XML::Node.new("name", @xml)
                name_node.content =name
                option_node << name_node
                state_node = Nokogiri::XML::Node.new("state", @xml)
                state_node.content =state
                option_node << state_node
                data_node << option_node
            end

            def create_option_state_node(target, xpath, value, *args, **kwargs)
                Core.assert(target.is_a?(String) && !target.empty?) do
                    "param must be non-empty string"
                end
                Core.assert(xpath.is_a?(String) && !xpath.empty?) do
                    "param must be non-empty string"
                end
                option_node = target_node(target).at_xpath(xpath)
                Core.assert(!option_node.nil?) do
                    "nodeset does not exist '#{xpath}'"
                end
                state_node = target_node(target).at_xpath(xpath + '/state')
                state_node.remove if state_node && state_node.content.strip == ''
                state_node = Nokogiri::XML::Node.new("state", @xml)
                state_node.content = value.to_s
                option_node << state_node
            end

            def convert_string(value, *args, **kwargs)
                Core.assert(value.is_a?(String)) do
                    "conversion error, value '#{value}' is not a String type"
                end
                return value
            end

            def convert_enum(value, convert, *args, **kwargs)
                Core.assert(convert.has_key?(value)) do
                    "conversion error, value '#{value}' does not exists in enum '#{convert.keys.join(', ')}'"
                end
                return convert[ value ]
            end

            def convert_boolean(value, *args, **kwargs)
                Core.assert(value.is_a?(TrueClass) || value.is_a?(FalseClass)) do
                    "conversion error, value '#{value}' must be a 'true' or 'false'"
                end
                return value ? '1' : '0'
            end
        end

        # Base tab class to inherit @operations attribute
        class TabBase
            attr_reader :operations
            def initialize(operations)
                @operations = operations
            end
        end

        class SetupTab < TabBase

            private

            def driver(target, value, *args, **kwargs)
                # we dont need debuggers like ST, TI, ...
                # but just to keep the idea here is the full list
                convert = {
                    'simulator'     => 'ARMSIM_ID',
                    'angel'         => 'ANGEL_ID',
                    'cmsisdap'      => 'CMSISDAP_ID',
                    'gdbserver'     => 'GDBSERVER_ID',
                    'rom_monitor'   => 'IARROM_ID',
                    'ijet'          => 'IJET_ID',
                    'jlink'         => 'JLINK_ID',
                    'ti_stellaris'  => 'LMIFTDI_ID',
                    'macraigor'     => 'MACRAIGOR_ID',
                    'pemicro'       => 'PEMICRO_ID',
                    'rdi'           => 'RDI_ID',
                    'stlink'        => 'STLINK_ID',
                    'xds100'        => 'XDS100_ID',
                }
                @operations.set_state_node(
                    target, "settings/data/option[name=\"OCDynDriverList\"]/state", @operations.convert_enum(value, convert)
                )
            end

            def run_to(target, value, choose, *args, **kwargs)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"RunToName\"]/state", @operations.convert_string(value)
                )
                @operations.set_state_node(
                    target, "settings/data/option[name=\"RunToEnable\"]/state", @operations.convert_boolean(choose)
                )
            end
        end


        class DownloadTab < TabBase

            private

            def attach_to_running(target, value, *args, **kwargs)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"OCDownloadAttachToProgram\"]/state", @operations.convert_boolean(value)
                )
            end

            def verify_download(target, value, *args, **kwargs)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"OCDownloadVerifyAll\"]/state", @operations.convert_boolean(value)
                )
            end

            def suppress_download(target, value, *args, **kwargs)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"OCDownloadSuppressDownload\"]/state", @operations.convert_boolean(value)
                )
            end

            def use_flash_loaders(target, value, *args, **kwargs)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"UseFlashLoader\"]/state", @operations.convert_boolean(value)
                )
            end

            def board_file(target, value, *args, **kwargs)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"FlashLoadersV3\"]/state", @operations.convert_string(value)
                )
                @operations.set_state_node(
                    target, "settings/data/option[name=\"OverrideDefFlashBoard\"]/state", @operations.convert_boolean(true)
                )
            end

            def macro_file(target, value, choose, *args, **kwargs)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"MacOverride\"]/state", @operations.convert_boolean(choose)
                )
                @operations.set_state_node(
                    target, "settings/data/option[name=\"MacFile\"]/state", @operations.convert_string(value)
                )
            end
        end

        class MulticoreTab < TabBase
            private

            def multicore_master_mode(target, value)
                path = "settings/data/option[name=\"OCMulticoreAMPConfigType\"]/state"
                if @operations.state_node_exist?(target, path)
                    @operations.set_state_node(
                      target, path, @operations.convert_boolean(value)
                    )
                else
                    @operations.create_option_node(
                      target, "settings/data", 'OCMulticoreAMPConfigType', @operations.convert_boolean(value)
                    )
                end
            end

            def slave_multicore_attach(target, value)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"OCAttachSlave\"]/state", @operations.convert_boolean(value)
                )
            end

            def slave_workspace(target, value)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"OCMulticoreWorkspace\"]/state", @operations.convert_string(value)
                )
            end

            def slave_project(target, value)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"OCMulticoreSlaveProject\"]/state", @operations.convert_string(value)
                )
            end

            def slave_configuration(target, value)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"OCMulticoreSlaveConfiguration\"]/state", @operations.convert_string(value)
                )
            end
        end

        class ImagesTab < TabBase
            private
            def download_extra_image(target, value)
                @operations.set_state_node(
                        target, "settings/data/option[name=\"OCImagesUse#{value}\"]/state", @operations.convert_boolean((1..3).include?(value))
                    )
            end

            def image_path(target, value, order)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"OCImagesPath#{order}\"]/state", @operations.convert_string(value)
                )
            end

            def offset(target, value, order)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"OCImagesOffset#{order}\"]/state", @operations.convert_string(value)
                )
            end

            def debug_info_only(target, value, order)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"OCImagesSuppressCheck#{order}\"]/state", @operations.convert_boolean(value)
                )
            end
        end

        class ExtraOptionTab < TabBase
            private
            def use_command_line_options(target, value)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"CExtraOptionsCheck\"]/state", @operations.convert_boolean(value)
                )
            end
            def set_command_line_options(target, value)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"CExtraOptions\"]/state", @operations.convert_string(value)
                )
            end
            def set_debugger_extra_options(target, value)
                @operations.create_option_state_node(
                    target, "settings/data/option[name=\"CExtraOptions\"]", @operations.convert_string(value)
                )
            end
        end

        class DebuggerCmsisDapTab < TabBase
            private
            def interface_probeconfig(target, value)
                value = case value
                    when 'auto'
                        '0'
                    when 'from file'
                        '1'
                    when 'explicit'
                        '2'
                    else
                        '0'
                end
                @operations.set_state_node(
                    target, "settings/data/option[name=\"CMSISDAPProbeConfigRadio\"]/state", @operations.convert_string(value)
                )
            end

            def cmsisdap_multicpu_enable(target, value)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"CMSISDAPMultiCPUEnable\"]/state", @operations.convert_boolean(value)
                )
            end

            def cmsisdap_multitarget_enable(target, value)
                @operations.set_state_node(
                    target, "settings/data/option[name=\"CMSISDAPMultiTargetEnable\"]/state", @operations.convert_boolean(value)
                )
            end
            def cmsisdap_resetlist(target, value)
                value = case value
                    when 'disabled'
                        '0'
                    when 'software'
                        '1'
                    when 'hardware'
                        '2'
                    when 'core'
                        '3'
                    when 'system'
                        '4'
                    when 'custom'
                        '5'
                    when 'halt_after_bootloader'
                        '7'
                    else
                        '5'
                end
                @operations.set_state_node(
                    target, "settings/data/option[name=\"CMSISDAPResetList\"]/state", @operations.convert_string(value)
                )
            end

        end

    end

end
end

