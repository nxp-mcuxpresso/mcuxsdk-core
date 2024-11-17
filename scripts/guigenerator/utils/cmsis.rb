# frozen_string_literal: true

# ********************************************************************
# Copyright 2018 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

# Shared constants and classes for CMSIS packs
# ********************************************************************
# CMSIS PDSC constants
# ********************************************************************
module Pdsc
  # [String] default SDK bundle, used for all SDK components, hard-coded
  SDK_BUNDLE = 'MCUXpresso SDK'

  # [String] default NXP vendor
  NXP_VENDOR = 'NXP'

  # [String] NXP vendor with numerical identification
  NXP_VENDOR_COLON_ID = 'NXP:11'

  # [String] File name (with extension) of the PDSC XSD schema
  SCHEMA_FILE_NAME = 'PACK.xsd'
  # [String] PDSC XSD schema version
  SCHEMA_VERSION = '1.4'

  # [String] URL where the NXP packages are published
  NXP_URL = 'https://mcuxpresso.nxp.com/cmsis_pack/repo/'

  #CMSIS Pack supported toolchains
  CMSIS_TOOLCHAINS = %w[iar mdk].freeze
  CMSIS_PACK_SUPPORT_TOOLCHAINS = %w[iar mdk armgcc].freeze

  # core short name map to CMSIS Core definition
  CORE_SHORT_NAME_MAP = {
    'cm0' => 'Cortex-M0',
    'cm0p' => 'Cortex-M0+',
    'cm3' => 'Cortex-M3',
    'cm4f' => 'Cortex-M4',
    'cm4' => 'Cortex-M4',
    'cm7f' => 'Cortex-M7',
    'cm7' => 'Cortex-M7',
    'cm23' => 'Cortex-M23',
    'cm33' => 'Cortex-M33',
    'cm33f' => 'Cortex-M33',
    'ca7' => 'Cortex-A7',
    'ca9' => 'Cortex-A9',
    'ca53' => 'Cortex-A53',
    'ca35' => 'Cortex-A35'
  }.freeze

  SRC_FILTER_CONDITION = ['toolchains', 'cores', 'core_ids', 'fpu', 'compilers', 'components', 'device_ids', 'devices', 'dsp', 'trustzone', 'boards'].freeze
  COMP_FILTER_CONDITION = ['toolchain', 'core', 'core_id', 'fpu', 'compiler', 'device_id', 'device', 'dsp', 'trustzone', 'vendor', 'board', 'kit'].freeze

  def condition_to_s(cond)
    cond.to_s.tr('[', '').tr(']', '').tr('"', '').tr('{','').tr('}', '').tr('>', '')
  end
end

