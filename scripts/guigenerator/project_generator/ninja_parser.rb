# Copyright 2024, 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
require 'logger'
require 'json'
require 'pathname'
require 'fileutils'
require 'deep_merge'
require_relative '../utils/utils'
require_relative '../utils/sdk_utils'
class NinjaParser
  include SDKGenerator::SDKUtils
  REPO_ROOT_PATH = File.expand_path(File.join(File.dirname(__FILE__), '../../..'))
  NO_GUI_TEMPLATE_TOOLCHAIN = %w[armgcc xcc xclang]

  def initialize(ninja, name, toolchain, config, outdir, logger)
    @logger = Logger.new(STDOUT)
    @ninja = ninja
    @name = name
    @toolchain = toolchain
    @config = config
    @outdir = outdir
    @logger = logger
    @data = prepare_data(name, toolchain, config, outdir)
  end

  def process
    read_ninja
    parse_cc_flags
    parse_cx_flags
    parse_as_flags
    parse_ld_flags
    parse_source
    parse_header
    parse_libraries
    parse_as_include_path
    parse_cc_include_path
    parse_prebuild
    parse_postbuild
    parse_precompile
    merge_ide_data
    remove_unsupported_config
    {"set.board.#{ENV['board']}" => @data}
  end

  def prepare_data(name, toolchain, config, outdir)
    data = {
      @name => {
        'section-type' => ENV['project_type']  == 'LIBRARY' ? 'library' : 'application',
        'required' => true,
        'belong_to' => "set.board.#{ENV['board']}",
        'contents' => {
          'configuration' => {
            'tools'=> {
              toolchain => {
                'config' => {
                  config => {
                    'identity' => config,
                    'target' => config,
                    'cc-define' => {},
                    'cx-define' => {},
                    'as-define' => {},
                    'as-flags' => [],
                    'cc-flags' => [],
                    'cx-flags' => [],
                    'ld-flags' => [],
                    'cp-define' => {},
                  }
                }
              }
            }
          },
          'document' => {
            'name' => @name,
            'platform_devices_soc_name' => ENV['device'],
            'board' => ENV['board'],
            'core' => ENV['core'],
            'core_id' => ENV['core_id'],
            'fpu' => ENV['fpu'],
            'dsp' => ENV['dsp'],
            'trustzone' => ENV['trustzone'],
            'toolchains' => [toolchain],
            'compilers' => [get_compiler(toolchain)]
          },
          # Use build dir as gui porject root dir to short output path, because IDE such as mdk/iar may report too deep path error
          # it can also simply toolchain setting
          'project-root-path' => ".",
          'modules' => {
            'demo' => {
              'required' => true,
              'cc-include' => [],
              'as-include' => [],
              'files' => [],
            }
          }
        },
        'dependency' => [],
        'project_tags' => name,
        'depended_set' => []
      }
    }
    if ENV['IDE_TEMPLATE'] == 'undefined'
      raise "ERROR: IDE template is not defined, please add it by mcux_set_ide_template function"
    end
    data
  end

  def get_project_root_path
    root_folder = File.dirname(File.expand_path(File.join(__FILE__, "../../.."))).split(File::SEPARATOR).last
    path_parts = ENV['APPLICATION_SOURCE_DIR'].split(File::SEPARATOR)
    index = path_parts.rindex(root_folder)
    result = if index
      File.join(path_parts[index + 1..-1])
    else
      @name
    end
    if ENV['is_multicore_device'] == 'y'
      File.join(result, ENV['core_id'])
    else
      result
    end
  end

  def read_ninja
    @content = []
    begin
      file = File.open(@ninja, 'rb')
      @content = file.readlines
      file.close
    rescue StandardError => e
      @logger.error("read file error #{@ninja}: #{e.message} ")
    end
  end

  def get_compiler(toolchain)
    type_map = {
      'iar' => 'iar',
      'mdk' => 'arm',
      'armgcc' => 'gcc',
      'mcux' => 'gcc',
      'armds' => 'arm',
      'codewarrior' => 'mwcc56800e',
      'xtensa' => 'xcc'
    }
    type_map[toolchain]
  end

  def get_pattern(type)
    type_map = {
        'cc' => /^build\sCMakeFiles\S+\.o(bj)?:\sC_COMPILER/,
        'cx' => /^build\sCMakeFiles\S+\.o(bj)?:\sCXX_COMPILER/,
        'as' => /^build\sCMakeFiles\S+\.o(bj)?:\sASM_COMPILER/
    }
    type_map[type]
  end
  def parse_cc_flags
    parse_flags(get_pattern('cc'), 'cc')
  end
  def parse_cx_flags
    parse_flags(get_pattern('cx'), 'cx')
  end
  def parse_as_flags
    parse_flags(get_pattern('as'), 'as')
  end

  def parse_cc_include_path
    parse_include_path(get_pattern('cc'), 'cc')
  end

  def parse_as_include_path
    parse_include_path(get_pattern('as'), 'as')
  end

  def parse_flags(source_pattern, type)
    find_source_obj = false
    @content.each do |line|
      if line.match(source_pattern)
        find_source_obj = true
        next
      end
      if find_source_obj
        pattern = /FLAGS\s=\s*([\S\s]+)\s*/
        result = line.match(pattern)
        if result
          all_flags = preprocess_flags_with_prefix(result[1].split(/\s+/))
          all_flags.each do |flag|
            case flag
            when /-D([\"A-Za-z0-9_\(\)]+)=?(.*)?/
              _flag = flag.match(/-D([\"A-Za-z0-9_\(\)]+)=?(.*)?/)
              if _flag[2] && _flag[2] != ''
                if _flag[2].strip.match(/\S+,\S+/) && @toolchain == 'mdk'
                    # mdk GUI define does not support A=B,C add it in misc flags
                    @data[@name]['contents']['configuration']['tools'][@toolchain]['config'][@config]["#{type}-flags"] << flag
                    next
                elsif _flag[2].match(/^\\\".*(\\\"|\\\"\")$/)
                  if @toolchain == 'mdk'
                    # mdk GUI define does not support quotes, add it in misc flags
                    @data[@name]['contents']['configuration']['tools'][@toolchain]['config'][@config]["#{type}-flags"] << flag
                    next
                    # handle case like -D"COMPILER_FLAGS=\"-Ohs --no_size_constraints\""
                  elsif _flag[1].start_with?("\"") && _flag[2].end_with?("\"")
                     key = _flag[1].gsub(/^\"/,'')
                     value= _flag[2].gsub(/\"$/, '')
                     @data[@name]['contents']['configuration']['tools'][@toolchain]['config'][@config]["#{type}-define"][key] = value.gsub("\\", '')
                     next
                  else
                    # flags like -DSSCP_CONFIG_FILE=\"fsl_sscp_config_elemu.h\", should be parsed as yml format:
                    # SSCP_CONFIG_FILE: '"fsl_sscp_config_elemu.h"'
                    @data[@name]['contents']['configuration']['tools'][@toolchain]['config'][@config]["#{type}-define"][_flag[1]] = _flag[2].gsub("\\", '')
                    next
                  end
                end
              end
              @data[@name]['contents']['configuration']['tools'][@toolchain]['config'][@config]["#{type}-define"][_flag[1]] = _flag[2].empty? ? nil : _flag[2]
            when /-I-\s(-i|-ir)\s+\"([\S|\s]+)\"/
              _flag = flag.match(/-I-\s(-i|-ir)\s+\"([\S|\s]+)\"/)
              if _flag[2].include?("MCU/DSP56800x_EABI_Tools")
                res = "\\\"${MCUToolsBaseDir}/#{_flag[2].split('/MCU/')[1]}\\\""
              else
                res = "\\\"#{_flag[1]}\\\""
              end
              if _flag[1] == '-i'
                @data[@name]['contents']['configuration']['tools'][@toolchain]['config'][@config]["sys-search-path"] = [] unless @data[@name]['contents']['configuration']['tools'][@toolchain]['config'][@config]["sys-search-path"]
                @data[@name]['contents']['configuration']['tools'][@toolchain]['config'][@config]["sys-search-path"] << {'path' => res}
              elsif _flag[1] == '-ir'
                @data[@name]['contents']['configuration']['tools'][@toolchain]['config'][@config]["sys-path-recursively"] = [] unless @data[@name]['contents']['configuration']['tools'][@toolchain]['config'][@config]["sys-path-recursively"]
                @data[@name]['contents']['configuration']['tools'][@toolchain]['config'][@config]["sys-path-recursively"] << {'path' => res}
              end
            else
              @data[@name]['contents']['configuration']['tools'][@toolchain]['config'][@config]["#{type}-flags"] << flag
            end
          end
          break
        end
      end
    end
  end

  def parse_include_path(source_pattern, type)
    find_source_obj = false
    @content.each do |line|
      if line.match(source_pattern)
        find_source_obj = true
        next
      end
      if find_source_obj
        pattern = /INCLUDES\s=\s*([\S\s]+)\s*/
        result = line.match(pattern)
        if result
          result[1].split(/\s+/) do |flag|
            path = flag.tr('\\', '/')
            pattern = /-I(\S+)/
            _flag = path.match(pattern)
            if _flag
              if _flag[1].include? REPO_ROOT_PATH
                if _flag[1] == REPO_ROOT_PATH
                  include_path = './'
                else
                  include_path = _flag[1].split(REPO_ROOT_PATH)[-1].sub('/', '')
                end
              else
                begin
                include_path = Pathname.new(_flag[1]).relative_path_from(Pathname.new(REPO_ROOT_PATH)).cleanpath.to_s
                rescue StandardError => e
                  raise "Get relative path error: Can't get relative path from #{REPO_ROOT_PATH} to #{_flag[1]}, please make sure the destination path is in the same disk for Windows"
                end
              end

              @data[@name]['contents']['modules']['demo']["#{type}-include"].push({
                                                                          'path' => include_path,
                                                                          'package_path' => include_path,
                                                                          'project_path' => include_path
                                                                        })
            end
          end
          break
        end
      end
    end
  end

  def parse_source
    source_pattern = /^build\sCMakeFiles(\S+\.\S+)\.o(bj)?:/
    @content.each_with_index do |line, index|
      result = line.match(source_pattern)
      if result
        file_full_path = nil
        case Utils.detect_os
        when 'windows'
          file_full_path = line.split(/\s+/)[3]
          file_full_path = file_full_path.sub('$:', ':')
        when /linux|mac/
          file_full_path = line.split(/\s+/)[3]
        end
        if file_full_path
          add_file(file_full_path, line, 'src')
        else
          @logger.error("parse source error: #{@ninja} line #{index + 1}: #{line}.")
        end
      end
    end
  rescue StandardError => e
    @logger.error("parse_source error: #{e.message} ")
  end

  def parse_header
    file_list = File.join(ENV['build_dir'], "#{@name}_source_list.txt")
    if File.exist?(file_list)
        content = File.read(file_list)
        content.strip.split(";").each do |file|
            add_file(file, content, 'c_include') if ['.h', '.hpp'].include?(File.extname(file))
        end
    end
  end

  def parse_libraries
    find_link_obj = false
    @content.each do |line|
      if line.match( /^build\s#{@name}\.elf:/)
        find_link_obj = true
        next
      end
      if find_link_obj
        pattern = /LINK_LIBRARIES\s=\s*([\S\s]+)\s*/
        result = line.match(pattern)
        if result
          link_libraries = result[1].split(/\s+/)
          link_libraries&.each do |file_full_path|
            next if ["-Wl,--start-group", "-Wl,--end-group"].include? file_full_path
            # skip system library
            unless %w[.a .o .lib].include? File.extname(file_full_path)
            # for xtensa, should be put in ld-flags
             if @toolchain == "xtensa"
                @data[@name]['contents']['configuration']['tools'][@toolchain]['config'][@config]["ld-flags"] << file_full_path
             end
             next
            end
            add_file(file_full_path, line, 'lib', 'extra-libraries')
          end
          break
        end
      end
    end
  end

  def add_file(file_full_path, line, type, attribute = nil)
    file_path = file_full_path.tr('\\', '/')
    # the library file may not in repo, will be created by other project
    if attribute != 'extra-libraries'
      return unless File.exist?(file_path)
    end
    if file_path.include? REPO_ROOT_PATH
      # when the file is inside the repo
      file_path = file_path.split(REPO_ROOT_PATH)[-1].sub('/', '')
    elsif file_path.include? "#{@name}.dir/"
      file_path = file_path.split("#{@name}.dir/")[1]
      base_path = ENV['APPLICATION_SOURCE_DIR'].split(REPO_ROOT_PATH)[-1].sub('/', '')
      file_path = File.join(base_path, file_path)
    else
      file_path = get_relative_path(REPO_ROOT_PATH, file_path)
    end
    # some toolchain like mdk may remove file extension in ninja file, need to add it back for gui project
    file_path = complete_path(file_path, line, attribute)
    return if file_path.nil?
    source_hash = {
      'source' => file_path,
      'type' => type,
      'project_path' => File.dirname(file_path),
      'repo_path' => File.dirname(file_path),
      'package_path' => File.dirname(file_path)
    }
    source_hash['attribute'] = attribute if attribute
    
    # Codewarrior use "build" as build folder, can not set source file to this folder
    if @toolchain == 'codewarrior' && source_hash['project_path'] == 'build'
      source_hash['project_path'] = 'build_dir'
    end
    @data[@name]['contents']['modules']['demo']['files'].push(source_hash)
  end

  def parse_ld_flags
    find_link_obj = false
    source_pattern = /^build\s#{@name}\.elf:/
    @content.each do |line|
      if line.match(source_pattern)
        find_link_obj = true
        next
      end
      if find_link_obj
        pattern = /LINK_FLAGS\s=\s*([\S\s]+)\s*/
        result = line.match(pattern)
        if result
          if @toolchain == 'mcux'
            all_flags = []
            tmp_flags = result[1].split(/\s+/)
            xlinker_flag = false
            tmp_flags.each do |flag|
              if flag == '-Xlinker'
                xlinker_flag = true
                next
              end
              if xlinker_flag
                all_flags << "-Xlinker #{flag}"             
                xlinker_flag = false
              else
                all_flags << flag
              end
            end
          else
            all_flags = parse_ld_script(result[1]).split(/\s+/)
          end
          all_flags = preprocess_flags_with_prefix(all_flags)
          all_flags.each do |flag|
            @data[@name]['contents']['configuration']['tools'][@toolchain]['config'][@config]["ld-flags"] << flag
          end
          break
        end
      end
    end
  end

  def parse_ld_script(all_flags)
    case @toolchain
    when 'iar'
      pattern = /--config\s(\S+)\s/
    when 'mdk'
      pattern = /--scatter\s(\S+)\s/
    when 'armgcc'
      pattern = /-T\s(\S+)\s/
    when 'codewarrior'
      pattern = /(\S+Internal_PFlash_(SDM|LDM|HPM|LPM|SPM).cmd)/
    else
      pattern = nil
    end
    if pattern
      result = all_flags.match(pattern)
    else
      result = nil
    end
    if result
      path = result[1].tr('\\', '/').split(REPO_ROOT_PATH)[-1].sub('/', '')
      @data[@name]['contents']['modules']['demo']['files'].push({
                                                                  'source' => path,
                                                                  'attribute' => 'linker-file',
                                                                  'toolchains' => @toolchain,
                                                                  'targets' => @config,
                                                                  'type' => 'linker',
                                                                  'project_path' => File.dirname(path),
                                                                  'repo_path' => File.dirname(path),
                                                                  'package_path' => File.dirname(path)
                                                                })
      all_flags.sub!(result[ 0 ], '')
    end
    all_flags
  end
  #for preifx like --preinclude/--include/--config_def may have several configs, must keep the prefix for each config
  def preprocess_flags_with_prefix(all_flags)
    keep_prefix = ["--preinclude", "-include", "--config_def",  "-P", "--diag_suppress"]
    result = []

    all_flags.each_with_index do |flag, index|
        next if flag.nil? || flag.strip.empty?
        if keep_prefix.include?(flag.strip)
          # update relative path for preinclude file
          preinclude_file = all_flags[index+1]
          if File.exist?(preinclude_file)
            path = translate_project_relative_path(preinclude_file)
            if @toolchain == 'iar'
              all_flags[index+1] = File.join('$PROJ_DIR$', path)
            elsif @toolchain == 'xtensa'
              all_flags[index+1] = File.join('${xt_project_loc}', path)
            elsif @toolchain == 'codewarrior'
              all_flags[index+1] = File.join('${ProjDirPath}', path)
            else
              all_flags[index+1] = path
            end
          end
          if flag.strip == "--config_def"
            result.push "#{flag}=#{all_flags[index+1]}"
          else
            result.push "#{flag} #{all_flags[index+1]}"
          end
          all_flags[index+1] = nil
        elsif flag.strip.start_with?("--image_input=")
          pattern = /--image_input=(\S+),(\S+),(\S+),(\d+)/
          res = flag.strip.match(pattern)
          if res && res[1]
            # If using relative path in cmake setting, need to transfer it to absolute path first, then get path relative to project path
            if res[1].start_with?('../') || res[1].start_with?('./')
              path = File.join('$PROJ_DIR$', translate_project_relative_path(File.join(ENV['build_dir'], res[1])))
            else
              path = File.join('$PROJ_DIR$', translate_project_relative_path(res[1]))
            end
            result.push flag.gsub(res[1], path)
          end
        elsif flag.strip.match(/-D([\"A-Za-z0-9_\(\)]+)=?(.*)?/)
          _flag = flag.match(/-D([\"A-Za-z0-9_\(\)]+)=?(.*)?/)
          if _flag[2] && _flag[2] != ''
            # if macro value like \"-Ohs without ending \",  means there is a space in macro value
            if _flag[2].start_with?("\\\"") && !_flag[2].end_with?("\\\"")
              result.push "#{flag} #{all_flags[index+1]}"
              all_flags[index+1] = nil
            else
              result.push flag
            end
          else
            result.push flag
          end
        elsif @toolchain == 'codewarrior'
          if flag.strip == '-I-'
            # for codewarrior, "-I -i path" and "-I -ir path" should be seen as a whole
            result.push "#{flag} #{all_flags[index+1]}  #{all_flags[index+2]} #{all_flags[index+3]}"
            for i in 1..3
              all_flags[index+i] = nil
            end
          elsif flag.strip == "-opt"
              result.push "#{flag} #{all_flags[index+1]}"
              all_flags[index+1] = nil
          else
            pattern = /-l\"(\S+)MCU\/(DSP56800x_EABI_Tools\/lib\S+)\"/
            res = flag.strip.match(pattern)
            if res && res[2]
              result.push "-l\\\"${MCUToolsBaseDir}/#{res[2]}\\\""
            else
              result.push flag
            end
          end
        elsif flag
          result.push flag
        end
    end
    result
  end

  # translate absolute path to path relative to project root path
  def translate_project_relative_path(abs_path)
    relative_path = Pathname.new(abs_path).relative_path_from(Pathname.new(@outdir)).to_s
    if ENV['standalone'] == 'true'
      if relative_path.start_with?('..')
        path = abs_path.tr('\\', '/').split(REPO_ROOT_PATH)[-1]
      else
        path = relative_path
      end
    else
      # For gui project, project file is in toolchain/.. folder
      path = File.join('..', relative_path)
    end
    path
  end

  def parse_prebuild
    pattern = /PRE_LINK\s=\s(.*)/
    @content.each do |line|
      result = line.match(pattern)
      if result
        content = result[1].strip
        # cd . means no cmd
        break if content == 'cd .' || content == ':'
        cmd_list = content.split(" && ")
        cmd_list.each_with_index do |cmd_item, index|
          cmd_list[index] = nil if cmd_item.match(/(cmd.exe|cd)[\s\S]+[\/\\]#{File.basename(@outdir)}"?$/)
        end
        cmd_list =cmd_list.compact.join(' && ').split(' ')
        # TODO Identify more toolchains if necessary
        cmd_list.each_with_index do |item, index |
          if item.match(/bin[\/\\]iccarm/)
            cmd_list[index] = "$TOOLKIT_DIR$/bin/iccarm"
          elsif item.match(/bin[\/\\]armclang/)
            cmd_list[index] = "$KARM/ARMCLANG/bin/armclang"
          elsif item.match(/bin[\/\\]arm-none-eabi-gcc/)
            cmd_list[index] = "${TOOLCHAIN_DIR}/bin/arm-none-eabi-gcc"
          elsif item.match(/-[Io](\S+)/)
            path = item.include?('mcu-sdk-3.0') && item.match(/-[Io](\S+)/)[1]
            if File.exist?(path)
              if ENV['standalone'] == 'true'
                dest_path = File.join(File.join(@outdir, @toolchain), path.split(/mcu-sdk-3.0[\/\\]/)[-1])
                new_path = get_relative_path(File.join(@outdir, @toolchain), dest_path)
              else
                new_path = get_relative_path(File.join(@outdir, @toolchain), path)
              end
              if item.strip.start_with?('-I')
                cmd_list[index] = "-I#{new_path}"
              else
                cmd_list[index] = "-o#{new_path}"
              end
            end
          elsif item.include?('mcu-sdk-3.0') && File.exist?(File.dirname(item))
            if ENV['standalone'] == 'true'
                dest_path = File.join(File.join(@outdir, @toolchain), item.split(/mcu-sdk-3.0[\/\\]/)[-1])
                cmd_list[index] = get_relative_path(File.join(@outdir, @toolchain), dest_path)
            else
                cmd_list[index] = get_relative_path(File.join(@outdir, @toolchain), item)
            end
          end
        end
        cmd_list = cmd_list.join(' ').split(' && ')
        @logger.debug( "Parse prebuild command: #{cmd_list.join(' ')}")
        if NO_GUI_TEMPLATE_TOOLCHAIN.include? @toolchain
          @data[@name]['contents']['configuration']['tools'][@toolchain]['prebuild'] = cmd_list
        else
          @data[@name]['contents']['configuration']['tools'][@toolchain]['prebuild'] = cmd_list
        end
        break
      end
    end
  end

  def parse_postbuild
    pattern = /POST_BUILD\s=\s(.*)/
    @content.each do |line|
      result = line.match(pattern)
      if result
        content = result[1].strip
        if content.match(/\S+?.elf/) && content.match(/\S+(.bin|.srec)/) && content.match(/(-Obinary|--bin|-Osrec|--srec|--m32)/)
          bin_file = File.basename(content.match(/\S+\.(bin|srec)/)[0])
          @data[@name]['contents']['configuration']['tools'][@toolchain]['binary-file'] = bin_file
          break
        else
          # cd . means no postbuild cmd
          if content == 'cd .' || content == ':'
            break
          elsif @toolchain == 'iar'
            pattern = /--bin\s\S+#{@name}\.elf/
            result = content.match(pattern)
            content.sub!(result[ 0 ], '--bin $TARGET_DIR$/$TARGET_FNAME$') if result
          elsif @toolchain == 'mdk'
            pattern = /--bincombined\s\S+#{@name}\.elf/
            result = content.match(pattern)
            content.sub!(result[ 0 ], '--bincombined $p/#L') if result
          end
          if NO_GUI_TEMPLATE_TOOLCHAIN.include? @toolchain
            @data[@name]['contents']['configuration']['tools'][@toolchain]['postbuild'] = [content]
          else
            @data[@name]['contents']['configuration']['tools'][@toolchain]['postbuild'] = [content]
          end
          break
        end
      end
    end
  end

  def parse_precompile
    cmd_list = []
    pattern = /build\sCMakeFiles(\/|\\)PRE_COMPILE_CMD_TARGET/
    @content.each_with_index do |line, index|
      result = line.match(pattern)
      if result
        content = @content[index+1].strip
        if content.include?('COMMAND = ')
          cmd = content.split('COMMAND = ')[-1]
          cmd_list << cmd
        end
      end
    end
    @data[@name]['contents']['configuration']['tools'][@toolchain]['precompile'] = cmd_list if cmd_list
  end

  def complete_path(file_path, line, attribute = nil)
    source_ext = %w[.c .cpp .s .S .cc]
    full_path = File.join(REPO_ROOT_PATH, file_path)
    if File.exist?(full_path)
      return file_path
    elsif attribute == 'extra-libraries'
      return file_path
    else
      source_ext.each do |ext|
        tmp = full_path + ext
        # make sure the file exsit and the file ext name is exact same as build.ninja without letter case error, such as .S .s for file extension name
        if File.exist?(tmp) && line.include?(File.basename(tmp))
          return get_relative_path(REPO_ROOT_PATH, tmp)
        end
      end
    end
    @logger.error("complete path error: #{file_path} does not exist.")
    nil
  end

  def get_relative_path(base_path, taeget_path)
    base = Pathname.new(base_path)
    target = Pathname.new(taeget_path)
    target.relative_path_from(base).to_s
  end

  def merge_ide_data
    @variables = {}
    ENV.each do |key, value|
      @variables[key] = value
    end
    # codewarrior cp-define use CONFIG_MCUX_HW_DEVICE_ID
    @variables['CONFIG_MCUX_HW_DEVICE_ID'] =  @variables['device_id']

    file_list = ENV['IDE_YML_LIST']&.split(' ')
    ide_data = {}
    if NO_GUI_TEMPLATE_TOOLCHAIN.include?(@toolchain)
      ide_data.deep_merge!(reorg_ide_data({
        @toolchain=> {
          'project-templates' => ["scripts/guigenerator/templates/cmake/CMakeLists.txt",
                                  "cmake/toolchain/#{@toolchain}.cmake"]
        },
        'cmake_toolchain' => {
          'files' => [
            {'source' => "scripts/guigenerator/templates/cmake/toolchain/#{@toolchain}.cmake", 'type' => 'script', 'package_path' => 'cmake/toolchain', "exclude" => true},
            {'source' => "scripts/guigenerator/templates/cmake/toolchain/toolchain.cmake", 'type' => 'script', 'package_path' => 'cmake/toolchain', "exclude" => true},
            {'source' => "scripts/guigenerator/templates/cmake/toolchain/mcux_config.cmake", 'type' => 'script', 'package_path' => 'cmake/toolchain', "exclude" => true}
          ]
        }
      }))
    else
      raise "Error: No IDE.yml found." if ENV['IDE_YML_LIST'].nil? || ENV['IDE_YML_LIST'].empty?
    end
    file_list.each do |file|
      if File.extname(file) == '.yml'
        @logger.debug( "Merge IDE data #{file}")
        content = YAML.load_file(file)
        ide_data.deep_merge!(reorg_ide_data(content), {:overwrite_arrays => true})
      end
    end
    merge_by_variable(ide_data)
    merge_by_common!(ide_data)
    process_project_path(ide_data)

    if @logger.level == Logger::DEBUG
      dump_file = File.join(ENV['build_dir'], 'IDE.yml')
      @logger.debug("Dump merged IDE.yml into #{ENV['build_dir']}/IDE.yml")
      YAML.dump_file(dump_file, ide_data)
    end

    @data.deep_merge!(ide_data)
  end

  def reorg_ide_data(content)
    tmp = {
      '__variable__' => {},
      @name => {
        'contents' => {
          'configuration' => {
            'tools'=> {
              @toolchain => {
                'config' => {
                  @config => {
                  }
                }
              }
            }
          },
          'modules' => {
          }
        }
      }
    }
    content&.each do |key, value|
      if key == @toolchain
        tmp[@name]['contents']['configuration']['tools'][@toolchain].deep_merge! value
      elsif key == '__variable__'
        tmp['__variable__'].deep_merge! value
      elsif value.key? 'files'
        tmp[@name]['contents']['modules'][key] = value
      end
    end
    tmp.delete('__variable__') if tmp['__variable__'].empty?
    tmp
  end

  def merge_by_variable(yml_data_content)
    return if Hash != yml_data_content.class

    yml_data_content['__variable__']&.each do |key, val|
      if @variables.key?(key) && @variables[key] != val
        @logger.fatal("Yml variable \"#{key} => #{val}\" dose not match cmake variable \"#{key} => #{@variables[key]}\", please change variable name or update variable value in IDE.yml")
      end
      @variables[key] = val
    end

    yml_data_content.each do |key, value|
      next if yml_data_content[key].class != Hash

      value_iterator(@variables, value)
    end

    key_iterator(@variables, yml_data_content)
  end

  # handle project-root-path and project-name in IDE.yml
  def process_project_path(ide_data)
    project_path_variables = {
      'project-root-path' => './',
      'project-name' => @name
    }
    ide_data.each do |project_name, content|
      content['contents']['modules'].each do |mod_name, mod_content|
        mod_content['files']&.each do |file|
          file.each do |key, value|
            project_path_variables.each do |variable_name, variable_value|
              value.gsub!(/#{variable_name}/, variable_value) if value.is_a?(String)
            end
          end
          file['repo_path'] = File.dirname(file['source']) unless file.key?('repo_path')
        end
      end
    end
  end

  def value_iterator(variables, value)
    if Hash == value.class
      value.each_value { |v| value_iterator(variables, v) }
    elsif Array == value.class
      value.each { |v| value_iterator(variables, v) }
    elsif String == value.class
      value.gsub!(/\${(\w+)}/) do |_match|
        Core.assert(variables[$+], "variable '#{$+}' dose not exist")
        variables[$+]
      end
    end
  end

  def key_iterator(variables, data)
    case data
    when Hash
      data.transform_keys! do |key|
        key.gsub(/\${(\w+)}/) do |_match|
          Core.assert(variables[::Regexp.last_match(-1)],
                      "variable '#{::Regexp.last_match(-1)}' is used in yml record, but has not been defined under '__variable__'")
          variables[::Regexp.last_match(-1)]
        end
      end
      data.each do |key, value|
        key_iterator(variables, value)
      end
    when Array
      data.each do |value|
        key_iterator(variables, value)
      end
    end

    data
  end

  def merge_project_segments(project_segments, section_content)
    project_segments&.each do |each_segment, each_content|
      next if each_content['section-type'] != 'project_segment'
      next if each_content['required'] != true

      segment_data = deep_copy(each_content)
      segment_data.safe_delete('section-type')
      segment_data.safe_delete('merge_segment')
      segment_data.safe_delete('belong_to')

      section_content.deep_merge!(segment_data)
    end
    section_content
  end

  def merge_by_common!(yml_data_content)
    return if Hash != yml_data_content.class

    unless yml_data_content['__common__'].nil?
      yml_data_content.each_key do |subnode|
        next if KEY_LIST.include?(subnode)
        next if (yml_data_content[subnode].class != Hash) || (yml_data_content['__common__'].class != Hash)

        yml_data_content[subnode] = yml_data_content[subnode].deep_merge!(deep_copy(yml_data_content['__common__']))
      end
      yml_data_content.delete('__common__')
    end
    yml_data_content.each_key { |subnode| merge_by_common!(yml_data_content[subnode]) }
  end

  def merge_by_replace!(yml_data_content)
    return if Hash != yml_data_content.class
    _merge_by_replace!(yml_data_content)
    yml_data_content.each_key do |key|
      merge_by_replace!(yml_data_content[key]) if Hash == yml_data_content[key].class
    end
  end

  def _merge_by_replace!(yml_data_content)
    return if Hash != yml_data_content.class
    # get the replace hash
    return unless yml_data_content.key?('__replace__')

    temp = {}
    temp = temp.deep_merge(deep_copy(yml_data_content['__replace__']))
    temp.each_key do |key|
      next unless yml_data_content.key?(key)

      delete_node(yml_data_content, key)
      yml_data_content[key] = temp[key]
    end
    yml_data_content.delete('__replace__')
  end

  def delete_node(yml_data_content, type, items = nil)
    yml_data_content.each_key do |subnode|
      next if yml_data_content[subnode].nil?

      if items
        items.each { |item| yml_data_content[type].delete(item) }
      else
        yml_data_content.delete(type)
      end
      delete_node(yml_data_content[subnode], type) if Hash == yml_data_content[subnode].class
    end
  end

  def update_overlay(overlay_data)
    overlay_data.each do |node, overlay|
      update_iterate_nested_hash(@data, node.split('/'), overlay)
    end
  end

  def update_iterate_nested_hash(hash, sub_keys, content)
    if hash.is_a?(Hash)
      if hash.dig(*sub_keys)
        if sub_keys.length == 1
          hash[sub_keys.last] = content
        else
          hash.dig(*sub_keys[0..-2])[sub_keys.last] = content
        end
        return
      end
    end
    hash.each do |key, value|
      if value.is_a?(Hash)
        update_iterate_nested_hash(value, sub_keys, content)
      end
    end
  end


  def remove_unsupported_config
    @data[@name]['contents']['configuration']['tools'][@toolchain]['config'].each do |key, content|
      if key != @config
        @data[@name]['contents']['configuration']['tools'][@toolchain]['config'].delete(key)
        next
      end

      %w[cc-define cx-define as-define cc-flags as-flags cx-flags ld-flags cp-define].each do |setting|
        @data[@name]['contents']['configuration']['tools'][@toolchain]['config'][key].delete(setting) if content[setting].empty?
      end

    end
  end
end