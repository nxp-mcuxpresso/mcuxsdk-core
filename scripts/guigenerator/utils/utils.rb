# frozen_string_literal: true
# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
require 'logger'
require 'nokogiri'
require 'fileutils'
require_relative '_assert'

# ********************************************************************
# Copyright 2018 NXP
# ********************************************************************

# [Integer] max integer value
MAX_INTEGER = (2**(0.size * 8 - 2) - 1)

# [Array] All supported boolean values: true and false
BOOLEAN_VALUES = [true, false].freeze

MDK_TOOLCHAIN = 'mdk'
IAR_TOOLCHAIN = 'iar'

# Used for mapping toolchain name for <environment>
SUPPORTED_CMSIS_TOOLCHAINS_MAP = {
  MDK_TOOLCHAIN => 'uv',
  IAR_TOOLCHAIN => 'iar'
}.freeze

# [String] name of file, where are components without device/board dependency
SHARED_COMPS_FILE = 'components.yml'

# Constant of megabyte
MEGABYTE = 1_048_576
# Constant of 64kB
KILOBYTES_64 = 65_536

TAB_4 = "\s" * 4
TAB_2 = "\s" * 2

LOG_LEVEL_MAP = {
  5 => Logger::UNKNOWN,
  4 => Logger::FATAL,
  3 => Logger::ERROR,
  2 => Logger::WARN,
  1 => Logger::INFO,
  0 => Logger::DEBUG
}