module CMSISHelper
  CMSIS_PDSC_TYPE = [:dfp_pdsc, :bsp_pdsc, :swp_pdsc, :sbsp_pdsc].freeze
  CMSIS_PACK_TYPE = ['dfp', 'bsp', 'swp', 'sbsp'].freeze

  def section_info(content)
    content.dig_with_default({}, 'section_info')
  end

  def cmsis_info(content)
    content.dig_with_default({}, 'section_info', 'product', 'cmsis_pack')
  end

  def comp_pack_info(content)
    cmsis_info(content).dig_with_default({}, 'pack_root')
  end

  def comp_taxonomy_info(content)
    section_info(content).dig_with_default({}, 'taxonomy')
  end

  def is_cmsis_comp?(content)
    info = cmsis_info(content)
    return false if info.empty?
    info.dig_with_default(true, 'supported')
  end

  def is_cmsis_example?(content)
    content.dig_with_default(true, 'contents', 'document', 'support_CMSIS_PACK')
  end

  def csolution_unsupported?(data)
    files = data.dig_with_default([], 'contents', 'modules', 'product_output_csolution', 'files')
    return true if files.empty?

    files.each do |item|
      return false if %w[cproject csolution].include? item['attribute']
    end

    true
  end

  def cmsis_vector(content, section_name, logger)
    taxonomy = comp_taxonomy_info(content)
    cmsis_pack_info = cmsis_info(content)
    cclass = taxonomy['cclass']
    if cclass.nil?
      logger.warn("No cclass found in #{section_name}")
      return []
    end

    cgroup = taxonomy['cgroup']
    if cgroup.nil?
      logger.warn("No cgroup found in #{section_name}")
      return []
    end

    cversion = taxonomy['cversion'] || content.dig_with_default(nil, 'section_info', 'version')
    if cversion.nil?
      logger.warn("No cversion found in #{section_name}")
      return []
    else
      cversion = cversion.to_s
    end
    cbundle = taxonomy['cbundle']
    cbundle_version = taxonomy['cbundle_version']
    cbundle_version = cbundle_version.to_s unless cbundle_version.nil?
    cbundle_description = taxonomy['cbundle_description'] || cbundle
    cbundle_doc = taxonomy['cbundle_doc'] || cbundle
    csub = taxonomy['csub']
    cvariant = taxonomy['cvariant']
    c_default_variant = taxonomy['default_variant']
    c_description = content.dig_with_default(nil, 'section_info', 'description')
    capi = cmsis_pack_info['api'] if cmsis_pack_info.key? 'api'
    if cmsis_pack_info['api']
      capiversion =  cmsis_pack_info['capiversion'] || content.dig_with_default(nil, 'section_info', 'version')
    else
      capiversion =  cmsis_pack_info['capiversion'] if cmsis_pack_info.key? 'capiversion'
    end
    return {:cbundle => cbundle, :cbundle_version => cbundle_version, :cbundle_description=>cbundle_description, :cbundle_doc=>cbundle_doc,
            :cclass => cclass, :cgroup => cgroup, :csub => csub, :cvariant => cvariant, :cversion => cversion,
            :c_default_variant => c_default_variant,:c_description => c_description, :capi => capi, :capiversion => capiversion
    }
  end
  # CMSIS PACK history path
  CMSIS_PACK_HISTORY_PATH = File.join(File.dirname(__FILE__), "../../src/manifest_generator/pdsc_populator/cmsis-pack-rev" ).freeze

  def release_history(pack_name, logger, history_path=nil)
    history_path = CMSIS_PACK_HISTORY_PATH if history_path.nil?
    history_file = File.join(history_path, pack_name + '.yml')
    if File.exist?(history_file)
      return YAML.load_file(history_file)
    else
      require 'find'
      Find.find(File.dirname(history_file)) do |file|
        if File.basename(file).tr('-', '').casecmp?(pack_name+'.yml')
          return YAML.load_file(file)
        end
      end
    end
    logger.info("No history record for #{pack_name} is present in #{history_file}")
    []
  end

  def latest_version_in_history(release_history)
    if release_history.empty?
      [ 0, 0, 0 ]
    else
      version = release_history.map do |pack_info_entry|
        Gem::Version.new(pack_info_entry.dig_with_default('', 'version').to_s)
      end.max.to_s.split('.').map(&:to_i)
    end
  end

  def pack_version_from_set(section_info)
    section_info.dig_with_default(nil, 'product', 'cmsis_pack', 'pack_root', 'pack_version') ||
      section_info.dig_with_default(nil, 'version')
  end

  def update_pack_pdsc(data, set, path)
    data[set][set]['section_info']['product']['cmsis_pack']['pack_root']['pack_pdsc'] = path
  end

  def set_location(data, set)
    data.dig_with_default('', set, set, 'section_info', 'set_location', 'repo_base_path')
  end

  def collect_component_files(data, set)
    files = []
    data[set].each do |section_name, section_content|
      next if section_content['section-type'] != 'component' || !is_cmsis_comp?(section_content)
      section_content.dig_with_default([], 'contents', 'files')&.each {|item| files.push_uniq(item['source']) if item['source'] && !item['generated']}
    end
    files
  end

  def collect_example_files(data, set)
    files = []
    data[set].each do |section_name, section_content|
      next if !['application', 'library'].include?(section_content['section-type']) || !is_cmsis_example?(section_content)
      #TODO  skip project not supported for csolution
      next if @build_option[:generators].keys.include?(:csolution_generate) && csolution_unsupported?(section_content)
      section_content.dig_with_default({}, 'contents', 'modules')&.each do |mod_name, mod_content|
        next unless mod_content.safe_key?('files')
        next if mod_content['external_component']
        mod_content['files']&.each {|item| files.push_uniq(item['source']) if item['source'] && !item['generated']}
      end
    end
    files
  end

  def collect_container_files(data, set, type=nil)
    files = []
    data[set]&.each do |section_name, section_content|
      next if section_content['section-type'] != 'container'
      section_content.dig_with_default([], 'contents', 'files')&.each do |item|
        if item['source'] && !item['generated']
          if type && item.key?('type')
            next if item['type'] != type
          end
          files.push_uniq(item['source'])
        end
      end
    end
    files
  end

  def device_specific?(content)
    if content.safe_key? 'belong_to'
      if content['belong_to'].is_a? String
        belong_to = content['belong_to']
      elsif content['belong_to'].is_a? Hash
        belong_to = content['belong_to']['cmsis_pack']
      else
        belong_to = ''
      end
      if belong_to == "set.device.#{@option[:device]}"
        return true
      end
    end
    false
  end

  def board_kit_specific?(content)
    if content.safe_key? 'belong_to'
      if content['belong_to'].is_a? String
        belong_to = content['belong_to']
      elsif content['belong_to'].is_a? Hash
        belong_to = content['belong_to']['cmsis_pack']
      else
        belong_to = ''
      end
      if belong_to.include?("set.board.#{@option[:board]}") || belong_to.include?("set.kit.#{@option[:board]}")
        return true
      end
    end
    false
  end
