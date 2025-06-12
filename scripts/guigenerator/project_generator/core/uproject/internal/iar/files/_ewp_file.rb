# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../internal/_xml_utils'
require_relative '../../../../../../utils/_assert'
require_relative '../../../../../../utils/cmsis'
# require_relative '../../../../../../pdsc_generator//pdsc_populator/pdsc_utils'
require 'nokogiri'
require 'logger'


module Internal
  module Iar

    # Common class to manipulate with .ewp xml file
    # Subclasses and methods respond to GUI elements
    # Code/method inspection is pretty usefull
    class EwpFile

      attr_reader :xml
      attr_reader :logger
      attr_reader :operations

      private

      def initialize(template, *args, logger: nil, **kwargs)
        @xml = XmlUtils.load(template)
        @xml_path = File.dirname(template)  # path where .ewp file is located
        @logger = logger ? logger : Logger.new(STDOUT)
        @files_to_remove = []
        @components = Set[]
        @pack_info = {}
        @data_err_logger = nil
        @version_map = {
          "/project/fileVersion" => 3,
          "./settings[name=\"General\"]/data/version" => 35,
          "./settings[name=\"General\"]/data/option[name=\"GBECoreSlave\"]/version" => 32,
          "./settings[name=\"General\"]/data/option[name=\"CoreVariantVersion\"]/version" => 32,
          "./settings[name=\"General\"]/data/option[name=\"GFPUCoreSlave2Version\"]/version" => 32,
          "./settings[name=\"ICCARM\"]/data/version" => 37,
          "./settings[name=\"AARM\"]/data/version" => 11,
          "./settings[name=\"BUILDACTION\"]/archiveVersion" => 1,
        }
      end

      # Save file
      # ==== arguments
      # path      - string, file path to save
      def save(path, *args, **kargs)
        Core.assert(path.is_a?(String) && !path.empty?) do
          "param must be non-empty string"
        end
        # save set CMSIS structure to project file
        @rte_node.content = @rte_xml.to_xml if @rte_node
        @logger.debug("generate file: #{path}")
        XmlUtils::save(@xml, path)
      end

      # Add source file into 'vdirexpr' directory
      # ==== arguments
      # path      - name of target
      # vdirexpr  - string, virtual dir expression
      def add_source(path, vdirexpr, *args, **kargs)
        @operations.add_source(path, vdirexpr)
      end

      def add_comfiguration(target, path, optlevel, *args, **kargs)
        @operations.add_comfiguration(target, path, optlevel)
      end

      def add_specific_ccinclude(target, folder, path, *args, **kargs)
        @operations.add_specific_ccinclude(target, folder, path)
      end

      # Remove all source files
      def clear_sources!(*args, **kargs)
        @operations.clear_sources!()
      end

      def get_target_name(*args, **kwargs)
        return @operations.get_target_name(*args, **kwargs)
      end

      def set_target_name(*args, **kwargs)
        @operations.set_target_name(*args, **kwargs)
      end

      # Return list of all targets found in xml file
      def targets(*args, **kargs)
        return @operations.targets.keys
      end

      def clear_unused_targets!(*args, **kargs)
        @operations.clear_unused_targets!
      end

      # Return absolute paths to files to be remove
      # @return [Array<String>] Absolute paths to files
      def files_to_remove
        return @files_to_remove
      end

      # Create structure for CMSIS data to example project file to @rte_xml, @rte_node
      # @return [Nil]
      def create_rte_component
        rte_node = @xml.at_xpath('/project/cmsisPackSettings/rte')
        unless rte_node
          project_node = @xml.at_xpath('/project')
          cmsis_node = Nokogiri::XML::Node.new('cmsisPackSettings', @xml)
          project_node << cmsis_node
          rte_node = Nokogiri::XML::Node.new('rte', @xml)
          cmsis_node << rte_node
        end
        rte_text = '<?xml version="1.0" encoding="UTF-8" standalone="no"?>' \
              '<configuration xmlns:xs="http://www.w3.org/2001/XMLSchema-instance">' \
              '<components></components>' \
              '</configuration>'
        # identify CMSIS pack based project
        @xml.xpath('//option').each do |name|
          name.at_xpath('state').content = 2 if name.child.content == 'OGCoreOrChip'
        end
        # Update xml
        @rte_xml = Nokogiri.XML(rte_text)
        @rte_node = rte_node
      end

      # Set package of component
      # @param [HasH] cmsis_info: CMSIS ID vector
      # @param [Nokogiri::XML::Node] component_node: element of component
      # @return [Nil]
      def add_package_component(cmsis_info, component_node)
        package_node = Nokogiri::XML::Node.new('package', @xml)
        package_node['url'] = cmsis_info[:pack_url] if cmsis_info.safe_key?(:pack_url)
        package_node['version'] = cmsis_info[:pack_version]
        package_node['vendor'] = cmsis_info[:pack_vender]
        package_node['name'] = cmsis_info[:pack_name]
        component_node << package_node
      end

      # Update include paths to default "$PROJ_DIR$"
      # @return [nil]
      def update_include_paths
        @xml.xpath('//option').each do |option|
          option.xpath('name').each do |name_element|
            next unless name_element.content == 'CCIncludePath2'

            option.xpath('state').select { |s| s.content.start_with?('$PROJ_DIR$/..') }.each(&:remove)

            states = option.xpath('state')
            next if states.empty?

            # add '$PROJ_DIR$' as first include path
            state_node = Nokogiri::XML::Node.new('state', @xml)
            state_node.content = '$PROJ_DIR$'
            states[0].add_previous_sibling state_node
          end
        end
      end

      # Set board project template component
      # @param [CmsisCompVector] cmsis_vector: CMSIS ID vector
      # @param [Array<String>] files: board project template files
      # @return [Nil]
      def add_project_template_component(cmsis_vector, files)
        create_rte_component unless @rte_xml
        components_node = @rte_xml.at_xpath('/configuration/components')
        component_node = Nokogiri::XML::Node.new('component', @xml)
        component_node['Cvariant'] = cmsis_vector.c_variant
        component_node['Cversion'] = cmsis_vector.version
        component_node['Csub'] = cmsis_vector.c_sub
        component_node['Cgroup'] = cmsis_vector.c_group
        component_node['Cclass'] = cmsis_vector.c_class
        components_node << component_node
        add_package_component(cmsis_vector, component_node)

        files.each do |path|
          file = File.basename(path)
          package_node = add_config_file(file)
          package_node['name'] = File.join('project_template', file)
          component_node << package_node
        end
      end

      # Set config file for component
      # @param [Array<String>] config_file: config file name of component
      # @return [Nokogiri::XML::Node] file_node: element of config file
      def add_config_file(config_file)
        file_node = Nokogiri::XML::Node.new('file', @xml)
        file_node['category'] = PdscUtils.get_pdsc_source_type(File.extname(config_file))
        file_node['version'] = '1.0.0' # currently version is not supported in YML, this value is hardcoded
        file_node['attr'] = 'config'
        return file_node
      end

      # Set config files for component
      # @param [CmsisCompVector] cmsis_vector: CMSIS ID vector
      # @param [Nokogiri::XML::Node] component_node: element of component
      # @param [Array<String>] config_files: relative paths to config files of component
      # @param [String] device_part_number: device part name with core Pname
      # @param [ExampleSrcRemoval] example_src_removal: helper class to remove unused sources moved to project folder
      # @return [Nil]
      def add_config_group_file(cmsis_vector, component_node, config_files, device_part_number, example_src_removal)
        config_files.each do |path|
          file = File.basename(path)
          file_node = add_config_file(file)
          file_node['name'] = file
          component_node << file_node
        end
        add_project_template_files(config_files, cmsis_vector, device_part_number, example_src_removal)
      end

      # Set CMSIS components for project files
      # @param [CmsisCompVector] cmsis_vector: CMSIS ID vector
      # @param [Array<String>] config_files: relative paths to config files of component
      # @param [String] partnum: device part name with core Pname
      # @param [ExampleSrcRemoval] src_removal: helper class to remove unused sources moved to project folder
      # @return [Nil]
      def add_rte_package_and_component(cmsis_vector, config_files, partnum, src_removal)
        create_rte_component unless @rte_xml
        # For ARM CMSIS API component, no need to be added
        return if !cmsis_vector.apiversion.nil? && cmsis_vector.c_vendor == 'ARM'

        @components.each do |component_vector|
          return if component_vector.c_class == cmsis_vector.c_class &&
                    component_vector.c_group == cmsis_vector.c_group &&
                    component_vector.c_sub == cmsis_vector.c_sub &&
                    component_vector.version == cmsis_vector.version &&
                    component_vector.c_variant == cmsis_vector.c_variant
        end
        @components.push(cmsis_vector)
        components_node = @rte_xml.at_xpath('/configuration/components')
        component_node = Nokogiri::XML::Node.new('component', @xml)
        component_node['Cversion'] = cmsis_vector.version
        component_node['Capiversion'] = cmsis_vector.apiversion unless cmsis_vector.apiversion.nil?
        component_node['Csub'] = cmsis_vector.c_sub unless cmsis_vector.c_sub.nil?
        component_node['Cgroup'] = cmsis_vector.c_group
        component_node['Cclass'] = cmsis_vector.c_class
        component_node['Cvariant'] = cmsis_vector.c_variant unless cmsis_vector.c_variant.nil?
        components_node << component_node
        add_package_component(cmsis_vector, component_node)
        add_config_group_file(cmsis_vector, component_node, config_files, partnum, src_removal) if config_files.any?
      end

      # Set CMSIS components for project files
      # @param [Hash] cmsis_info: CMSIS component information
      # @return [Nil]
      def add_rte_component(cmsis_info)
        create_rte_component unless @rte_xml
        # For ARM CMSIS API component, no need to be added
        return if !cmsis_info[:apiversion].nil? &&  cmsis_info[:pack_vender] == 'ARM'

        uniq_cmsis_vector = [cmsis_info[:cclass], cmsis_info[:cgroup], cmsis_info[:csub], cmsis_info[:cvendor], cmsis_info[:cvariant]]
        return if @components.add?(uniq_cmsis_vector).nil?

        @pack_info = cmsis_info if @pack_info.empty? && cmsis_info[:pack_vender] == 'NXP' && cmsis_info[:pack_name].include?("DFP")
        components_node = @rte_xml.at_xpath('/configuration/components')
        component_node = Nokogiri::XML::Node.new('component', @xml)
        component_node['Cversion'] = cmsis_info[:cversion]
        component_node['Capiversion'] = cmsis_info[:apiversion] if cmsis_info.safe_key?(:apiversion)
        component_node['Csub'] = cmsis_info[:csub] if cmsis_info.safe_key?(:csub)
        component_node['Cgroup'] = cmsis_info[:cgroup]
        component_node['Cclass'] = cmsis_info[:cclass]
        component_node['Cbundle'] = cmsis_info[:cbundle] if cmsis_info.safe_key?(:cbundle)
        component_node['Cvariant'] = cmsis_info[:cvariant] if cmsis_info.safe_key?(:cvariant)
        components_node << component_node
        add_package_component(cmsis_info, component_node)
      end

      # Set CMSIS toolchain and device for project files, update include paths, set data error logger
      # @param [String] d_name: device long name
      # @param [String] d_family: device family name
      # @param [String] d_variant: device variant name
      # @param [String] core_name: name of the core used in the project for multi-core device; nil for single-core
      # @param [String] core_id: p-name of the core(core id) used in the project for multi-core device; nil for single-core
      # @param [ExampleInputData] example: example input data used for log_data_error
      # @return [Nil]
      def add_rte_globals(d_name, d_family, d_variant, core_name, core_id)
        create_rte_component unless @rte_xml
        configuration_node = @rte_xml.at_xpath('/configuration')

        toolchain_node = Nokogiri::XML::Node.new('toolchain', @xml)
        toolchain_node['Tcompiler'] = 'IAR'
        toolchain_node['Toutput'] = 'exe'
        configuration_node << toolchain_node

        device_node = Nokogiri::XML::Node.new('device', @xml)
        device_node['Dname'] = d_name
        device_node['Dvendor'] = Pdsc::NXP_VENDOR_COLON_ID
        device_node['Dfamily'] = d_family
        device_node['Dvariant'] = d_variant
        # only for multicore device
        if core_id
          device_node['Dcore'] = core_name unless core_name.nil?
          device_node['Pname'] = core_id unless core_id.nil?
        end
        configuration_node << device_node

        package_node = Nokogiri::XML::Node.new('package', @xml)
        package_node['url'] = @pack_info[:pack_url]
        package_node['version'] = @pack_info[:pack_version]
        package_node['vendor'] = @pack_info[:pack_vender]
        package_node['name'] = @pack_info[:pack_name]
        device_node << package_node
      end

      # copy file to destination folder
      # @param [String] destination: relative path from root example
      # @param [String] file_path: absolute file path to copy
      def copy_file_to_example(destination, file_path)
        FileUtils.mkdir_p(destination)
        unless File.exist?(file_path)
          @data_err_logger.log_data_error("example MDK '#{destination}', File cannot be copied, as it doesn't "\
                                     "exist: #{file_path}\n")
          return
        end

        FileUtils.cp(file_path, destination)
      end

      # Add include path of specific file if not exist
      # @param [Array<String>] path: relative path to directory, where is a specific file
      # @return [nil]
      def add_include_path(path)
        @xml.xpath('//option').each do |option|
          option.xpath('name').each do |name_element|
            next unless name_element.content == 'CCIncludePath2'

            contain = true
            option.xpath('state').each do |state_element|
              contain = false if state_element.content == path
            end
            next unless contain

            state_node = Nokogiri::XML::Node.new('state', @xml)
            state_node.content = path
            option << state_node
          end
        end
      end

      # Determines if IlinkExtraOptions instances contain an include path related to a copied project file. If so,
      # the IlinkExtraOptions/state elements are updated accordingly.
      # # @param [String] old_fpath: old path of the project file
      # @param [String] new_fpath: new path of the project file
      # @return nil
      def check_ilinkExtraOptions(old_fpath, new_fpath)
        @xml.xpath('//option').each do |option|
          option.xpath('name').each do |name_element|
            next unless name_element.content == 'IlinkExtraOptions'

            option.xpath('state').each do |state|
              next if state.content.empty?

              tokens = state.content.split('=').map { |t| t.split ',' }
              found_idx = []
              tokens.each do |tx|
                x = tokens.index(tx)
                tx.each { |ty| found_idx << [x, tokens[x].index(ty)] if ty == old_fpath}
              end
              next if found_idx.empty?

              found_idx.each { |i| tokens[i[0]][i[1]] = new_fpath }
              new_cont = ''
              tokens.each do |tx|
                new_cont += tx.join(',')
                new_cont += '=' if tokens.index(tx) < tokens.length - 1
              end

              pos = option.children.index(state)
              state.remove
              state_node = Nokogiri::XML::Node.new('state', @xml)
              state_node.content = new_cont
              option.children[pos].add_previous_sibling(state_node)
            end
          end
        end
      end

      # Removes all '../' substrings in a string after the '$PROJ_DIR$/' occurence
      # @param [String] str: string (mostly filepath) possibly containing parent directory references
      # @return [String] cleaned string
      def remove_parent_dir_ref(str)
        return str.scan(/(^[^\/]*\/|[^\.\/]*[a-zA-Z0-9_].*)/).join('')
      end

      # Update selected project file: remove config files and copy files from non-project folder
      # @param [Element] file_element: XML element for the file
      # @param [Array<String>] config_files: name of config files
      # @param [ExampleSrcRemoval] example_src_removal: helper class to remove unused sources moved to project folder
      # @return [Boolean] true if the file was removed; false if file still exists
      def update_prj_file_for_cmsis(file_element, config_files, example_src_removal)
        file_name = file_element.at_xpath('name').content
        if config_files.include? File.basename(file_name)
          file_element.remove
          return true
        end

        unless file_name.start_with?('$PROJ_DIR$/../')
          destination = File.join(@xml_path, file_name.sub('$PROJ_DIR$/', ''))
          example_src_removal.keep_referenced_src(destination)
          return false
        end

        # Files outside project directory move to the project
        new_file_name = remove_parent_dir_ref(file_name)
        file_element.at_xpath('name').content = new_file_name
        destination = File.dirname(File.join(@xml_path, new_file_name.sub('$PROJ_DIR$/', '')))
        orig_abs_path = File.join(@xml_path, file_name.sub('$PROJ_DIR$/', ''))
        @files_to_remove.push_uniq(orig_abs_path)
        #FIXME [SDKGEN-1622] Use target path contained in the group/name element
        copy_file_to_example(destination, orig_abs_path)
        add_include_path(File.dirname(new_file_name))
        check_ilinkExtraOptions(file_name, new_file_name)
        return false
      end

      # Recursively update project files for selected group: remove config files and copy files from non-project folder
      # @param [Element] group: project group to process
      # @param [Array<String>] config_files: name of config files
      # @param [ExampleSrcRemoval] example_src_removal: helper class to remove unused sources moved to project folder
      # @return [Boolean] true if empty group was removed; false if group is not empty
      def update_prj_group_for_cmsis(group, config_files, example_src_removal)
        remove_empty_group = true
        group.element_children.each do |element|
          if element.name == 'group'
            remove_empty_group = false unless update_prj_group_for_cmsis(element, config_files, example_src_removal)
          elsif element.name == 'file'
            remove_empty_group = false unless update_prj_file_for_cmsis(element, config_files, example_src_removal)
          elsif element.name != 'name' # ignore group name
            remove_empty_group = false
          end
        end
        group.remove if remove_empty_group
        return remove_empty_group
      end

      # Update all project groups: remove config files and copy files from non-project folder
      # @param [Array<String>] config_files: name of config files
      # @param [ExampleSrcRemoval] example_src_removal: helper class to remove unused sources moved to project folder
      # @return [nil]
      def update_all_prj_files_for_cmsis(config_files, example_src_removal)
        @xml.xpath('/project/group').each do |group|
          update_prj_group_for_cmsis(group, config_files, example_src_removal)
        end
      end

      # Set Board Support SDK Project Template component in project file and move files to RTE folder
      # @param [Array<String>] component_files: Absolute path to Board_project_template files
      # @param [CmsisCompVector] cmsis_id_vector: CMSIS ID vector with board project template
      # @param [String] device_part_number: device part name with core Pname
      # @param [ExampleSrcRemoval] example_src_removal: helper class to remove unused sources moved to project folder
      def add_project_template_files(component_files, cmsis_id_vector, device_part_number, example_src_removal)
        component_text = '<group><name>' + cmsis_id_vector.c_class + ' ' + cmsis_id_vector.c_group + '</name>' \
                         '<tag>CMSISPack.Component</tag></group>'
        component_node = Nokogiri.XML(component_text)
        configuration_node = component_node.at_xpath('/group')
        component_files_name = []
        component_files.each do |path|
          source = File.basename(path)
          component_files_name.push(source)
          file_node = Nokogiri::XML::Node.new('file', @xml)
          configuration_node << file_node
          name_node = Nokogiri::XML::Node.new('name', @xml)
          component_path = cmsis_id_vector.c_class.sub(' ', '_')
          if device_part_number.empty?
            name_node.content = '$PROJ_DIR$\\RTE\\' + component_path + '\\' + source
            board_template_dst = 'RTE/' + component_path
          else
            name_node.content = '$PROJ_DIR$\\RTE\\' + component_path + '\\' + device_part_number + '\\' + source
            board_template_dst = 'RTE/' + component_path + '/' + device_part_number
          end
          file_node << name_node
          destination = File.join(@xml_path, board_template_dst)
          copy_file_to_example(destination, path)
        end
        update_all_prj_files_for_cmsis(component_files_name, example_src_removal)
        @group_node << component_node.xpath('/group')
        @xml.at_xpath('/project') << @group_node
      end

      # Set Board Support SDK Project Template component in project file
      # @param [CmsisCompVector] cmsis_id_vector: board project template component CMSIS ID vect, nil if board project
      #                                           template is not generated into the projects
      # @param [Array<String>] component_files: Absolute path to Board_project_template files
      # @param [ExampleSrcRemoval] example_src_removal: helper class to remove unused sources moved to project folder
      # @return [nil]
      def add_cmsis_pack_component(cmsis_id_vector, component_files, example_src_removal)
        @group_node = Nokogiri::XML::Node.new('group', @xml)
        name_node = Nokogiri::XML::Node.new('name', @xml)
        tag_node = Nokogiri::XML::Node.new('tag', @xml)
        name_node.content = 'CMSIS-Pack'
        tag_node.content = 'CMSISPack.ComponentGroup'
        @group_node << name_node
        @group_node << tag_node

        if cmsis_id_vector.nil?
          # Board prj template is not automatically added into the project (see the CmsisExampleConvertor constructor)
          update_all_prj_files_for_cmsis([], example_src_removal)
          return
        end

        add_project_template_files(component_files, cmsis_id_vector, '', example_src_removal)
      end

      def exclude_building(target, path, exclude, *args, **kargs)
        path, group = @operations.path_div path
        if exclude && @operations.targets.include?(target)
          option_node = @operations.create_option_node_for_src("//project/#{group}/file[name=\"#{path}\"]/excluded")
          sub_node = Nokogiri::XML::Node.new('configuration', @xml)
          sub_node.content = target
          option_node << sub_node
        end
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

      # make all sub classes private
      private

      # Group of common xml operations
      class DocumentOperations

        attr_reader :xml
        attr_reader :targets
        attr_reader :groups
        attr_reader :logger

        def initialize(xml, *args, logger: nil, **kwargs)
          # init attributes
          @all_hash       = Hash.new
          @xml            = xml
          @logger         = logger
          @targets        = {}
          @groups         = {}
          # Load all available targets in XML document and
          # mark them with no-used flag !
          nodes = @xml.xpath('/project/configuration')
          nodes.each do | target_node |
            name_node = target_node.at_xpath("name")
            Core.assert(!name_node.nil?) do
              "missing '<name>' node"
            end
            # and use stripped version of target name
            target = name_node.content.strip.downcase
            name_node.content = target
            @targets[ target ] = {
              'node'  => target_node,
              'used'  => false
            }
          end
        end

        # Add source file into 'vdirexpr' directory
        # ==== arguments
        # path      - name of target
        # vdirexpr  - string, virtual dir expression
        def add_source(path, vdirexpr)
          Core.assert(path.is_a?(String) && !path.empty?) do
            "param must be non-empty string"
          end
          vdirexpr = 'src' if vdirexpr.nil?
          vdirexpr = '.' if vdirexpr == './'
          @group_node = create_group(vdirexpr)
          file_node = Nokogiri::XML::Node.new("file", @xml)
          @group_node << file_node
          name_node = Nokogiri::XML::Node.new("name", @xml)
          name_node.content = path
          file_node << name_node
          @all_hash[vdirexpr] = @group_node
        end

        # Add source file into 'vdirexpr' directory
        # ==== arguments
        # path      - name of target
        # vdirexpr  - string, virtual dir expression
        def add_comfiguration(target, folder, optlevel)
          if @all_hash.keys.include?(folder)
            configuration_node = Nokogiri::XML::Node.new("configuration", @xml)
            @all_hash[folder] << configuration_node
            configuration_name = Nokogiri::XML::Node.new("name", @xml)
            configuration_name.content = target.strip.downcase
            configuration_node << configuration_name

            configuration_setting = Nokogiri::XML::Node.new("settings", @xml)
            configuration_setting.content = @xml.at_xpath("/project/configuration/settings[name=\"ICCARM\"]")
            configuration_node << configuration_setting.text

            value = optlevel.split(' -')[1]
            optlevel = optlevel.split(' -')[0]
            convert = {'On' => 0, 'Ol' => 1, 'Om' => 2, 'Oh' => 3}
            set_state_node(
              target, "/project/group[name =\"#{folder}\"]/configuration/settings[name=\"ICCARM\"]/data/option[name=\"CCOptLevel\"]/state", convert_enum(optlevel, convert), used: true
            )
            set_state_node(
              target, "/project/group[name =\"#{folder}\"]/configuration/settings[name=\"ICCARM\"]/data/option[name=\"CCOptLevelSlave\"]/state", convert_enum(optlevel, convert), used: true
            )
            if optlevel == 'Oh' && value != nil
              strategy_convert = {'Sbalance' => 0, 'Ssize' => 1, 'Sspeed' => 2}
              set_state_node(
                target, "/project/group[name =\"#{folder}\"]/configuration/settings[name=\"ICCARM\"]/data/option[name=\"CCOptStrategy\"]/state", convert_enum(value, strategy_convert), used: true
              )
              set_state_node(
                target, "./project/group[name =\"#{folder}\"]/configuration/settings[name=\"ICCARM\"]/data/option[name=\"CCOptStrategySlave\"]/state", convert_enum(value, strategy_convert), used: true
              )
            end

            node = get_state_node(target, "/project/group[name =\"#{folder}\"]/configuration/settings[name=\"ICCARM\"]/data/option[name=\"CCAllowList\"]/state",  used: true)
            bit = ['0', '0', '0', '0', '0', '0', '0']
            bit = ['1', '1', '1', '1', '1', '1', '1'] if optlevel == 'Oh'
            bit = ['1', '0', '0', '1', '0', '1', '0'] if optlevel == 'Om'
            node.content = bit.join()
          end
        end

        # Add cc-include path into 'vdirexpr' directory
        # ==== arguments
        # target    - name of target
        # folder    - string, virtual dir expression
        # ccinclude - the folder include path
        def add_specific_ccinclude(target, folder, ccinclude)
          if @all_hash.keys.include?(folder) && !@all_hash[folder].at_xpath("/project/group[name =\"#{folder}\"]/configuration/name")

            configuration_node = Nokogiri::XML::Node.new("configuration", @xml)
            @all_hash[folder] << configuration_node
            configuration_name = Nokogiri::XML::Node.new("name", @xml)
            configuration_name.content = target.strip.downcase
            configuration_node << configuration_name

            configuration_setting = Nokogiri::XML::Node.new("settings", @xml)
            configuration_setting.content = @xml.at_xpath("/project/configuration/settings[name=\"ICCARM\"]")
            configuration_node << configuration_setting.text
            collection = target_node(target, used: true).xpath("/project/group[name =\"#{folder}\"]/configuration/settings[name=\"ICCARM\"]/data/option[name=\"CCIncludePath2\"]/state")
            collection.remove() unless (collection.nil?)
          end
          if @all_hash.keys.include?(folder)
            create_option_state_node(
              target, "/project/group[name =\"#{folder}\"]/configuration/settings[name=\"ICCARM\"]/data/option[name=\"CCIncludePath2\"]", convert_string(ccinclude), used: true
            )
          end
        end

        # Create (it not exists) and return group node based on 'vdirexpr'
        # ==== arguments
        # vdirexpr  - virtual dir expression/path
        def create_group(vdirexpr)
          return if vdirexpr.nil?
          # replace ':' with '/' to keep backward compatibility with old scripts
          vdirexpr = vdirexpr.gsub(':', '/')
          unless (@groups[ vdirexpr ])
            parent_node = @xml.at_xpath('/project')
            # separate expression by '/'
            parts = vdirexpr.split('/')
            parts.each_with_index do | item, index |
              subexpr = parts[0..index].join('/')
              unless (@groups[ subexpr ].nil?)
                parent_node = @groups[ subexpr ]
              else
                @group_node = Nokogiri::XML::Node.new("group", @xml)
                parent_node << @group_node
                name_node = Nokogiri::XML::Node.new("name", @xml)
                name_node.content = item
                @group_node << name_node
                parent_node = @group_node
                @groups[ subexpr ] = @group_node
              end
            end
          end
          @group_node = @groups[ vdirexpr ]
          Core.assert(!@group_node.nil?) do
            "groups are broken"
          end
          return @group_node
        end

        def clear_sources!()
          collection = @xml.xpath("/project/group")
          collection.remove() unless(collection.nil?)
          @groups = {}
        end

        # Remove all unused target nodes - marged by unused flags
        def clear_unused_targets!()
          @targets.each do | target_key, target_item |
            if (target_item[ 'used' ] == false)
              target_item[ 'node' ].remove
              @targets.delete(target_key)
            end
          end
        end

        def get_target_name(target, *args, used: false, **kwargs)
          target_node = target_node(target, used: used)
          name_node = target_node.at_xpath("name")
          Core.assert(!name_node.nil?) { "missing 'name' node" }
          return name_node.content
        end

        def set_target_name(target, value, *args, used: false, update_table: false, **kwargs)
          Core.assert(!update_table) { "not implemented" }
          target_node = target_node(target, used: used)
          name_node = target_node.at_xpath("name")
          Core.assert(!name_node.nil?) { "missing 'name' node" }
          name_node.content = value
        end

        # Get target node by target name and change it's flag to used
        # ==== arguments
        # target    - name of target
        def target_node(target, used: nil)
          Core.assert(target.is_a?(String) && !target.empty?) do
            "param must be non-empty string"
          end
          Core.assert(!used.nil?) do
            "used cannot be a nil"
          end
          target = target.strip.downcase
          Core.assert(@targets.has_key?(target)) do
            "target '#{target}' is not present. use one of: #{@targets.keys}"
          end
          Core.assert(!@targets[ target ][ 'node' ].nil?) do
            "name '#{target}' does not exist"
          end
          @targets[ target ][ 'used' ] = true if (used)
          return @targets[ target ][ 'node' ]
        end

        # Set content of '<state>' node by 'xpath' expression
        # ==== arguments
        # target    - name of target
        # xpath     - xpath expression
        # value     - content of '<state>' node
        def set_state_node(target, xpath, value, used: nil)
          Core.assert(target.is_a?(String) && !target.empty?) do
            "param must be non-empty string"
          end
          Core.assert(xpath.is_a?(String) && !xpath.empty?) do
            "param must be non-empty string"
          end
          state_node = target_node(target, used: used).at_xpath(xpath)
          if state_node.nil?
            # puts "nodeset does not exist '#{xpath}'"
            return
          end
          state_node.content = value.to_s
        end

        def set_node_value(path, value)
          return unless value
          state_node = @xml.at_xpath(path)
          return if state_node.nil?
          state_node.content = value
        end

        def set_state_node_nocheck(target, xpath, value, used: nil)
          Core.assert(target.is_a?(String) && !target.empty?) do
            "param must be non-empty string"
          end
          Core.assert(xpath.is_a?(String) && !xpath.empty?) do
            "param must be non-empty string"
          end
          state_node = target_node(target, used: used).at_xpath(xpath)
          if state_node.nil?
            # puts "nodeset does not exist '#{xpath}'"
            return
          end
          state_node.content = value.to_s

        end

        # Get '<state>' node by 'xpath' expression
        # ==== arguments
        # target    - name of target
        # xpath     - xpath expression
        def get_state_node(target, xpath, used: nil)
          Core.assert(target.is_a?(String) && !target.empty?) do
            "param must be non-empty string"
          end
          Core.assert(xpath.is_a?(String) && !xpath.empty?) do
            "param must be non-empty string"
          end
          state_node = target_node(target, used: used).at_xpath(xpath)
          Core.assert(!state_node.nil?) do
            "nodeset does not exist '#{xpath}'"
          end
          return state_node
        end

        # Add new '<state>value</state>' node inside '<option>'
        # node matched by 'xpath' expression
        # ==== arguments
        # target    - name of target
        # xpath     - xpath expression
        # value     - content of '<state>' node
        def create_option_state_node(target, xpath, value, used: nil)
          Core.assert(target.is_a?(String) && !target.empty?) do
            "param must be non-empty string"
          end
          Core.assert(xpath.is_a?(String) && !xpath.empty?) do
            "param must be non-empty string"
          end
          option_node = target_node(target, used: used).at_xpath(xpath)
          Core.assert(!option_node.nil?) do
            "nodeset does not exist '#{xpath}'"
          end
          state_node = Nokogiri::XML::Node.new("state", @xml)
          state_node.content = value.to_s
          option_node << state_node
        end

        def create_build_action_node(target, xpath, cmd, stage, used: nil)
          Core.assert(target.is_a?(String) && !target.empty?) do
            "param must be non-empty string"
          end
          Core.assert(xpath.is_a?(String) && !xpath.empty?) do
            "param must be non-empty string"
          end
          actions_node = target_node(target, used: used).at_xpath(xpath)
          Core.assert(!actions_node.nil?) do
            "nodeset does not exist '#{xpath}'"
          end

          build_action_node = Nokogiri::XML::Node.new('buildAction', @xml)
          cmd_node = Nokogiri::XML::Node.new('cmdline', @xml)
          cmd_node.content = cmd
          sequence_node = Nokogiri::XML::Node.new('buildSequence', @xml)
          sequence_node.content = stage
          build_action_node << cmd_node
          build_action_node << sequence_node

          actions_node << build_action_node
        end

        #  -------------------------------------------------------------------------------------
        # remove empty node
        # @param [String] target: target name
        # @param [String] xpath: Node under xpath will be checked
        # @param [String] used: indicate whether target is used or not
        # @return [Nil]
        def remove_empty_options!(target, xpath, used: false)
          option_node = target_node(target, used: used).xpath(xpath)
          option_node&.each do |each|
            each.remove if each.content.empty?
          end
        end

        # -------------------------------------------------------------------------------------
        # Create new node recursively if node does not exist
        # @param [String] xpath: xpath expression
        # @return [Nokogiri::XML::Element]: the created node of the xpath
        def create_option_node_for_src(xpath)
          option_node = @xml.at_xpath(xpath)
          if (option_node.nil?)
            matched = xpath.match(/^(.*)\/([^\/]+)/)
            Core.assert(!matched.nil?) do
              "corrupted xpath #{xpath}"
            end
            parent_xpath, node_name = matched.captures
            parent_node = @xml.at_xpath(parent_xpath)
            if parent_node.nil?
              parent_node = create_option_node_for_src(parent_xpath)
            end
            Core.assert(!parent_node.nil?) do
              "not such a node #{parent_xpath}"
            end
            matched = node_name.match(/(\S+)\[(\S+)=\"(\S+)\"\]/)
            if matched
              option_node_name, sub_node_name, sub_node_value = matched.captures
              option_node = Nokogiri::XML::Node.new(option_node_name, @xml)
              # sub_node does not need to add if exists
              unless @xml.at_xpath(parent_xpath + "/" + node_name)
                sub_node = Nokogiri::XML::Node.new(sub_node_name, @xml)
                sub_node.content = sub_node_value
                option_node << sub_node
              end
            else
              option_node = Nokogiri::XML::Node.new(node_name, @xml)
            end
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
          return convert[ value ]
        end

        def convert_boolean(value)
          Core.assert(value.is_a?(TrueClass) || value.is_a?(FalseClass)) do
            "conversion error, value '#{value}' must be a 'true' or 'false'"
          end
          return value ? '1' : '0'
        end

        def path_div(path)
          group = []
          path, vdir = path.split('/virtual-dir/')
          vdir.tr(':','/').split('/').each {group.concat(['group'])}
          [path, group.join('/')]
        end
      end


      # Base tab class to inherit @operations attribute
      class TabBase
        attr_reader :operations
        def initialize(operations)
          @operations = operations
        end
      end


      # Used only for namespace purpose
      class GeneralTab < TabBase

        # Contains operations of "TargetTab"
        class TargetTab < TabBase

          private
          # Set fpu option
          # ==== arguments
          # target    - name of target
          # value     - 'none', 'vfpv4_sp_d16', 'vfpv5_sp_16'
          def fpu(target, value, *args, used: true, **kargs)
            convert_v743 = {'none' => 0, 'vfpv4' => 5, 'vfpv4_sp' => 4, 'vfpv4_sp_d16' => 4, 'vfpv5_sp_d16' => 6, 'vfpv5_sp' => 6,'vfpv5_dp_d16' => 7, 'vfpv5_d16'=> 7}
            convert_v742 = {'none' => 0, 'vfpv4' => 6, 'vfpv4_sp' => 5, 'vfpv4_sp_d16' => 5, 'vfpv4_d16' => 5, 'vfpv5_sp_d16' => 12, 'vfpv5_sp' => 12, 'vfpv5_dp_d16' => 13, 'vfpv5_d16'=> 1}
            nr_regs_convert = {'none' => 0, 'vfpv4' => 2, 'vfpv4_sp' => 1, 'vfpv4_sp_d16' => 1, 'vfpv5_sp_d16' => 1, 'vfpv5_dp_d16' => 1,  'vfpv5_d16'=> 1, 'vfpv5_sp' => 1}
            @operations.set_state_node_nocheck(
              target, "./settings[name=\"General\"]/data/option[name=\"FPU2\"]/state", @operations.convert_enum(value, convert_v743), used: used
            )
            @operations.set_state_node_nocheck(
              target, "./settings[name=\"General\"]/data/option[name=\"NrRegs\"]/state", @operations.convert_enum(value, nr_regs_convert), used: used
            )
            @operations.set_state_node_nocheck(
              target, "./settings[name=\"General\"]/data/option[name=\"FPU\"]/state", @operations.convert_enum(value, convert_v742), used: used
            )
          end

          # Set cpu core option
          # ==== arguments
          # target    - name of target
          # value     - 'cortex-m4', 'cortex-m0', 'cortex-m0+', 'cortex-a5'
          def core(target, value, *args, used: true, **kargs)
            convert = {'cortex-m4' => 39, 'cortex-m4f' => 40, 'cortex-m7' => 41,'cortex-m0' => 34, 'cortex-m0+' => 35, 'cortex-a5' => 47, 'cortex-a5.neon' => 47, 'cortex-a7' => 50, 'cortex-m33' => 58}
            @operations.set_state_node_nocheck(
              target, "./settings[name=\"General\"]/data/option[name=\"Variant\"]/state", @operations.convert_enum(value, convert), used: used
            )
            @operations.set_state_node(
              target, "./settings[name=\"General\"]/data/option[name=\"CoreVariant\"]/state", @operations.convert_enum(value, convert), used: used
            )
            #@operations.set_state_node(
            #    target, "./settings[name=\"General\"]/data/option[name=\"Variant\"]/state", @operations.convert_enum(value, convert), used: used
            #)
            @operations.set_state_node_nocheck(
              target, "./settings[name=\"General\"]/data/option[name=\"GFPUCoreSlave\"]/state", @operations.convert_enum(value, convert), used: used
            )

            @operations.set_state_node_nocheck(
              target, "./settings[name=\"General\"]/data/option[name=\"GFPUCoreSlave2\"]/state", @operations.convert_enum(value, convert), used: used
            )
            @operations.set_state_node_nocheck(
              target, "./settings[name=\"General\"]/data/option[name=\"GBECoreSlave\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end

          def endian(target, value, *args, used: true, **kargs)
            convert = {'little' => 0, 'l' => 0, 'big' => 1, 'b' => 1}
            @operations.set_state_node(
              target, "settings[name=\"General\"]/data/option[name=\"GEndianMode\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end

          def device(target, value, *args, used: true, **kargs)
            @operations.set_state_node_nocheck(target, "settings[name=\"General\"]/data/option[name=\"OGChipSelectEditMenu\"]/state","#{value}", used: used)
            @operations.set_state_node_nocheck(target, "settings[name=\"General\"]/data/option[name=\"GFPUDeviceSlave\"]/state","#{value}", used: used)
          end

          def use_core_variant(target, value, *args, used: true, **kargs)
            @operations.set_state_node_nocheck(target, "settings[name=\"General\"]/data/option[name=\"OGCoreOrChip\"]/state", "#{value}", used: used)
          end

          def trustZone(target, value, *args, used: true, **kargs)
            convert = {'no_se' => 0}
            @operations.set_state_node(
              target, "settings[name=\"General\"]/data/option[name=\"TrustZone\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end

          def secure(target, value,*args, used: true, **kargs)
            convert = {'--cmse' => 0}
            @operations.set_state_node(
              target, "settings[name=\"General\"]/data/option[name=\"TrustZoneModes\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end

          def dspExtension(target, value,*args, used: true, **kargs)
            convert = {'no_dsp' => 0}
            @operations.set_state_node(
              target, "settings[name=\"General\"]/data/option[name=\"DSPExtension\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end
        end


        # Contains operations of "OutputTab"
        class OutputTab < TabBase

          private

          # Select type of output format
          # ==== arguments
          # target    - name of target
          # value     - 'executable', 'library'
          def output_type(target, value, *args, used: true, **kargs)
            convert = {'executable' => 0, 'library' => 1}
            @operations.set_state_node(
              target, "./settings[name=\"General\"]/data/option[name=\"RTDescription\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end

          # Select output directory
          # ==== arguments
          # target    - name of target
          # value     - path to directory
          def output_dir(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"General\"]/data/option[name=\"ExePath\"]/state", @operations.convert_string(value), used: used
            )
          end

          # Select .o files directory
          # ==== arguments
          # target    - name of target
          # value     - path to directory
          def object_files_dir(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"General\"]/data/option[name=\"ObjPath\"]/state", @operations.convert_string(value), used: used
            )
          end

          # Select .lst files directory
          # ==== arguments
          # target    - name of target
          # value     - path to directory
          def list_files_dir(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"General\"]/data/option[name=\"ListPath\"]/state", @operations.convert_string(value), used: used
            )
          end
        end


        class LibraryConfigurationTab < TabBase

          def library(target, value, *args, used: true, **kargs)
            convert = {
              'none'    => 0,
              'normal'  => 1,
              'full'    => 2,
              'custom'  => 3,
            }
            @operations.set_state_node(
              target, "./settings[name=\"General\"]/data/option[name=\"GRuntimeLibSelect\"]/state", @operations.convert_enum(value, convert), used: used
            )
            @operations.set_state_node(
              target, "./settings[name=\"General\"]/data/option[name=\"GRuntimeLibSelectSlave\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end

          def library_configuration_file(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"General\"]/data/option[name=\"RTConfigPath2\"]/state", @operations.convert_string(value), used: used
            )
          end

          def use_cmsis(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"General\"]/data/option[name=\"OGUseCmsis\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          def use_cmsis_dsp(target, value, *args, used: true, **kargs)
            use_cmsis(target, value, *args, used: used, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"General\"]/data/option[name=\"OGUseCmsisDspLib\"]/state", @operations.convert_boolean(value), used: used
            )
          end

        end


        class LibraryOptionsTab < TabBase

          def printf_formatter(target, value, *args, used: true, **kargs)
            convert = {
              'auto'        => 0,
              'full'        => 1,
              'full_no_mb'  => 2,
              'large'       => 3,
              'large_no_mb' => 4,
              'small'       => 5,
              'small_no_mb' => 6,
              'tiny'        => 7,
            }
            content = @operations.set_state_node(
              target, "./settings[name=\"General\"]/data/option[name=\"Output variant\"]/state", @operations.convert_enum(value, convert), used: used
            )
            # IAR 9.30 has different setting in.ewp file
            if content.nil?
              convert = {
                'auto'        => 0,
                'full'        => 1,
                'full_no_mb'  => 1,
                'large'       => 2,
                'large_no_mb' => 2,
                'small'       => 3,
                'small_no_mb' => 3,
                'tiny'        => 4,
              }
              @operations.set_state_node(
                target, "./settings[name=\"General\"]/data/option[name=\"OGPrintfVariant\"]/state", @operations.convert_enum(value, convert), used: used
              )
            end
          end

          def scanf_formatter(target, value, *args, used: true, **kargs)
            convert = {
              'auto'        => 0,
              'full'        => 1,
              'full_no_mb'  => 2,
              'large'       => 3,
              'large_no_mb' => 4,
              'small'       => 6,
              'small_no_mb' => 7,
            }
            content = @operations.set_state_node(
              target, "./settings[name=\"General\"]/data/option[name=\"Input variant\"]/state", @operations.convert_enum(value, convert), used: used
            )
            # IAR 9.30 has different setting in.ewp file
            if content.nil?
              convert = {
                'auto'        => 0,
                'full'        => 1,
                'full_no_mb'  => 1,
                'large'       => 2,
                'large_no_mb' => 2,
                'small'       => 3,
                'small_no_mb' => 3
              }
              @operations.set_state_node(
                target, "./settings[name=\"General\"]/data/option[name=\"OGScanfVariant\"]/state", @operations.convert_enum(value, convert), used: used
              )
            end
          end

          def buffered_terminal_output(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"General\"]/data/option[name=\"OGBufferedTerminalOutput\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          def enable_semihosted(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
                target, "./settings[name=\"General\"]/data/option[name=\"GenLowLevelInterface\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          def redirect_swo(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
                target, "./settings[name=\"General\"]/data/option[name=\"GenStdoutInterface\"]/state", @operations.convert_boolean(value), used: used
            )
          end
        end

        # Contains operations of "MISRA-C2004Tab"
        class MisraC2004Tab < TabBase

          # Enable "MISRA-C"
          # ==== arguments
          # target    - name of target
          # value     - false, true
          def enable_misra(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"General\"]/data/option[name=\"GeneralEnableMisra\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          # Set version of "MISRA-C"
          # ==== arguments
          # target    - name of target
          # value     - '2004', '1998'
          def misra_version(target, value, *args, used: true, **kargs)
            convert = {'2004' => 0, '1998' => 1}
            @operations.set_state_node(
              target, "./settings[name=\"General\"]/data/option[name=\"GeneralMisraVer\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end
        end
      end


      # Used only for namespace purpose
      class CompilerTab < TabBase

        # Contains operations of "Language1Tab"
        class Language1Tab < TabBase

          private

          # Set compiler language
          # ==== arguments
          # target    - name of target
          # value     - 'c', 'c++', 'auto'_based on extension
          def language(target, value, *args, used: true, **kargs)
            convert = {'c' => 0, 'cpp' => 1, 'c++' => 1, 'auto' => 2}
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"IccLang\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end

          # Set c language dialect
          # ==== arguments
          # target    - name of target
          # value     - 'c89', 'c99'
          def c_dialect(target, value, *args, used: true, **kargs)
            convert = {'c89' => 0, 'c99' => 1}
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"IccCDialect\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end

          # Enable c++ inline semantic
          # ==== arguments
          # target    - name of target
          # value     - false, true
          def cpp_inline_semantic(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"IccCppInlineSemantics\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          # Set "allow_vla" checkbox
          # ==== arguments
          # target    - name of target
          # value     - true, false
          def allow_vla(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"IccAllowVLA\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          # Enable "require prototypes"
          # ==== arguments
          # target    - name of target
          # value     - false, true
          def require_prototypes(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCRequirePrototypes\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          # Enable conformance
          # ==== arguments
          # target    - name of target
          # value     - 'extension', 'standard', 'strict'
          def comformance(target, value, *args, used: true, **kargs)
            convert = {'extension' => 0, 'standard' => 1, 'strict' => 2}
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCLangConformance\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end

          # Enable conformance
          # ==== arguments
          # target    - name of target
          # value     - 'extension', 'standard', 'strict'
          def cpp_dialect(target, value, *args, used: true, **kargs)
            convert = {'embedded' => 0, 'extended' => 1, 'full' => 2}
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"IccCppDialect\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end

          # Enable "C++ with exceptions"
          # ==== arguments
          # target    - name of target
          # value     - false, true
          def cpp_with_exceptions(target, value, *args, used: true, **kargs)
            cpp_dialect(target, "full") if (value)
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"IccExceptions\"]/state", @operations.convert_boolean(value), used: used
            )
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"IccExceptions2\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          # Enable "C++ with RTTI"
          # ==== arguments
          # target    - name of target
          # value     - false, true
          def cpp_with_rtti(target, value, *args, used: true, **kargs)
            cpp_dialect(target, "full") if (value)
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"IccRTTI\"]/state", @operations.convert_boolean(value), used: used
            )
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"IccRTTI2\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          # Enable "destroy static objects"
          # ==== arguments
          # target    - name of target
          # value     - false, true
          def destroy_static_objects(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"IccStaticDestr\"]/state", @operations.convert_boolean(value), used: used
            )
          end
        end


        # Contains operations of "Language2Tab"
        class Language2Tab < TabBase

          private

          def plain_char(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCSignedPlainChar\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          def float_semantic(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"IccFloatSemantics\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          def mutlibyte(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCMultibyteSupport\"]/state", @operations.convert_boolean(value), used: used
            )
          end
        end


        # Contains operations of "CodeTab"
        class CodeTab < TabBase

          private

          # Enable interworking
          # ==== arguments
          # target    - name of target
          # value     - true, false
          def interwork_code(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"IInterwork2\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          # Select processor mode
          # ==== arguments
          # target    - name of target
          # value     - 'arm', 'thumb'
          def processor_mode(target, value, *args, used: true, **kargs)
            convert = {'arm' => 0, 'thumb' => 1}
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"IProcessorMode2\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end
        end


        # Contains operations of "OptimizationTab"
        class OptimizationTab < TabBase

          private

          # Select optimization level
          # ==== arguments
          # target    - name of target
          # value     - 'none', 'low', 'medium', 'high'
          def level(target, value, *args, used: true, **kargs)
            convert = {'none' => 0, 'low' => 1, 'medium' => 2, 'high' => 3}
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCOptLevel\"]/state", @operations.convert_enum(value, convert), used: used
            )
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCOptLevelSlave\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end

          def level_for_src(target, path, value, *args, used: true, **kargs)
            path, group = @operations.path_div path
            convert = {'none' => 0, 'low' => 1, 'medium' => 2, 'high' => 3}
            option_node = @operations.create_option_node_for_src("//project/#{group}/file[name=\"#{path}\"]/configuration[name=\"#{target}\"]/settings[name=\"ICCARM\"]/data/option[name=\"CCOptLevel\"]/state")
            option_node.content = @operations.convert_enum(value, convert)
            option_node = @operations.create_option_node_for_src("//project/#{group}/file[name=\"#{path}\"]/configuration[name=\"#{target}\"]/settings[name=\"ICCARM\"]/data/option[name=\"CCOptLevelSlave\"]/state")
            option_node.content = @operations.convert_enum(value, convert)
          end

          # Select optimization strategy
          # ==== arguments
          # target    - name of target
          # value     - 'balanced', 'size', 'speed'
          def strategy(target, value, *args, used: true, **kargs)
            convert = {'balance' => 0, 'size' => 1, 'speed' => 2}
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCOptStrategy\"]/state", @operations.convert_enum(value, convert), used: used
            )
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCOptStrategySlave\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end

          def strategy_for_src(target, path, value, *args, used: true, **kargs)
            path, group = @operations.path_div path
            convert = {'balance' => 0, 'size' => 1, 'speed' => 2}
            option_node = @operations.create_option_node_for_src("//project/#{group}/file[name=\"#{path}\"]/configuration[name=\"#{target}\"]/settings[name=\"ICCARM\"]/data/option[name=\"CCOptStrategy\"]/state")
            option_node.content = @operations.convert_enum(value, convert)
            option_node = @operations.create_option_node_for_src("//project/#{group}/file[name=\"#{path}\"]/configuration[name=\"#{target}\"]/settings[name=\"ICCARM\"]/data/option[name=\"CCOptStrategySlave\"]/state")
            option_node.content = @operations.convert_enum(value, convert)
          end

          def high_strategy(target, value, *args, used: true, **kargs)
            strategy = 3
            convert = {'balance' => 0, 'size' => 1, 'speed' => 2}
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCOptLevel\"]/state", strategy, used: used
            )
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCOptLevelSlave\"]/state", strategy, used: used
            )
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCOptStrategy\"]/state", @operations.convert_enum(value, convert), used: used
            )
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCOptStrategySlave\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end

          def high_strategy_for_src(target, path, value, *args, used: true, **kargs)
            path, group = @operations.path_div path
            strategy = 3
            convert = {'balance' => 0, 'size' => 1, 'speed' => 2}
            option_node = @operations.create_option_node_for_src("//project/#{group}/file[name=\"#{path}\"]/configuration[name=\"#{target}\"]/settings[name=\"ICCARM\"]/data/option[name=\"CCOptLevel\"]/state")
            option_node.content = strategy
            option_node = @operations.create_option_node_for_src("//project/#{group}/file[name=\"#{path}\"]/configuration[name=\"#{target}\"]/settings[name=\"ICCARM\"]/data/option[name=\"CCOptLevelSlave\"]/state")
            option_node.content = strategy
            option_node = @operations.create_option_node_for_src("//project/#{group}/file[name=\"#{path}\"]/configuration[name=\"#{target}\"]/settings[name=\"ICCARM\"]/data/option[name=\"CCOptStrategy\"]/state")
            option_node.content = @operations.convert_enum(value, convert)
            option_node = @operations.create_option_node_for_src("//project/#{group}/file[name=\"#{path}\"]/configuration[name=\"#{target}\"]/settings[name=\"ICCARM\"]/data/option[name=\"CCOptStrategySlave\"]/state")
            option_node.content = @operations.convert_enum(value, convert)
          end

          # Select optimization nosize_constraints
          # ==== arguments
          # target    - name of target
          # value     - 'no size constraints'
          def enable_nosize_constraints(target, value, *args, used: true, **kargs)
            convert = {false => 0, true => 1}
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCOptimizationNoSizeConstraints\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end

          def enable_nosize_constraints_for_src(target, path, value, *args, used: true, **kargs)
            path, group = @operations.path_div path
            convert = {false => 0, true => 1}
            option_node = @operations.create_option_node_for_src("//project/#{group}/file[name=\"#{path}\"]/configuration[name=\"#{target}\"]/settings[name=\"ICCARM\"]/data/option[name=\"CCOptimizationNoSizeConstraints\"]/state")
            option_node.content = @operations.convert_enum(value, convert)
          end
          # Enable/disable size constraints
          # ==== arguments
          # target    - name of target
          # value     - false, true
          def enable_no_size_constraints(target, value, *args, used: true, **kargs)
            convert = {false => 0, true => 1}
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCOptimizationNoSizeConstraints\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end                # Enable/disable subexpression elimination
          # ==== arguments
          # target    - name of target
          # value     - false, true
          def enable_subexp_elimination(target, value, *args, used: true, **kargs)
            set_ccallow_list_index(target, @operations.convert_boolean(value), 0, used: used)
          end

          # Enable/disable loop unrolling
          # ==== arguments
          # target    - name of target
          # value     - false, true
          def enable_loop_unrolling(target, value, *args, used: true, **kargs)
            set_ccallow_list_index(target, @operations.convert_boolean(value), 1, used: used)
          end

          # Enable/disable function inlining
          # ==== arguments
          # target    - name of target
          # value     - false, true
          def enable_func_inlining(target, value, *args, used: true, **kargs)
            set_ccallow_list_index(target, @operations.convert_boolean(value), 2, used: used)
          end

          # Enable/disable code motion
          # ==== arguments
          # target    - name of target
          # value     - false, true
          def enable_code_motion(target, value, *args, used: true, **kargs)
            set_ccallow_list_index(target, @operations.convert_boolean(value), 3, used: used)
          end

          # Enable/disable alias analysis
          # ==== arguments
          # target    - name of target
          # value     - false, true
          def enable_alias_analysis(target, value, *args, used: true, **kargs)
            set_ccallow_list_index(target, @operations.convert_boolean(value), 4, used: used)
          end

          # Enable/disable static clustering
          # ==== arguments
          # target    - name of target
          # value     - false, true
          def enable_static_clustering(target, value, *args, used: true, **kargs)
            set_ccallow_list_index(target, @operations.convert_boolean(value), 5, used: used)
          end

          # Enable/disable instruction scheduling
          # ==== arguments
          # target    - name of target
          # value     - false, true
          def enable_instruction_scheduling(target, value, *args, used: true, **kargs)
            set_ccallow_list_index(target, @operations.convert_boolean(value), 6, used: used)
          end

          # Enable/disable vectorization
          # method is supported by IAR version 7.x and higher
          # ==== arguments
          # target    - name of target
          # value     - false, true
          def enable_vectorization(target, value, *args, used: true, **kargs)
            set_ccallow_list_index(target, @operations.convert_boolean(value), 7, used: used)
          end

          # Setup optimization bitfield
          # ==== arguments
          # target    - name of target
          # value     - false, true
          # value     - integer, <0,6>
          def set_ccallow_list_index(target, value, index, *args, used: true, **kargs)
            value = value.to_i()
            index = index.to_i()
            Core.assert(value == 0 || value == 1) do
              "value '#{value}' is not in range <0,1>"
            end
            Core.assert(index >= 0 && index <= 7) do
              "index '#{index}' is not in range <0,6>"
            end
            node = @operations.get_state_node(target, "settings[name=\"ICCARM\"]/data/option[name=\"CCAllowList\"]/state", used: used)
            bitfield = node.content.split(//)
            bitfield[ index ] = value.to_s
            node.content = bitfield.join()
          end
        end


        # Contains operations of "OutputTab"
        class OutputTab < TabBase

          private

          # Enable/disable generating debug information
          # ==== arguments
          # target    - name of target
          # value     - false, true
          def debug_info(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCDebugInfo\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          # Set name of code section
          # ==== arguments
          # target    - name of target
          # value     - string
          def codesection_name(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCCodeSection\"]/state", @operations.convert_string(value), used: used
            )
          end
        end


        # Contains operations of "PreprocessorTab"
        class PreprocessorTab < TabBase

          private

          # Add include path
          # ==== arguments
          # target    - name of target
          # value     - include path
          def add_include(target, value, *args, used: true, **kargs)
            value = @operations.convert_string(value)
            path = "./settings[name=\"ICCARM\"]/data/option[name=\"CCIncludePath2\"]"
            return if @operations.get_state_node(target, path, used: used).content&.split('$PROJ_DIR$').include? (value.gsub('$PROJ_DIR$', ''))
            @operations.create_option_state_node(
              target, path, value, used: used
            )
          end

          # Clear all include paths
          # ==== arguments
          # target    - name of target
          def clear_include!(target, *args, used: false, **kargs)
            # clear do not set used target
            collection = @operations.target_node(target, used: used).xpath("./settings[name=\"ICCARM\"]/data/option[name=\"CCIncludePath2\"]/state")
            collection.remove() unless (collection.nil?)
          end

          # Add include path
          # ==== arguments
          # target    - name of target
          # value     - include path
          def add_define(target, value, *args, used: true, **kargs)
            @operations.create_option_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCDefines\"]", @operations.convert_string(value), used: used
            )
          end

          # Clear all include paths
          # ==== arguments
          # target    - name of target
          def clear_defines!(target, *args, used: false, **kargs)
            # clear do not set used target
            collection = @operations.target_node(target, used: used).xpath("./settings[name=\"ICCARM\"]/data/option[name=\"CCDefines\"]/state")
            collection.remove() unless (collection.nil?)
          end

          # Enable/disable ignoring standard include paths
          # ==== arguments
          # target    - name of target
          # value     - true, false
          def ignore_standard_include(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCStdIncCheck\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          def add_pre_include(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"PreInclude\"]/state", value, used: used
            )
          end
        end


        # Contains operations of "DiagnosticTab"
        class DiagnosticTab < TabBase

          private

          # Add suppression code
          # ==== arguments
          # target    - name of target
          # value     - string
          def add_suppress(target, value, *args, used: true, **kargs)
            value = @operations.convert_string(value)
            state_node = @operations.get_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCDiagSuppress\"]/state", used: used
            )
            state_node.content = state_node.content.empty? ? value : "#{state_node.content},#{value}"
          end

          # Set suppression code
          # ==== arguments
          # target    - name of target
          # value     - string
          def set_suppress(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCDiagSuppress\"]/state", @operations.convert_string(value), used: used
            )
          end

          # Treat all warnings as errors
          # ==== arguments
          # target    - name of target
          # value     - boolean
          def treat_warnings_as_errors(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"CCDiagWarnAreErr\"]/state", @operations.convert_boolean(value), used: used
            )
          end
        end

        # Contains operations of "ExtraOptionTab"
        class ExtraOptionTab < TabBase

          def initialize(operations)
            super(operations)
            @extra_options = {}
          end

          private

          # Set suppression code
          # ==== arguments
          # target    - name of target
          # value     - string
          def use_commandline(target, value, *args, used: true, **kargs)
            @extra_options[target] = [] unless @extra_options.key? target
            @extra_options[target].push_uniq value
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"IExtraOptionsCheck\"]/state", "1", used: used
            )
            @operations.set_state_node(
              target, "./settings[name=\"ICCARM\"]/data/option[name=\"IExtraOptions\"]/state", @operations.convert_string(@extra_options[target].join(' ')), used: used
            )
          end

          # Set suppression code for file
          # ==== arguments
          # target[String]    - name of target
          # path[String]      - relative path of source file
          # value[String]     - the value to be set
          # @return nil
          def use_commandline_for_src(target, path, value, *args, used: true, **kargs)
            path, group = @operations.path_div path
            option_node = @operations.create_option_node_for_src("//project/#{group}/file[name=\"#{path}\"]/configuration[name=\"#{target}\"]/settings[name=\"ICCARM\"]/data/option[name=\"IExtraOptionsCheck\"]/state")
            option_node.content = "1"
            option_node = @operations.create_option_node_for_src("//project/#{group}/file[name=\"#{path}\"]/configuration[name=\"#{target}\"]/settings[name=\"ICCARM\"]/data/option[name=\"IExtraOptions\"]/state")
            option_node.content = @operations.convert_string(value)
          end
        end
      end


      # Used only for namespace purpose
      class AssemblerTab < TabBase

        # Contains operations of "LanguageTab"
        class LanguageTab < TabBase

          private

          # Enable/disable case sensitivity
          # ==== arguments
          # target    - name of target
          # value     - true, false
          def allow_case_sensitivity(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"AARM\"]/data/option[name=\"ACaseSensitivity\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          # Enable/disable multibyte support
          # ==== arguments
          # target    - name of target
          # value     - true, false
          def enable_multibyte(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"AARM\"]/data/option[name=\"AMultibyteSupport\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          # Select quote character
          # ==== arguments
          # target    - name of target
          # value     - '()', '[]', '{}', '<>'
          def macro_quote_character(target, value, *args, used: true, **kargs)
            convert = {'()' => 0, '[]' => 1, '{}' => 2, '<>' => 3}
            @operations.set_state_node(
              target, "./settings[name=\"AARM\"]/data/option[name=\"MacroChars\"]/state", @operations.convert_enum(value, convert), used: used
            )
          end

          # Enable/disable alternative names support
          # ==== arguments
          # target    - name of target
          # value     - true, false
          def allow_alternative_names(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"AARM\"]/data/option[name=\"AltRegisterNames\"]/state", @operations.convert_boolean(value), used: used
            )
          end
        end


        # Contains operations of "OutputTab"
        class OutputTab < TabBase

          private

          # Enable/disable generating debug information
          # ==== arguments
          # target    - name of target
          # value     - true, false
          def debug_info(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"AARM\"]/data/option[name=\"ADebug\"]/state", @operations.convert_boolean(value), used: used
            )
          end
        end


        # Contains operations of "PreprocessorTab"
        class PreprocessorTab < TabBase

          private

          # Add include path
          # ==== arguments
          # target    - name of target
          # value     - include path
          def add_include(target, value, *args, used: true, **kargs)
            value = @operations.convert_string(value)
            path = "./settings[name=\"AARM\"]/data/option[name=\"AUserIncludes\"]"
            # filter duplicated path
            return if @operations.get_state_node(target, path, used: used).content&.split('$PROJ_DIR$').include? (value.gsub('$PROJ_DIR$', ''))
            @operations.create_option_state_node(
              target, path, value, used: used
            )
          end

          # Clear all include paths
          # ==== arguments
          # target    - name of target
          def clear_include!(target, *args, used: false, **kargs)
            # clear do not set used target
            collection = @operations.target_node(target, used: used).xpath("./settings[name=\"AARM\"]/data/option[name=\"AUserIncludes\"]/state")
            collection.remove() unless(collection.nil?)
          end

          # Ignore standard include paths
          # ==== arguments
          # target    - name of target
          # value     - include path
          def ignore_standard_include(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"AARM\"]/data/option[name=\"AIgnoreStdInclude\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          # Add define
          # ==== arguments
          # target    - name of target
          # value     - macro in 'name=value' format
          def add_define(target, value, *args, used: true, **kargs)
            @operations.create_option_state_node(
              target, "./settings[name=\"AARM\"]/data/option[name=\"ADefines\"]", @operations.convert_string(value), used: used
            )
          end

          # Clear all define macros
          # ==== arguments
          # target    - name of target
          def clear_defines!(target, *args, used: false, **kargs)
            # clear do not set used target
            collection = @operations.target_node(target, used: used).xpath("./settings[name=\"AARM\"]/data/option[name=\"ADefines\"]/state")
            collection.remove() unless(collection.nil?)
          end
        end


        # Contains operations of "DiagnosticTab"
        class DiagnosticTab < TabBase

          private

          # Enable/disable showing warnings
          # ==== arguments
          # target    - name of target
          # value     - true, false
          def enable_warnings(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"AARM\"]/data/option[name=\"AWarnEnable\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          # todo: add remaining fn
        end

        # Contains operations of "ExtraOptionTab"
        class ExtraOptionTab < TabBase

          private

          # Set suppression code
          # ==== arguments
          # target    - name of target
          # value     - string
          def use_commandline(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"AARM\"]/data/option[name=\"AExtraOptionsCheckV2\"]/state", "1", used: used
            )
            @operations.set_state_node(
              target, "./settings[name=\"AARM\"]/data/option[name=\"AExtraOptionsV2\"]/state", @operations.convert_string(value), used: used
            )
          end
        end
      end

      # Used only for namespace purpose
      class OutputConverterTab < TabBase

        # Contains operations of additional output settings
        class OutputTab < TabBase

          private

          # Enable generate additional output
          # ==== arguments
          # target    - name of target
          # value     - string, true or false
          def enable_additional_output(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"OBJCOPY\"]/data/option[name=\"OOCObjCopyEnable\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          # Setting output format
          # ==== arguments
          # target    - name of target
          # value     - string, format names:
          #             srec: Motorola
          #             hex : Intel extended
          #             txt : Texas Instruments TI-TXT,
          #             bin : binary
          #             sim : simple
          def set_output_format(target, value, *args, used: true, **kargs)
            convert = { 'srec' => 0, 'hex' => 1, 'txt' => 2, 'bin' => 3, 'sim' => 4}
            @operations.set_state_node(
              target, "./settings[name=\"OBJCOPY\"]/data/option[name=\"OOCOutputFormat\"]/state", @operations.convert_enum(value, convert), used: used
            )
            @operations.set_state_node(
              target, "./settings[name=\"OBJCOPY\"]/data/option[name=\"OOCOutputFormat\"]/version", @operations.convert_string("3"), used: used
            )
          end

          # Enable override default output files
          # ==== arguments
          # target    - name of target
          # value     - string, true or false
          def enable_override_default_output(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"OBJCOPY\"]/data/option[name=\"OCOutputOverride\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          # Setting override output file names
          # ==== arguments
          # target    - name of target
          # value     - string, override output file names
          def set_override_output_file(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"OBJCOPY\"]/data/option[name=\"OOCOutputFile\"]/state", @operations.convert_string(value), used: used
            )
          end
        end
      end

      # Used only for namespace purpose
      class BuildActionTab < TabBase

        # Contains operations of "DiagnosticTab"
        class ConfigurationTab < TabBase

          private

          # Add prebuild command
          # ==== arguments
          # target    - name of target
          # value     - string, command
          def prebuild_command(target, value, *args, used: true, **kargs)
            node = @operations.create_option_node_for_src("//project/configuration[name=\"#{target}\"]/settings[name=\"BUILDACTION\"]/data/buildActions")
            Core.assert(!node.nil?) do
              "cannot find node"
            end

            @operations.create_build_action_node(
              target, "./settings[name=\"BUILDACTION\"]/data/buildActions", @operations.convert_string(value), 'preCompile', used: used
            )
          end

          # Add postbuild command
          # ==== arguments
          # target    - name of target
          # value     - string, command
          def postbuild_command(target, value, *args, used: true, **kargs)
            node = @operations.create_option_node_for_src("//project/configuration[name=\"#{target}\"]/settings[name=\"BUILDACTION\"]/data/buildActions")
            Core.assert(!node.nil?) do
              "cannot find node"
            end

            @operations.create_build_action_node(
              target, "./settings[name=\"BUILDACTION\"]/data/buildActions", @operations.convert_string(value), 'postLink', used: used
            )
          end
        end
      end


      # Used only for namespace purpose
      class LibraryBuilderTab < TabBase

        # Contains operations of "DiagnosticTab"
        class OutputTab < TabBase

          private

          # Enable/disable overriding default output binary file
          # ==== arguments
          # target    - name of target
          # value     - true, false
          def override_default(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"IARCHIVE\"]/data/option[name=\"IarchiveOverride\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          # Set output binary file
          # ==== arguments
          # target    - name of target
          # value     - string, path
          def output_file(target, value, *args, used: true, **kargs)
            override_default(target, true)
            @operations.set_state_node(
              target, "./settings[name=\"IARCHIVE\"]/data/option[name=\"IarchiveOutput\"]/state", @operations.convert_string(value), used: used
            )
          end
        end
      end


      # Used only for namespace purpose
      class LinkerTab < TabBase

        # Contains operations of "DiagnosticTab"
        class ConfigTab < TabBase

          private

          # Enable/disable overriding default linker command file
          # ==== arguments
          # target    - name of target
          # value     - true, false
          def override_default(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkIcfOverride\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          # Set linker command file
          # ==== arguments
          # target    - name of target
          # value     - string, path
          def configuration_file(target, value, *args, used: true, **kargs)
            override_default(target, true)
            @operations.set_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkIcfFile\"]/state", @operations.convert_string(value), used: used
            )
          end

          def configuration_file_defines(target, value, *args, used: true, **kargs)
            @operations.create_option_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkConfigDefines\"]", @operations.convert_string(value), used: used
            )
          end

          def clear_configuration_file_defines!(target, *args, used: false, **kargs)
            # clear do not set used target
            collection = @operations.target_node(target, used: used).xpath("./settings[name=\"ILINK\"]/data/option[name=\"IlinkConfigDefines\"]/state")
            collection.remove() unless(collection.nil?)
          end
        end


        # Contains operations of "DiagnosticTab"
        class LibraryTab < TabBase

          private

          # Add library
          # ==== arguments
          # target    - name of target
          # value     - string, path
          def add_library(target, value, *args, used: true, **kargs)
            @operations.create_option_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkAdditionalLibs\"]", @operations.convert_string(value), used: used
            )
          end

          # Clear all libraries
          # ==== arguments
          # target    - name of target
          def clear_libraries!(target, *args, used: false, **kargs)
            # clear do not set used target
            collection = @operations.target_node(target, used: used).xpath("./settings[name=\"ILINK\"]/data/option[name=\"IlinkAdditionalLibs\"]/state")
            collection.remove() unless(collection.nil?)
          end

          def override_default_program_entry(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkOverrideProgramEntryLabel\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          def entry_symbol(target, value, *args, used: true, **kargs)
            check_entry_symbol(target, false)
            @operations.set_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkProgramEntryLabel\"]/state", @operations.convert_string(value), used: used
            )
          end

          def defined_by_application(target, value, *args, used: true, **kargs)
            check_entry_symbol(target, true)
          end

          private

          def check_entry_symbol(target, value, *args, used: true, **kargs)
            override_default_program_entry(target, true)
            @operations.set_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkProgramEntryLabelSelect\"]/state", @operations.convert_boolean(value), used: used
            )
          end
        end


        class InputTab < TabBase

          private

          def add_keep_symbol(target, value, *args, used: true, **kargs)
            @operations.create_option_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkKeepSymbols\"]", @operations.convert_string(value), used: used
            )
          end

          def clear_keep_symbols!(target, *args, used: true, **kargs)
            # clear do not set used target
            collection = @operations.target_node(target, used: used).at_xpath("./settings[name=\"ILINK\"]/data/option[name=\"IlinkKeepSymbols\"]/state")
            collection.remove if collection && collection.content.empty?
          end

          def set_raw_binary_image_file(target, value, *args, used: true, **kargs)
            state_node = @operations.target_node(target, used: used).at_xpath("./settings[name=\"ILINK\"]/data/option[name=\"IlinkRawBinaryFile\"]/state")
            if state_node.nil?
              @operations.create_option_state_node(
                target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkRawBinaryFile\"]", @operations.convert_string(value), used: used
              )
            else
              @operations.set_state_node(
                target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkRawBinaryFile\"]/state", @operations.convert_string(value), used: used)
            end
          end

          def set_raw_binary_image_symbol(target, value, *args, used: true, **kargs)
            state_node = @operations.target_node(target, used: used).at_xpath("./settings[name=\"ILINK\"]/data/option[name=\"IlinkRawBinarySymbol\"]/state")
            if state_node.nil?
              @operations.create_option_state_node(
                target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkRawBinarySymbol\"]", @operations.convert_string(value), used: used
              )
            else
              @operations.set_state_node(
                target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkRawBinarySymbol\"]/state", @operations.convert_string(value), used: used)
            end
          end
          def set_raw_binary_image_section(target, value, *args, used: true, **kargs)
            state_node = @operations.target_node(target, used: used).at_xpath("./settings[name=\"ILINK\"]/data/option[name=\"IlinkRawBinarySegment\"]/state")
            if state_node.nil?
              @operations.create_option_state_node(
                target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkRawBinarySegment\"]", @operations.convert_string(value), used: used
              )
            else
              @operations.set_state_node(
                target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkRawBinarySegment\"]/state", @operations.convert_string(value), used: used)
            end
          end
          def set_raw_binary_image_align(target, value, *args, used: true, **kargs)
            state_node = @operations.target_node(target, used: used).at_xpath("./settings[name=\"ILINK\"]/data/option[name=\"IlinkRawBinaryAlign\"]/state")
            if state_node.nil?
              @operations.create_option_state_node(
                target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkRawBinaryAlign\"]", @operations.convert_string(value), used: used
              )
            else
              @operations.set_state_node(
                target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkRawBinaryAlign\"]/state", @operations.convert_string(value), used: used)
            end
          end

          def set_raw_binary_image(target, value, *args, used: true, **kargs)
            order = value['order'] == 0 ? '' : '2'
            # set path
            state_node = @operations.create_option_node_for_src("//project/configuration[name=\"#{target}\"]/settings[name=\"ILINK\"]/data/option[name=\"IlinkRawBinaryFile#{order}\"]/state")
            state_node.content = value['source']
            if value['symbol']
              state_node = @operations.create_option_node_for_src("//project/configuration[name=\"#{target}\"]/settings[name=\"ILINK\"]/data/option[name=\"IlinkRawBinarySymbol#{order}\"]/state")
              state_node.content = value['symbol']
            end
            if value['section']
              state_node = @operations.create_option_node_for_src("//project/configuration[name=\"#{target}\"]/settings[name=\"ILINK\"]/data/option[name=\"IlinkRawBinarySegment#{order}\"]/state")
              state_node.content = value['section']
            end
            if value['align']
              state_node = @operations.create_option_node_for_src("//project/configuration[name=\"#{target}\"]/settings[name=\"ILINK\"]/data/option[name=\"IlinkRawBinaryAlign#{order}\"]/state")
              state_node.content = value['align']
            end
          end
        end


        class OutputTab < TabBase

          private

          # Set output binary file
          # ==== arguments
          # target    - name of target
          # value     - string, path
          def output_filename(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkOutputFile\"]/state", @operations.convert_string(value), used: used
            )
          end

          # Enable/disable generating debug information
          # ==== arguments
          # target    - name of target
          # value     - true, false
          def debug_info(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkDebugInfoEnable\"]/state", @operations.convert_boolean(value), used: used
            )
          end

          def set_tz_import_lib(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkTrustzoneImportLibraryOut\"]/state", @operations.convert_string(value), used: used
            )
          end
        end

        class ChecksumTab < TabBase
          private

          #Enable/disable the checksum
          def enable_checksum(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"DoFill\"]/state", @operations.convert_boolean(value), used: used
            )
          end
          def fillerbyte(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"FillerByte\"]/state", value, used: used
            )
          end
          def fillerstart(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"FillerStart\"]/state", value, used: used
            )
          end
          def fillerend(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"FillerEnd\"]/state", value, used: used
            )
          end

        end


        class ExtraOptionTab < TabBase

          private

          def add_command_option(target, value, *args, used: true, **kargs)
            @operations.set_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkUseExtraOptions\"]/state", "1", used: used
            )
            @operations.create_option_state_node(
              target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkExtraOptions\"]", @operations.convert_string(value), used: used
            )
          end

          def clear_command_options!(target, value, *args, used: false, **kargs)
            # clear do not set used target
            collection = @operations.target_node(target, used: used).xpath("./settings[name=\"ILINK\"]/data/option[name=\"IlinkExtraOptions\"]/state")
            collection.remove() unless(collection.nil?)
          end

          def clear_empty_command_options!(target, *args, used: false, **kargs)
            @operations.remove_empty_options!(target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkExtraOptions\"]/state", used: used)
          end
        end

        class DiagnosticTab < TabBase

          private

          def set_suppress(target, value, *args, used: true, **kargs)
            if @operations.target_node(target, used: used).at_xpath("./settings[name=\"ILINK\"]/data/option[name=\"IlinkSuppressDiags\"]/state")
              @operations.set_state_node(
                target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkSuppressDiags\"]/state", @operations.convert_string(value), used: used
              )
            else
              @operations.create_option_state_node(
                target, "./settings[name=\"ILINK\"]/data/option[name=\"IlinkSuppressDiags\"]", @operations.convert_string(value), used: used
              )
            end
          end
        end
      end
    end

  end
end
