# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# frozen_string_literal: true
require 'sequel'

# @private
# This class is used to provide log id support.
# It should only be initialized and used in {#SdkgenLogger}
class LogHelper
  attr_accessor :contents

  # Init log helper.
  #
  # @param db [String] path of the database, can be file or directory
  def initialize(db=nil, validate=false)
    @validate = validate
    set_db(db) if db
  end

  # Initialize log issue database
  #
  # @param db [String] path of the database
  def set_db(db)
    @db = {}
    if File.directory? db
      Dir[db + '/**/*.yml'].each { |src| @db.merge!(YAML.load_file(src)) }
    elsif File.file?(db)
      if db.end_with?('.yml')
        @db = YAML.load_file db
      elsif db.end_with?('.db')
        @db = Sequel.sqlite(db)
      else
        raise ArgumentError
      end
    else
      raise ArgumentError
    end
    0
  rescue StandardError => _
    puts 'The input log database path is not a valid directory or file: ' + db
    -1
  end

  # Get a issue content by given id
  #
  # @param id [Object] unique id of the issue
  # @return [Object] the issue object from database
  def get(id)
    if @db.is_a? Hash
      @db[id]
    elsif @db.is_a? Sequel::SQLite::Database
      @db[:logs].where(:ID => id).first
    end
  rescue StandardError
    nil
  end
end
