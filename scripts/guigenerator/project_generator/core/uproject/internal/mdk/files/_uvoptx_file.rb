# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../_xml_utils'
require_relative '../../../../_file'
require_relative '../../../../../../utils/cmsis'
require_relative '../../../../../../utils/_assert'
require_relative '../../../../../../utils/data_problems_logger'
#TODO FIXME
#require_relative '../../../../../../../src/manifest_generator/manifest_populator/populator_utils'
require 'nokogiri'
require 'logger'


module Internal
  module Mdk

    # Common class to manipulate with .uvproj xml file
    # Subclasses and methods respond to GUI elements
    class UvoptxFile

      attr_reader :xml
      attr_reader :logger
      attr_reader :operations

      private

      def initialize(template, *args, logger: nil, **kwargs)
        @xml = XmlUtils.load(template)
        @xml_path = File.dirname(template)
        @logger = logger ? logger : Logger.new(STDOUT)
      end

      # Save file
      # ==== arguments161
      # path      - string, file path to save
      def save(path, *args, **kargs)
        Core.assert(path.is_a?(String) && !path.empty?) do
          "param must be non-empty string"
        end
        @logger.debug("generate file: #{path}")
        XmlUtils::save(@xml, path)
      end

      # Setup project name
      # ==== arguments
      # target    - target name
      # value       - xml document
      def project_name(target, value, *args, used: false, **kargs)
        name_node = @operations.target_node(target, used: used).at_xpath("./TargetName")
        Core.assert(!name_node.nil?) do
          "no '<TargetName>' node"
        end
        name_node.content = value
      end

      # Setup project name
      def clear_unused_targets!(*args, **kargs)
        @operations.clear_unused_targets!
      end

      def get_target_name(*args, **kwargs)
        return @operations.get_target_name(*args, **kwargs)
      end

      def set_target_name(*args, **kwargs)
        @operations.set_target_name(*args, **kwargs)
      end

      # Get list of available targets
      def targets(*args, **kargs)
        return @operations.targets
      end

      # make subclasses private

      private

      # Internal class, provide common operations of xml project
      class DocumentOperations

        attr_reader :xml
        attr_reader :targets
        attr_reader :groups
        attr_reader :logger

        # Load all available targets in XML document and
        # mark them with no-used flag !
        # ==== arguments
        # xml       - xml document
        def initialize(xml, *args, logger: nil, **kwargs)
          # init object attributes
          @xml = xml
          @logger = logger
          @targets = {}
          @groups = {}
          # loop over targets
          nodes = @xml.xpath("/ProjectOpt/Target")
          nodes.each do |target_node|
            name_node = target_node.at_xpath("TargetName")
            Core.assert(!name_node.nil?) do
              "no <TargetName> node!"
            end
            # and use downcase stripped version of target name
            target = name_node.content.strip.downcase
            name_node.content = target
            @targets[target] = {
                'node' => target_node,
                'used' => false
            }
          end
        end

        def targets()
          return @targets.keys
        end

        # Return target node and set 'used' flag
        # ==== arguments
        # target    - name of target
        def target_node(target, used: nil)
          Core.assert(target.is_a?(String) && !target.empty?) do
            "param must be non-empty string"
          end
          Core.assert(!used.nil?, "used cannot be nil!")
          # use downcase stripped version
          target = target.strip.downcase
          Core.assert(@targets.has_key?(target)) do
            "target '#{target}' is not present. use one of: #{@targets.keys} "
          end
          Core.assert(!@targets[target]['node'].nil?) do
            "name '#{target}' does not exist"
          end
          if (used)
            @targets[target]['used'] = true
          end
          return @targets[target]['node']
        end

        # Clear unused targets
        def clear_unused_targets!
          @targets.each do |target_key, target_item|
            if (target_item['used'] == false)
              target_item['node'].remove()
              @targets.delete(target_key)
            end
          end
        end

        def get_target_name(target, *args, used: false, **kwargs)
          target_node = target_node(target, used: used)
          name_node = target_node.at_xpath("TargetName")
          Core.assert(!name_node.nil?) do
            "missing 'name' node"
          end
          return name_node.content
        end

        def set_target_name(target, value, *args, used: false, update_table: false, **kwargs)
          Core.assert(!update_table) do
            "not implemented"
          end
          target_node = target_node(target, used: used)
          name_node = target_node.at_xpath("TargetName")
          Core.assert(!name_node.nil?) do
            "missing 'name' node"
          end
          name_node.content = value
        end

        # Add source file into 'vdirexpr' directory
        # ==== arguments
        # path      - name of target
        # vdirexpr  - string, virtual dir expression
        def add_source(path, vdirexpr, source_target)
          extension = File.extname(path)
          basename = File.basename(path)
          filetype = 5
          # choose filetype according extension
          if (extension =~ /(?i)^.(c)$/)
            filetype = 1 # c files
          elsif (extension =~ /(?i)^.(s|asm)$/)
            filetype = 2 # assembly files
          elsif (extension =~ /(?i)^.(o)$/)
            filetype = 3 # object files
          elsif (extension =~ /(?i)^.(lib|a)$/)
            filetype = 4 # libraries
          elsif (extension =~ /(?i)^.(h|hpp|txt|inc)$/)
            filetype = 5 # other non-bulded files
          elsif (extension =~ /(?i)^.(cpp|cc)$/)
            filetype = 8 # cpp files
          end
          targets.each do |target|
            group_node = create_group(target, vdirexpr)
            # add <File>
            file_node = Nokogiri::XML::Node.new("File", @xml)
            group_node << file_node
            # add <FileName>
            node = Nokogiri::XML::Node.new("FileName", @xml)
            node.content = basename
            file_node << node
            # add <FileType>
            node = Nokogiri::XML::Node.new("FileType", @xml)
            node.content = filetype
            file_node << node
            # add <FilePath>
            node = Nokogiri::XML::Node.new("FilePath", @xml)
            node.content = path
            file_node << node
            unless source_target == nil
              unless source_target.include?(target)
                set_IncludeInBuild(file_node)
              end
            end
          end
        end

        def add_comfiguration(target, folder, optlevel)
          target_node = @xml.xpath("/Project/Targets/Target")
          target_node.each do |target_node|
            next unless target_node.at_xpath("./TargetName").content == target
            groups_node = target_node.xpath("./Groups/Group")
            groups_node.each do |node|
              if node.at_xpath("./GroupName").content == folder
                groupoption_node = Nokogiri::XML::Node.new("GroupOption", @xml)
                node << groupoption_node

                grouparmads_node = Nokogiri::XML::Node.new("GroupArmAds", @xml)
                groupoption_node << grouparmads_node

                group_cads_node = Nokogiri::XML::Node.new("Cads", @xml)
                group_cads_node.content = target_node.at_xpath("./TargetOption/TargetArmAds/Cads")
                grouparmads_node << group_cads_node.text

                group_aads_node = Nokogiri::XML::Node.new("Aads", @xml)
                group_aads_node.content = target_node.at_xpath("./TargetOption/TargetArmAds/Aads")
                grouparmads_node << group_aads_node.text

                commonproperty_node = Nokogiri::XML::Node.new("CommonProperty", @xml)
                commonproperty_node.content = target_node.at_xpath("./TargetOption/CommonProperty")
                groupoption_node << commonproperty_node.text

                convert = {'O0' => 1, 'O1' => 2, 'O2' => 3, 'O3' => 4}
                set_option_node(
                    target.split(' ')[-1], "//GroupOption/GroupArmAds/Cads/Optim", convert_enum(optlevel, convert), used: true
                )

              end
            end
          end
        end

        # Add source file into 'vdirexpr' directory
        def clear_sources!(used: false)
          targets.each do |target|
            @groups[target] = {}
            groups_node = target_node(target, used: false).at_xpath('Groups')
            groups_node.remove() unless (groups_node.nil?)
          end
        end

        # Add source file into 'vdirexpr' directory
        def clear_flashDriver!(used: false)
          targets.each do |target|
            @groups[target] = {}
            flashDriver_node = target_node(target, used: false).at_xpath('TargetOption/TargetCommonOption/FlashDriverDll')
            flashDriver_node.remove() unless (flashDriver_node.nil?)
          end
        end

        def set_IncludeInBuild(file_node)
          common_property = @xml.at_xpath("/Project/Targets/Target/TargetOption/CommonProperty")
          common_property.at_xpath("./UseCPPCompiler").content = 2
          common_property.at_xpath("./RVCTCodeConst").content = 0
          common_property.at_xpath("./RVCTZI").content = 0
          common_property.at_xpath("./RVCTOtherData").content = 0
          common_property.at_xpath("./ModuleSelection").content = 0
          common_property.at_xpath("./IncludeInBuild").content = 0
          common_property.at_xpath("./AlwaysBuild").content = 2
          common_property.at_xpath("./GenerateAssemblyFile").content = 2
          common_property.at_xpath("./AssembleAssemblyFile").content = 2
          common_property.at_xpath("./PublicsOnly").content = 2
          common_property.at_xpath("./StopOnExitCode").content = 11

          file_option = Nokogiri::XML::Node.new("FileOption", @xml)
          file_node << file_option

          file_option << common_property

          fileArmAds_node = Nokogiri::XML::Node.new("FileArmAds", @xml)
          file_option << fileArmAds_node

          cads_node = Nokogiri::XML::Node.new("Cads", @xml)

          interw_node = Nokogiri::XML::Node.new("interw", @xml)
          interw_node.content = 2
          cads_node << interw_node
          optim_node = Nokogiri::XML::Node.new("Optim", @xml)
          optim_node.content = 0
          cads_node << optim_node
          oTime_node = Nokogiri::XML::Node.new("oTime", @xml)
          oTime_node.content = 2
          cads_node << oTime_node
          splitLS_node = Nokogiri::XML::Node.new("SplitLS", @xml)
          splitLS_node.content = 2
          cads_node << splitLS_node
          oneElfS_node = Nokogiri::XML::Node.new("OneElfS", @xml)
          oneElfS_node.content = 2
          cads_node << oneElfS_node
          strict_node = Nokogiri::XML::Node.new("Strict", @xml)
          strict_node.content = 2
          cads_node << strict_node
          enumInt_node = Nokogiri::XML::Node.new("EnumInt", @xml)
          enumInt_node.content = 2
          cads_node << enumInt_node
          plainCh_node = Nokogiri::XML::Node.new("PlainCh", @xml)
          plainCh_node.content = 2
          cads_node << plainCh_node
          ropi_node = Nokogiri::XML::Node.new("Ropi", @xml)
          ropi_node.content = 2
          cads_node << ropi_node
          rwpi_node = Nokogiri::XML::Node.new("Rwpi", @xml)
          rwpi_node.content = 2
          cads_node << rwpi_node
          wLevel_node = Nokogiri::XML::Node.new("wLevel", @xml)
          wLevel_node.content = 0
          cads_node << wLevel_node
          uThumb_node = Nokogiri::XML::Node.new("uThumb", @xml)
          uThumb_node.content = 2
          cads_node << uThumb_node
          uSurpInc_node = Nokogiri::XML::Node.new("uSurpInc", @xml)
          uSurpInc_node.content = 2
          cads_node << uSurpInc_node
          uC99_node = Nokogiri::XML::Node.new("uC99", @xml)
          uC99_node.content = 2
          cads_node << uC99_node
          useXO_node = Nokogiri::XML::Node.new("useXO", @xml)
          useXO_node.content = 2
          cads_node << useXO_node

          fileArmAds_node << cads_node

        end

        # Create virtual directory according 'vdirexpr' expression
        # ==== arguments
        # target    - name of target
        # vdirexpr  - vdirexpr
        def create_group(target, vdirexpr, used: false)
          if (@groups[target].nil? || @groups[target][vdirexpr].nil?)
            target_node = target_node(target, used: used)
            groups_node = target_node.at_xpath('Groups')
            if (groups_node.nil?)
              groups_node = Nokogiri::XML::Node.new("Groups", @xml)
              target_node << groups_node
            end
            # add '<Group>'
            group_node = Nokogiri::XML::Node.new("Group", @xml)
            groups_node << group_node
            # add '<GroupName>'
            name_node = Nokogiri::XML::Node.new("GroupName", @xml)
            name_node.content = vdirexpr
            group_node << name_node
            # add '<Files>'
            files_node = Nokogiri::XML::Node.new("Files", @xml)
            group_node << files_node
            # add to @groups
            @groups[target] = {} if (@groups[target].nil?)
            @groups[target][vdirexpr] = files_node
          end
          return @groups[target][vdirexpr]
        end

        # Setup  '<Option>' node
        # ==== arguments
        # target    - name of target
        # xpath     - xpath expression
        # value     - value to setup
        def set_option_node(target, xpath, value, used: nil)
          option_node = create_option_node(target, xpath, used: used)
          option_node.content = value
        end

        # Setup  '<Option>' node
        # ==== arguments
        # target    - name of target
        # xpath     - xpath expression
        def create_option_node(target, xpath, used: nil)
          option_node = target_node(target, used: used).at_xpath(xpath)
          if (option_node.nil?)
            # so the node requested by xpath does not exist
            # don't panic and tries create a new one
            # take the last node name from xpath expression
            # and tries to find parrent node
            matched = xpath.match(/^(.*)\/([^\/]+)/)
            Core.assert(!matched.nil?) do
              "corrupted xpath #{xpath}"
            end
            parent_xpath, node_name = matched.captures
            parent_node = target_node(target, used: used).at_xpath(parent_xpath)
            Core.assert(!parent_node.nil?) do
              "not such a node #{parent_xpath}"
            end
            option_node = Nokogiri::XML::Node.new(node_name, @xml)
            parent_node << option_node
          end
          Core.assert(!option_node.nil?) do
            "node of '#{xpath}' does not exist"
          end
          return option_node
        end

        # -------------------------------------------------------------------------------------
        # Create new node recursively if node does not exist
        # @param [String] target: the name of target
        # @param [String] xpath: xpath expression
        # @return [Nokogiri::XML::Element]: the created node of the xpath
        def create_option_node_for_src(target, xpath, used: nil)
          option_node = target_node(target, used: used).at_xpath(xpath)
          if (option_node.nil?)
            # so the node requested by xpath does not exist
            # don't panic and tries create a new one
            # take the last node name from xpath expression
            # and tries to find parrent node
            matched = xpath.match(/^(.*)\/([^\/]+)/)
            Core.assert(!matched.nil?) do
              "corrupted xpath #{xpath}"
            end
            parent_xpath, node_name = matched.captures
            parent_node = target_node(target, used: used).at_xpath(parent_xpath)
            if parent_node.nil?
              parent_node = create_option_node_for_src(target, parent_xpath, used: used)
            end
            Core.assert(!parent_node.nil?) do
              "not such a node #{parent_xpath}"
            end
            option_node = Nokogiri::XML::Node.new(node_name, @xml)
            parent_node << option_node
          end
          Core.assert(!option_node.nil?) do
            "node of '#{xpath}' does not exist"
          end
          return option_node
        end

        def convert_string(value)
          Core.assert(value.is_a?(String)) do
            "conversion error, value '#{value}' is not a String type"
          end
          return value
        end

        def convert_enum(value, convert)
          Core.assert(convert.has_key?(value)) do
            "conversion error, value '#{value}' does not exists in enum '#{convert.keys.join(', ')}'"
          end
          return convert[value]
        end

        def convert_boolean(value)
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

      class DebugTab < TabBase
        def add_initialization_file(target, path, *args, used: true, **kargs)
          @operations.set_option_node(
              target, "TargetOption/DebugOpt/tIfile", @operations.convert_string(path), used: used
          )
        end

        def set_load_application(target, value, *args, used: true, **kargs)
          @operations.set_option_node(
              target, "TargetOption/DebugOpt/tLdApp", value, used: used
          )
        end

        def set_periodic_update(target, value, *args, used: true, **kargs)
          @operations.set_option_node(
              target, "TargetOption/DebugFlag/periodic", value, used: used
          )
        end
      end
    end

  end
end



