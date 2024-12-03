# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

# ********************************************************************
#
# ********************************************************************
class ModeFilter
  def initialize(data, logger: nil)
    @data = data
    @logger = logger ? logger : Logger.new(STDOUT)
  end

  # remove enabled
  def remove_enabled(mode)
    process_all_nodes(method(:remove_enabled_node), mode)
  end

  # remove disabled
  def remove_disabled(mode)
    process_all_nodes(method(:remove_disabled_node), mode)
  end

  # clean structure - no 'mode' nodes anymore
  def clean
    process_all_nodes(method(:remove_mode_node))
  end

  private

  # remove parent node if subnode 'mode' has some enabled 'mode' key
  def remove_enabled_node(parent, mode, expression: nil)
    if parent['mode'].nil?
      parent.clear
    elsif parent['mode'].is_a?(Hash)
      status = parent['mode'][mode]
      parent.clear if !status.nil? || status == 1
    else
      Core.assert(false, "unsupported mode type '#{parent['mode'].class.name}'")
    end
  end

  # remove parent node if subnode 'mode' has some disabled 'mode' key
  def remove_disabled_node(parent, mode, expression: nil)
    if parent['mode'].nil?
      parent.clear
    elsif parent['mode'].is_a?(Hash)
      status = parent['mode'][mode]
      parent.clear if status.nil? || status.zero?
    else
      Core.assert(false, "unsupported mode type '#{parent['mode'].class.name}'")
    end
  end

  # remove 'mode' node
  def remove_mode_node(data)
    data.delete('mode') if data['mode']
  end

  def process_paths(paths_data, processfn, *args)
    return unless paths_data
    paths_data.each_with_index do |file, _index|
      processfn.call(file, *args)
    end
  end

  def process_common_modules(modules_data, processfn, *args)
    return unless modules_data
    modules_data.each do |_module_key, module_data|
      # try to remove common-modules node
      processfn.call(module_data, *args)
      next if module_data.empty?
      %w[source-files as-include cc-include cx-include].each do |path_type|
        # try to remove 'source-files', 'as-include', 'cc-include', 'cx-include'
        process_paths(module_data[path_type], processfn, *args)
      end
    end
  end

  def process_tool_modules(modules_data, processfn, *args)
    return unless modules_data
    modules_data.each do |_module_key, module_data|
      # try to remove tool-modules node
      processfn.call(module_data, *args)
      next if module_data.empty?
      %w[source-files as-include cc-include cx-include].each do |path_type|
        # try to remove 'source-files', 'as-include', 'cc-include', 'cx-include'
        process_paths(module_data[path_type], processfn, *args)
      end
    end
  end

  def process_tool_settings(settings_data, processfn, *args)
    return unless settings_data
    settings_data.each do |_tool_key, tool_data|
      # try to remove tool node
      processfn.call(tool_data, *args)
      next if tool_data.empty?
      %w[app-targets lib-targets].each do |target_type|
        next unless tool_data[target_type]
        tool_data[target_type].each do |_target_key, target_data|
          # try to remove app/lib targets
          processfn.call(target_data, *args)
          next if target_data.empty?
          %w[as-include cc-include cx-include].each do |path_type|
            # try to remove 'source-files', 'as-include', 'cc-include', 'cx-include'
            process_paths(target_data[path_type], processfn, *args)
          end
        end
      end
    end
  end

  # loop over structure and apply processfn
  def process_all_nodes(processfn, *args)
    @data.each do |_section_key, section_data|
      # process '{section_key}'
      # expression: "section_key"
      processfn.call(section_data, *args)
      next if section_data.empty?
      # common modules'
      process_common_modules(section_data['common-modules'], processfn, *args) if section_data['common-modules']
      process_tool_modules(section_data['tool-modules'], processfn, *args) if section_data['tool-modules']
      process_tool_settings(section_data['tool-settings'], processfn, *args) if section_data['tool-settings']
    end
  end
end