end
# ********************************************************************
# CMSIS PACK ID vector
# ********************************************************************
class CmsisPackVector
  # [String] CMSIS pack name
  attr_reader :name

  # [String] CMSIS vendor
  attr_reader :vendor

  # [String] URL where the CMSIS pack is published; nil if not known
  attr_reader :url

  # --------------------------------------------------------
  # Constructor
  # @param [String] name: CMSIS pack name where the component is located
  # @param [String] vendor: CMSIS vendor
  # @param version_proc: string or function returning version of the CMSIS pack; parameter of the function: name
  #     The function is used to retrieve info lazy, as for SDK_components generation it is not needed and into in
  #       release_config.yml is not available
  # @param [Boolean] external: true if it is reference to external CMSIS pack; false if it is generated pack
  # @param [String] url: where the CMSIS pack is published. nil if not known
  def initialize(name, vendor, version_proc, external, url)
    Utils.assert !name.nil? && !vendor.nil? && !version_proc.nil?, 'unexpected nil'
    @name = name
    @vendor = vendor
    @version_proc = version_proc
    @external = external
    @url = url
  end

  # --------------------------------------------------------
  # @return [Boolean] external: true if it is reference to external CMSIS pack; false if it is generated pack
  def external_ref?
    return @external
  end

  # --------------------------------------------------------
  # @return [String] version of the CMSIS pack
  def version
    return @version_proc if @version_proc.is_a?(String)

    return @version_proc.call(name) # retrieve lazy
  end

  # --------------------------------------------------------
  # @return [String] string representation of the class for logging and debugging
  def to_s
    return "CMSIS-pack{name=`#{name}`,version=`#{version}`,vendor=`#{vendor}`,url=`#{url}`"
  end

  # --------------------------------------------------------
  # Overrides the default implementation of == operator
  # @param [CmsisPackVector] other: CmsisPackVector whose values should be compared to the current one
  # @return [Bool] true if two CmsisPackVector objects' attributes are the same, false otherwise
  def ==(other)
    Utils.assert(other.is_a?(CmsisPackVector), 'Could not compare a CmsisPackVector with a ' + other.class.to_s)
    return @name == other.name && @url == other.url && @vendor == other.vendor
  end

end

# ********************************************************************
# CMSIS COMP ID vector
# ********************************************************************
class CmsisCompVector
  # [String] CMSIS bundle
  attr_reader :c_bundle

  # [String] CMSIS class
  attr_reader :c_class

  # [String] CMSIS group
  attr_reader :c_group

  # [String] CMSIS sub group; nil if not defined
  attr_reader :c_sub

  # [String] CMSIS variant; nil if not defined
  attr_reader :c_variant

  # [String] CMSIS version of the component
  attr_reader :version

  # [String] CMSIS API version of the component; nil if not available
  attr_reader :apiversion

  # [CmsisPackVector] CMSIS pack ID vector
  attr_reader :pack

  # --------------------------------------------------------
  # Constructor
  # @param [String] c_bundle: CMSIS bundle
  # @param [String] c_class: CMSIS class
  # @param [String] c_group: CMSIS group
  # @param [String] c_sub: CMSIS sub group; nil if not defined
  # @param [String] c_variant: CMSIS variant; nil if not defined
  # @param [String] version: component version
  # @param [String] apiversion: API component version; nil if not assigned
  #                 https://www.keil.com/pack/doc/CMSIS/Pack/html/pdsc_apis_pg.html
  # @param [CmsisPackVector] pack: CMSIS pack ID vector
  def initialize(c_bundle, c_class, c_group, c_sub, c_variant, version, apiversion, pack)
    Utils.assert !c_bundle.nil? && !c_class.nil? && !c_group.nil? && !version.nil? && !pack.nil?,
                 'unexpected nil'
    @c_bundle = c_bundle
    @c_class = c_class
    @c_group = c_group
    @c_sub = c_sub
    @c_variant = c_variant
    @version = version
    @apiversion = apiversion
    @pack = pack
  end

  # @return [String] CMSIS pack name
  def pack_name
    return pack.name
  end

  # --------------------------------------------------------
  # @return [String] CMSIS vendor
  def c_vendor
    return pack.vendor
  end

  # --------------------------------------------------------
  # @return [String] URL where the CMSIS pack is published; nil if not known
  def url
    return pack.url
  end

  # @return [String] CMSIS pack version
  def pack_version
    return pack.version
  end

  # --------------------------------------------------------
  # @return [String] string representation of the class for logging and debugging
  def to_s
    return "CMSIS{class=`#{c_class}`,group=`#{c_group}`,sub=`#{c_sub}`,variant=`#{c_variant}`,bundle=`#{c_bundle}`\
           ,vendor=`#{c_vendor}`,version=`#{version}`,#{pack}}"
  end
end