# ********************************************************************
# Useful general-purpose utilities
module Utils
  # --------------------------------------------------------
  # Assertion
  # See also Core.assert instead
  # @param [bool] +condition+: boolean value expected to be true
  # @param [String] +message+: message displayed in case of test failure
  def self.assert(condition, message)
    Core.assert(condition, message)
  end

  # --------------------------------------------------------
  # @return [Boolean] true if running in RubyMine debugger
  def self.rubymine_debugger?
    ENV['RUBYLIB'] =~ /ruby-debug-ide/
  end

  # --------------------------------------------------------
  # @return [Boolean] whether Process.fork is supported; returns false in debugger due to RubyMine problem
  def self.fork_supported?
    return false if rubymine_debugger?

    Process.respond_to?(:fork)
  end

  def self.parallel_type
    if fork_supported?
      :in_processes
    elsif Object.const_defined?('Ractor')
      :in_ractors
    else
      :in_threads
    end
  end

  # --------------------------------------------------------
  # Converts integer value to hex binary XML string
  # About HEX binary look at: http://www.datypic.com/sc/xsd/t-xsd_hexBinary.html
  # @param [Integer] +value+: to be converted
  # @param [Integer] n_lead_zeros: number of leading zeros, default is 8, must be even number
  # @return [String] hex binary format
  def self.to_hex_binary(value, n_lead_zeros = 8)
    Utils.assert (value.is_a? Integer), 'invalid argument type'
    Utils.assert n_lead_zeros.even?, 'number of leading zeros must be even'
    value.to_s(16).rjust(n_lead_zeros, '0')
  end

  # --------------------------------------------------------
  # Converts integer value to hex integer XML format
  # @param [Integer] +value+: to be converted
  # @return [String] hex int format; padding zeros to reach number of digits dividable by 2
  def self.to_hex2_int(value)
    return value if value.nil?

    result = to_hex_binary(value, 2)
    # add leading zero if result is odd, eq. 10000 would be 010000
    result = result.rjust(result.length + 1, '0') if result.length.odd?
    '0x' + result
  end

  # --------------------------------------------------------
  # Converts integer value to hex integer XML format
  # @param [Integer] +value+: to be converted
  # @return [String] hex int format; padding zeros to reach number of digits dividable by 4
  def self.to_hex4_int(value)
    return value if value.nil?

    result = to_hex_binary(value, 4)
    '0x' + result
  end

  # --------------------------------------------------------
  # Converts integer value to hex integer XML format
  # @param [Integer] +value+: to be converted
  # @return [String] hex int format; padding zeros to reach number of digits dividable by 8
  def self.to_hex8_int(value)
    return value if value.nil?

    result = to_hex_binary(value, 8)
    '0x' + result
  end

  # ----------------------------------------------------------
  # Loads hash and recursively resolves any environmental values that might be specified inside as a string
  #   using %ENV(value) syntax. Value is then converted using ENV['value'] call and replaces old value
  # @param [Hash] hash_data: hash to be read
  # @return [Hash]: hash converted (or not changed at all if no ``%ENV`` is present)
  def self.resolve_env_vars(hash_data)
    hash_data.each do |key, value|
      if value.is_a? Array
        value.map! { |element| replace_env(element) }
      elsif value.is_a? Hash
        value = resolve_env_vars(value)
      elsif value.is_a? String
        value = replace_env(value)
      end
      hash_data[key] = value
    end

    hash_data
  end

  # ----------------------------------------------------------
  # Replaces %ENV(VALUE) in supplied string with ENV[VALUE] resolved
  # @param [String] string: string to be replaced
  # @return [String]: string processed
  def self.replace_env(string)
    return string.to_s unless string.is_a? String

    return string unless string.include? '%ENV('

    # match returns MatchData nad [1] returns our 1s matched group (there is only one)
    env_var = ENV[string.match(/%ENV\((.*?)\)/)[1]]
    # replaced %ENV(value) with returned ENV value
    string.sub(/%ENV\((.*?)\)/, env_var)
  end

  # ----------------------------------------------------------
  # FIXME SDKGEN-2770 this api is really slow
  # Compares two objects on value level
  # returns false if not equal, true otherwise
  # possibility to skip attributes using variables_omitted
  # allows recursive behavior but only on variables with at least one instance variable
  # @param [Object] source: source object for comparing
  # @param [Object] target: target object for comparing
  # @param [Array] variables_omitted: array of of string values to be omitted when comparing
  # @param [Boolean] recursive: sets recursive behavior
  def self.compare_objects(source, target, variables_omitted = [], recursive = false)
    # converts variables to symbolic instance variables
    # if '@' is already first char, convert to symbolic
    # Do not use prepend, as it modifies source values (conflict with frozen string)
    variables_omitted = variables_omitted.map { |x| x.index('@')&.zero? ? x.to_sym : "@#{x}".to_sym }

    # subtracts variables from object's instance variables
    target_variables = (target.instance_variables - variables_omitted)
    source_variables = (source.instance_variables - variables_omitted)

    return false if target_variables.length != source_variables.length

    source_variables.each do |variable|
      src_var = source.instance_variable_get(variable)
      tgt_var = target.instance_variable_get(variable)
      # in 99% of cases, no instance variables mean it is String, Hash, Array, etc. class
      if recursive && !src_var.instance_variables.empty?
        return false unless compare_objects(src_var, tgt_var, [], true)
      elsif src_var != tgt_var
        return false
      end
    end

    true
  end

  # --------------------------------------------------------
  # The function compares two text files. Found differences are described on STDOUT
  # @param [File/String] f_new: newly created file; OR [String] file-path
  # @param [File/String] f_template: template file to compare with OR [String] file-path
  # @return [Boolean] true if files are same; false otherwise
  def self.compare_text_files_content(f_new, f_template)
    f_new = File.open(f_new, 'r:utf-8') if f_new.is_a? String
    f_template = File.open(f_template, 'r:utf-8') if f_template.is_a? String

    result = true
    f_new.each_line do |line|
      expected_line = f_template.readline
      # ignore whitespace while comparing content
      next if line&.strip == expected_line&.strip

      # found difference
      puts 'Different lines:'
      puts ' New: ' + line.to_s
      puts ' Exp: ' + expected_line.to_s
      result = false
      break
    end
    not_eof = !f_template.eof?
    if not_eof
      result = false
      puts 'Different line: ' + f_template.readline
    end
    f_new.close
    f_template.close
    result
  end

  # --------------------------------------------------------
  # The function compares two text files and prints result. Found differences are described on STDOUT
  # @param [String] name: description of the generated file for log message
  # @param [String] f_new: generated file-path
  #               If result is true, the file is removed from the disk
  # @param [String] f_template: template file to compare with OR [String] file-path
  # @return [Boolean] true if files are same; false otherwise
  def self.compare_text_files(name, f_new, f_template)
    result = compare_text_files_content(f_new, f_template)
    unless result
      puts 'FAILURE: Generated ' + f_new + ' is different compare to previous version' + f_template
      exit(1)
    end
    puts 'Pass: ' + name + ' successfully compared by content with previous version'
    FileUtils.remove_file(f_new, true)
    puts 'Filed to delete file: ' + f_new if File.file?(f_new)
    result
  end

  # Get the operating system
  # @return [String] one of: 'windows'/'macosx'/'linux'/'unix'
  def self.detect_os
    os ||= begin
      host_os = RbConfig::CONFIG['host_os']
      case host_os
      when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
        'windows'
      when /darwin|mac os/
        'mac'
      when /linux/
        'linux'
      when /solaris|bsd/
        'unix'
      else
        Core.fail 'operating system not detected'
      end
    end
    os
  end

  # judge if path_a and path_b in same disk drive
  def self.same_disk_drive?(path_a, path_b)
    if self.detect_os == 'windows'
      drive_a = path_a[0, 1].upcase if path_a =~ /^[a-zA-Z]:/
      drive_b = path_b[0, 1].upcase if path_b =~ /^[a-zA-Z]:/
      return drive_a != nil && drive_b != nil && drive_a == drive_b
    else
      return true
    end
  end

  # judge if path_a inside path_b
  def self.path_inside?(path_a, path_b)
    path_a = Pathname.new(path_a).cleanpath
    path_b = Pathname.new(path_b).cleanpath
  
    path_a.fnmatch?(File.join(path_b, '**'))
  end

  def self.find_executable(bin, path = nil)
    executable_file = proc do |name|
      begin
        stat = File.stat(name)
      rescue SystemCallError
      else
        next name if stat.file? and stat.executable?
      end
    end

    config_string = lambda { |key, config = RbConfig::MAKEFILE_CONFIG, &block|
      s = config[key] and !s.empty? and block ? block.call(s) : s
    }

    exts = config_string.call('EXECUTABLE_EXTS') {|s| s.split} || config_string.call('EXEEXT') {|s| [s]}
    if File.expand_path(bin) == bin
      return bin if executable_file.call(bin)
      if exts
        exts.each {|ext| executable_file.call(file = bin + ext) and return file}
      end
      return nil
    end
    if path ||= ENV['PATH']
      path = path.split(File::PATH_SEPARATOR)
    else
      path = %w[/usr/local/bin /usr/ucb /usr/bin /bin]
    end
    file = nil
    path.each do |dir|
      dir.sub!(/\A"(.*)"\z/m, '\1') if $mswin or $mingw
      return file if executable_file.call(file = File.join(dir, bin))
      if exts
        exts.each {|ext| executable_file.call(ext = file + ext) and return ext}
      end
    end
    nil
  end

  # Check if file is binary file
  # @param [String] path: absolute path to file
  # @return [Boolean] True if file is binary, else False
  def self.binary_file?(path)
    # On the start of file can be BOF with null chars
    actual_position = 5
    file_size = File.size(path)
    while file_size > actual_position && MEGABYTE > actual_position # 1 MB
      return true unless /\x00/.match(IO.read(path, KILOBYTES_64, actual_position, mode: 'rb')).nil?

      actual_position += KILOBYTES_64
    end
    false
  end

  def self.measure(msg, print=true, &block)
    return unless block_given?

    start = Time.new
    _ret = yield(block)
    finish = Time.new
    puts("#{msg}: using #{'%.3f' % (finish - start)}s") if print
    _ret
  end

  # The method logs an error message and raise FatalError exception
  # @param [String] message to be logged
  def self.raise_nonfatal_error(message)
    Logger.new(STDOUT).error message
    raise NonFatalError, message
  end

  # The method logs an error message and raise NoAbortError exception
  # @param [String] message to be logged
  def self.raise_no_abort_error(message)
    Logger.new(STDOUT).error message
    raise NoAbortError, message
  end

  # The method logs a fatal message and raise FatalError exception
  # @param [String] message to be logged
  def self.raise_fatal_error(message)
    raise FatalError, message
  end

  # The method logs a fatal message and raise AbortError exception
  # @param [String] message to be logged
  def self.raise_abort_error(message)
    Logger.new(STDOUT).fatal message
    raise AbortError, message
  end

  # --------------------------------------------------------
  # Ensure hash contains key with sub-hash
  # @param [Hash] hash: that should contains key
  # @param [String] key: to identify hash in the hash above
  def sub_hash(hash, key)
    hash.store(key, {}) unless hash.key?(key)
    hash[key]
  end

  # --------------------------------------------------------
  # Ensure hash contains key with sub-array
  # @param [Array] array: that should contains key
  # @param [String] key: to identify array in the array above
  def sub_array(hash, key)
    hash.store(key, []) unless hash.key?(key)
    hash[key]
  end

  # --------------------------------------------------------
  # Get version-specific class
  # @param [String] class_name: class name
  # @param [String] version: version
  def instance_with_version(class_name, version, *args, **kwargs)
    class_name_with_version = version.nil? ? class_name : class_name + '_' + version.to_s.split('.').join('_')
    target_class = if Object.const_defined?(class_name_with_version, false)
      Object.const_get(class_name_with_version)
    elsif Object.const_defined?(class_name, false)
      Object.const_get(class_name)
    else
      nil
    end
    if target_class
      target_class.new(*args, **kwargs)
    else
      raise_fatal_error("Undefined class #{class_name}")
    end
  end
