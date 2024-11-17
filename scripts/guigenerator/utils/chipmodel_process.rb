# frozen_string_literal: true

# ********************************************************************
# Copyright 2018 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require_relative 'utils'
require_relative 'sdk_consts'

# ********************************************************************
# This class process the device's chipmodel and return all kinds of
# attributes of the device
# ********************************************************************
class ChipmodelProcess
  attr_reader :devices_information
  attr_reader :core_information
  # --------------------------------------------------------
  # Constructor
  # @param [String] datatable_path: The path to the to be processed datatable
  def initialize(datatable_path)
    @chipmodel_content = YAML.load_file(datatable_path)['device.hardware_data']
    @devices_information = @chipmodel_content.dig_with_default({}, 'contents', 'devices')
    @core_information = @devices_information[0]['core']
  end

  # --------------------------------------------------------
  # Returns whether the devices info of this chipmodel data is empty
  def devices_empty?
    @devices_information.empty?
  end

  # --------------------------------------------------------
  # Return the device's ids as an array
  def device_ids
    return [] if devices_empty?
    ids = []
    @devices_information.each { |each_device| ids.push each_device['id'] }
    ids
  end

  # --------------------------------------------------------
  # Return the device's part names as an array
  def device_part_names(id)
    return [] if devices_empty? or not device_ids.include?(id)
    parts = []
    @devices_information.each do |each_device|
      next unless each_device['id'] == id
      each_device['part'].each { |each_part| parts.push each_part['name'] }
    end
    parts
  end

  # --------------------------------------------------------
  # Return the device's fullset id
  def fullset_id
    return @devices_information[0]['id']
  end

  # --------------------------------------------------------
  # Return whether this device is multicore
  def multicore?
    @core_information.length > 1
  end

  # --------------------------------------------------------
  # Return whether this device is homogeneous
  def homogeneous?
    core0_name = @core_information[0]['name']
    @core_information.each { |each_core| return false unless core0_name == each_core['name'] }
    true
  end
end
# ********************************************************************
# EOF
# ********************************************************************
