# frozen_string_literal: true

# ********************************************************************
# Copyright 2018 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

require 'rubygems'
require 'rubygems/package'
require 'zlib'
require 'fileutils'

# ********************************************************************
# Tar archive creator script to create tar.gz file
# ********************************************************************
class Tar
  # --------------------------------------------------------
  # Creates a tar file in memory recursively from the given path
  # @param [String] +path+: path of directory to be compressed
  # @param [Array<String>] +ignored_files+: Optional list of files not to be added into package
  # @return [StringIO] returns a StringIO whose underlying String
  # is the contents of the tar file.
  def tar(path, ignored_files = [])
    tarfile = StringIO.new
    Gem::Package::TarWriter.new(tarfile) do |tar|
      Dir.glob("#{path}/**/*", File::FNM_DOTMATCH).reject { |f| f.end_with?('/.') }.each do |file|
        next if ignored_files.include? file

        mode = File.stat(file).mode
        relative_file = file.sub(/^#{Regexp::escape path}\/?/, '')
        if File.directory?(file)
          tar.mkdir relative_file, mode
        else
          tar.add_file relative_file, mode do |tf|
            File.open(file, 'rb') { |f| tf.write f.read }
          end
        end
      end
    end

    tarfile
  end

  # --------------------------------------------------------
  # gzips the underlying string in the given StringIO
  # @param [StringIO] tarfile: StringIO representing tar file
  # @return [StringIO] gzipped file StringIO
  def gzip(tarfile)
    gz = StringIO.new
    z = Zlib::GzipWriter.new(gz)
    z.write tarfile.string
    z.close # this is necessary!

    # z was closed to write the gzip footer, so
    # now we need a new StringIO
    StringIO.new gz.string
  end
end