end

# ###########################################################
# Base class with @logger (never nil)
class BaseClassWithLogger
  # --------------------------------------------------------
  # Constructor
  # @param [Logger] logger: Logger object used for logging.
  #   Default value is nil, which will initialize new Logger with output to STDOUT and level WARNING
  def initialize(logger = nil)
    if logger.nil?
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::ERROR
      @logger.debug('Initialized new logger')
    else
      @logger = logger
    end
  end

  # [Logger] logger
  attr_reader :logger
end

# ###########################################################
# Extend the File class
class File
  # --------------------------------------------------------
  # First create directory if not exists yet
  # Then write the content into file_path.
  # @param [String] file_path: the file path
  # @param [Object] content: the content to be wrote; "content.to_yaml" is called to write it
  # @return [nil]
  def self.create_write(file_path, content)
    FileUtils.mkdir_p(File.dirname(file_path)) unless File.directory?(File.dirname(file_path))
    File.open(file_path, 'w:utf-8') do |f|
      f.puts content.to_yaml
    end
  end

  # --------------------------------------------------------
  # Get the file extension. The File.extname will return "" for dotfile like ".project", what needed is ".project"
  # @param [String] file_path: the file path
  # @return [String] file extension
  def self.get_extension(file_path)
    file_name = File.basename(file_path)
    return file_name if file_name.rindex('.')&.zero?

    File.extname(file_name)
  end
