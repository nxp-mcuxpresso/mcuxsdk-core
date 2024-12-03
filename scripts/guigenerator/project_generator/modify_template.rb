# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require 'nokogiri'
require 'set'
require 'tempfile'

module SDKGenerator
  module ProjectGenerator
    # ********************************************************************
    # The Compiler template base on xml data
    # ********************************************************************
    class XMLTemplate
      def initialize(template_array, target_need, project_name = '_', sdk_root_dir = '../../../..')
        @template_array = template_array
        @target_need = target_need
        @sdk_root_dir = sdk_root_dir
        @project_name = project_name
      end

      # Get all target name from xml template
      def get_all_target(xml_data, key_separate, tag_name)
        all_target = []
        config_data = xml_data.xpath("//#{key_separate}")
        config_data.each do |target_data|
          all_target.push(target_data.xpath(tag_name.to_s).text.downcase)
        end
        all_target
      end

      # Add new target to file
      def add_target_to_file(file_path, target_name, key_separate, tag_name, tool_key)
        path = file_path.gsub(/\\/) { '/' }
        return false unless File.exist?(path)

        if tool_key == 'codewarrior'
          xml_data = Nokogiri::XML(File.open(path)) {|x| x.noblanks }
          config_data = xml_data.xpath("//#{key_separate}").first
          config_data.children.each do |target_data|
            temp_node = target_data.at_xpath("#{key_separate}")
            next unless temp_node['name'].include? "Target Template"
            next unless target_name.downcase.include?(temp_node['name'].split(' ')[0].downcase)

            clone_target_data = target_data.dup
            # update target name
            clone_target_data.at_xpath("#{key_separate}[\@moduleId=\"#{tag_name}\"]")['name'] = target_name
            target_data.before(clone_target_data)
            break
          end
        else
          file_data = IO.read(path)
          xml_data = Nokogiri::XML(file_data)
          all_target = get_all_target(xml_data, key_separate, tag_name)
          return false if all_target.include?(target_name)
          # Clone target from debug or release target
          clone_target_name = 'debug'
          clone_target_name = 'release' if target_name.downcase.include? 'release'
          config_data = xml_data.xpath("//#{key_separate}")
          config_data.each do |target_data|
            next unless target_data.xpath(tag_name.to_s).text.downcase == clone_target_name
            clone_target_data = target_data.dup
            clone_target_data.at_xpath(tag_name.to_s).content = target_name
            target_data.after(clone_target_data)
            break
          end
        end

        # Rewrite the template file
        File.open(path, 'w') { |handler| handler.print(xml_data.to_xml) }
      end

      # Modify template
      def modify_template(tool_key)
        if tool_key == 'iar'
          @key_separate = 'configuration'
          @tag_name = 'name'
          @match_file = '.ew[p|d]'
        elsif tool_key == 'mdk'
          @key_separate = 'Target'
          @tag_name = 'TargetName'
          @match_file = 'uvoptx|uvprojx'
        elsif tool_key == 'codewarrior'
          @key_separate = 'storageModule'
          @tag_name = 'org.eclipse.cdt.core.settings'
          @match_file = 'cproject$'
        end

        @new_templates = @template_array.dup
        @template_array.each do |template_path|
          next unless template_path.match(@match_file)
          # Change to new template, using tempfile class
          # add project name in temp file name to prevent the possible that tmp file name duplicated
          new_template_path = Tempfile.create([@project_name + File.basename(template_path),
                                               File.extname(template_path)], File.dirname(template_path))
          @new_templates.delete(template_path)
          FileUtils.copy(template_path, new_template_path)
          @new_templates.push(new_template_path.path)
          @target_need.each do |target_name|
            add_target_to_file(new_template_path.path, target_name, @key_separate, @tag_name, tool_key)
          end
        end
        @new_templates
      end
    end

    # ********************************************************************
    # The Cmsis Rte Template base on xml data
    # ********************************************************************
    class CmsisRteTemplate
      def initialize(project_name, project_path, sdk_root_dir,
                     rte_template_path = 'bin/generator/templates/mdk/cmsis_rte/rte')
        @project_name = project_name
        @project_path = project_path
        @rte_template_path = File.join(sdk_root_dir, rte_template_path)
        @rte_node = nil
      end

      def add_cmsis_component(type)
        rte_doc = Nokogiri::XML(IO.read(@rte_template_path), &:noblanks)

        @rte_node = rte_doc.at_xpath('/RTE')
        # Change API node
        api_node = @rte_node.at_xpath('apis/api/targetInfos')
        name = api_node.xpath('targetInfo')
        name.each do |a|
          target = a['name'].split(' ')[-1]
          a['name'] = @project_name + ' ' + target
        end
        # Change compontent node
        components_node = @rte_node.xpath('components/component')
        components_node.each do |component|
          targetinfo_node = component.xpath('targetInfos/targetInfo')
          targetinfo_node.each do |a|
            target = a['name'].split(' ')[-1]
            a['name'] = @project_name + ' ' + target
          end
          # Set the CMSIS validation type
          if (component['Cclass'] == 'CMSIS Driver Validation') && (component['Cgroup'] != 'Framework')
            component['condition'] = "CMSIS Driver Validation API #{type}"
            component['Cgroup'] = type
          end
        end
        # Change files node
        file_node = @rte_node.xpath('files/file')
        file_node.each do |files|
          targetnfo_node = files.xpath('targetInfos/targetInfo')
          targetnfo_node.each do |a|
            target = a['name'].split(' ')[-1]
            a['name'] = @project_name + ' ' + target
          end
        end
      end

      def save
        proj_doc = Nokogiri::XML(IO.read(@project_path), &:noblanks)

        # # Add "::CMSIS" group
        # proj_doc.xpath("/Project/Targets/Target").each do |target_node|
        # groups_node = Nokogiri::XML::Node.new("Groups", proj_doc)
        # group_node = Nokogiri::XML::Node.new("Group", proj_doc)
        # group_name_node = Nokogiri::XML::Node.new("GroupName", proj_doc)
        # group_name_node.content = "::CMSIS"
        # group_node << group_name_node
        # groups_node << group_node
        # target_node << groups_node
        # end

        # Add RTE node into project file
        project_node = proj_doc.at_xpath('/Project')
        project_node << @rte_node

        File.open(@project_path, 'w') do |f|
          f.print(proj_doc.to_xml)
        end
      end
    end
  end
end
# ********************************************************************
# EOF
# ********************************************************************
