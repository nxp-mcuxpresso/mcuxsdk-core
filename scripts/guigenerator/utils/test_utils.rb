# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
require 'nokogiri'
require 'fileutils'

# ********************************************************************
# Useful test utilities for PDSC tests
module TestUtils

  # Execute yield block passed as argument for all example projects for IAR and MDK
  # @param [Hash] examples: list of examples to be tested, key is name of the example, value is path to the example root
  # The block gets the following arguments:
  # [String] name: of the example
  # [String] ext: file extension of the project file
  # [String] path_no_ext: absolute path to the project file without extension
  def self.for_all_examples_projects(examples)
    examples.each do |name, path|
      yield(name, 'ewp',     path + '/iar/' + name + '.')
      yield(name, 'uvprojx', path + '/mdk/' + name + '.')
    end
  end

  # --------------------------------------------------------
  # Update release notes in <releases> in PDSC from cmsis-pack-history-updated folder
  # @param [String] pdsc_path: absolute path to the PDSC file
  # @param [String] updated_pack_rev: absolute path to the cmsis pack history updated yml file
  def self.update_release_notes(pdsc_path, updated_pack_rev)
    release_history = File.exist?(updated_pack_rev) ? YAML.load_file(updated_pack_rev) : []
    if release_history.empty?
      puts 'Missing updated yml file in cmsis-pack-history-updated folder \'' + updated_pack_rev + '\''
      exit(1)
    end

    xml = Nokogiri::XML(File.open(pdsc_path), &:noblanks)
    xml.xpath('/package/releases/release').each(&:remove)
    release_notes = xml.at_xpath('/package/releases')
    release_history.each do |release|
      release_node = Nokogiri::XML::Node.new('release', xml)
      release_node.content = release['description']
      release_node['version'] = release['version']
      release_node['date'] = release['date']
      release_notes << release_node
    end
    File.open(pdsc_path, 'w') do |handler|
      handler.print(xml.to_xml)
      handler.close
    end
  end

  # Check if all described files in project file exist
  # @param [String] project_file_path: absolute path to the project file
  def self.check_files_location(project_file_path)
    xml = Nokogiri::XML(File.open(project_file_path), &:noblanks)
    extension = File.extension(project_file_path)
    if extension == 'ewp'
      project_files = xml.xpath('//group/file/name')
      project_files.each do |project_file|
        file_path = File.join(File.dirname(project_file_path), project_file.content.sub('$PROJ_DIR$', '').tr('\\', '/'))
        unless File.exist? file_path
          puts 'File ' + project_file.content + ' not exist'
          exit(1)
        end
      end
    elsif extension == 'uvprojx'
      project_files = xml.xpath('//Group/Files/File/FilePath').map(&:content)
      rte_files = xml.xpath('/Project/RTE/files/file/instance').map(&:content)
      (project_files | rte_files).each do |project_file|
        unless File.exist?(File.join(File.dirname(project_file_path), project_file.tr('\\', '/')))
          puts 'File ' + project_file + ' not exist'
          exit(1)
        end
      end
    else
      puts 'Project file path have not supported extension'
      exit(1)
    end
  end

  # Generate files for regression test
  # @param [String] datatable_dir_path: path to datatable directory
  def self.generate_test_files(datatable_dir_path)
    path = File.join(datatable_dir_path, 'list_of_files.yml')
    list_of_files = YAML.load_file(path)
    list_of_files.fetch('files_to_create').each do |file_path|
      file_path = File.expand_path(File.join(datatable_dir_path, file_path))
      unless File.exist?(file_path)
        dir_name = File.dirname(file_path)
        FileUtils.mkdir_p(dir_name) unless File.directory?(dir_name)
        File.new(file_path, 'w').puts('_')
      end
    end
  end
end