end

# ###########################################################
# Extend the FileUtils class
module FileUtils
  # --------------------------------------------------------
  # First create target directory if not exists yet
  # Then copy the file
  # @param [String] original_path: String that contains original path
  # @param [String] new_path: String that contains new path
  # @return [nil]
  def self.cp_e(original_path, new_path)
    FileUtils.mkdir_p(File.dirname(new_path)) unless File.directory?(File.dirname(new_path))
    FileUtils.cp(original_path, File.dirname(new_path), preserve: true) unless File.exist?(new_path)
  end
end

# ###########################################################
# Extend standard String class
class String
  # --------------------------------------------------------
  # Converts string to an array that contains the string
  def to_a
    raise StandardError, "#{self} must be an string" if self.class != String

    string_array = []
    string_array.push(self)
    string_array
  end

  # ---------------------------------------------------------------------
  # Return constant value with the same name of the string
  def to_const
    unless self == upcase
      raise StandardError,
            "#{self} must be in all uppercase if it wants to be converted to a CONSTANT."
    end

    Object.const_get(self)
  end
end

# ###########################################################
# extend standard Array class
class Array
  # --------------------------------------------------------
  # Multiplies two arrays of string.
  # @param [Array] multiplier_array: second parameter, array of string
  # @return [Array] of string, each element consists of [1st-item][space][2nd-item],
  #                 where [N-item] is an item from N array.
  #                 But if both items are same, the item contains just one of them
  #                 If array is empty, the function returns {multiplier_array}
  def multiply(multiplier_array)
    if (multiplier_array.class != Array) || multiplier_array.empty?
      raise StandardError, "#{multiplier_array} must be an non-empty array!"
    end
    return multiplier_array if empty?

    new_array = []
    each do |each|
      raise StandardError, "Array member #{each} must be an string" if each.class != String

      multiplier_array.each do |sub_each|
        raise StandardError, "Array member #{sub_each} must be an string" if each.class != String

        new_array.push(each + ' ' + sub_each)
      end
    end
    # remove the duplicated element
    final_array = []
    new_array.each do |each|
      final_array.push(each.split(' ').uniq.join(' '))
    end
    final_array
  end

  # add in the element if the array does not include this element
  def push_uniq(element)
    push(element) unless include?(element)
  end

  def only_include?(element)
    include?(element) && self.length == 1
  end

  # return self except specified value(s)
  # @param [Any]: value or values to be removed from array before returning itself
  # @return [Array]: array without specified value(s)
  def except(value)
    self - [value].flatten
  end

  # whether self array contains all elements from other array
  def contain?(other_array)
    self.sort == self.union(other_array).sort
  end

  # get median number of array
  def median
    return nil if self.empty?
    sorted = self.sort
    len = sorted.length
    (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end
end

# ###########################################################
# extend standard Hash class
class Hash
  # Fetch the value of certain key, if the key not found raise error
  # @param [String] msg: the message to raise if the key(es) do(es) not exists
  def fetch_raise_msg(msg, key, *smth)
    return dig(key, *smth) unless dig(key, *smth).nil?

    raise StandardError, msg
  end

  # @param [Object] default: the default value to return if the key(s) do(es) not exists
  def dig_with_default(default, key, *smth)
    dig(key, *smth).nil? ? default : dig(key, *smth)
  end

  # Check whether has this key and is not nil or empty
  # @param [String] key: the section type to be checked
  def safe_key?(key)
    !nil? && key?(key) && !self[key].nil? && !self[key].empty?
  end

  # --------------------------------------------------------
  # Store new hash after checking whether the key already exists
  # @param [Object] key: key of the hash
  # @param [Object] content: content of the hash
  def check_store(key, content)
    store(key, content) unless key?(key)
  end

  # --------------------------------------------------------
  # Store new hash after checking whether the content is blank
  # @param [Object] key: key of the hash
  # @param [Object] content: content of the hash
  def store_nonblank(key, content)
    store(key, content) unless content.nil? || content.empty?
  end

  # --------------------------------------------------------
  # Store new hash after checking whether the content is blank
  # @param [Object] key: key of the hash
  def safe_delete(key)
    return nil unless key?(key)

    delete(key)
  end

  # --------------------------------------------------------
  # Deep sort the hash object to rearrange all the keys and all the arrays within alphabetically
  def deep_sort
    return {} if empty?

    each do |_k, v|
      if v.instance_of?(Array)
        # a = []
        mixed = false
        v.each do |e|
          if e.instance_of?(Hash)
            mixed = true
            break
          end
        end
        v.sort! unless mixed
      elsif v.instance_of?(Hash)
        v.deep_sort
      end
    end
    Hash[sort { |x, y| x <=> y }]
  end

  # --------------------------------------------------------
  # Secure fetch to avoid nil value.
  # The usage of it is same with the function fetch.
  # For example
  #   test_hash = { 'a' => 'c', 'b' => nil }
  #   test_hash.fetch('a', 1)     =>  'c'
  #   test_hash.fetch('b', 2)     =>  nil
  #   test_hash.fetch_s('a', 1)   =>  1
  #   test_hash.fetch_s('b', 2)   =>  2
  def fetch_s(key, *args, &block)
    result = fetch(key, *args, &block)
    return result if args.empty?

    result.nil? && !args[0].nil? ? args[0] : result
  end

  def stringify_keys
    h = self.map do |k,v|
      v_str = if v.instance_of? Hash
                v.stringify_keys
              else
                v
              end

      [k.to_s, v_str]
    end
    Hash[h]
  end

  def symbolize_keys
    h = self.map do |k,v|
      v_str = if v.instance_of? Hash
                v.symbolize_keys
              else
                v
              end

      [k.to_sym, v_str]
    end
    Hash[h]
  end

  #Split a hash into an array of equal-sized hashes
  def split_into(divisions)
    count = 0
    inject([]) do |final, key_value|
      final[count%divisions] ||= {}
      final[count%divisions].merge!({key_value[0] => key_value[1]})
      count += 1
      final
    end
  end
end
# ********************************************************************
# EOF
# ********************************************************************

# This class of error can be used for any nonspecific failure which will cause the current thread/process abort.
class FatalError < StandardError
end

# This derived class of FatalError is used when
#   1. All threads/processes run failed in stage 1/2 if production is set false
#   2. Any threads/processes run failed in stage 1/2 if production is set true
class AbortError < FatalError
end

# This class of error can be used for any nonspecific failure which will not cause the current thread/process abort.
class NonFatalError < StandardError
end

# This derived class of NonFatalError is used when
#   1. Not all threads/processes run failed in stage 1/2 if production is set false
class NoAbortError < NonFatalError
end
