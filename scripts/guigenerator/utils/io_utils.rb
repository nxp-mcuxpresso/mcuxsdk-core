# Copyright 2024 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
require 'git'
require 'pathname'

module IOUtils

  def self.abs_path?(path)
    Pathname.new(path).absolute?
  end

  def self.format_path(path)
    Pathname.new(path).realpath.to_s
  end

  def self.sdkgen_abs_path(path)
    if self.abs_path? path
      Pathname.new(path).cleanpath.to_s
    else
      Pathname.new(File.expand_path(path, SDKGenerator::SDKGEN_DIR)).cleanpath.to_s
    end
  rescue
    raise "The path #{path} does not exist!"
  end

  def self.abs_path(path)
    if self.abs_path? path
      Pathname.new(path).cleanpath.to_s
    else
      Pathname.new(File.expand_path(path, Dir.pwd)).cleanpath.to_s
    end
  rescue
    raise "The directory #{path} does not exist!"
  end

  # Check whether the directory already exists, if does, remove it.
  # @param [String] src_dir: the src directory.
  # @param [String] dest_dir: the directory path to be checked.
  # @return [Nil]
  def self.safe_remove_dir(src_dir, dest_dir)
    return if src_dir.nil? || dest_dir.nil?
    src_dir = self.format_path(src_dir)
    dest_dir = Pathname.new(dest_dir).cleanpath.to_s
    return unless File.directory?(dest_dir)
    return if src_dir == dest_dir

    raise('The output directory cannot be a git repo.') if File.exist?(File.join(dest_dir, '.git'))
    raise('The output directory cannot contain the source directory (mcu-sdk-2.0 repo or a superset).') if src_dir.include? dest_dir
    puts "#{dest_dir} already exists, it will be removed."
    FileUtils.remove_dir(dest_dir)
  end

  def self.sdk_git_repo?(sdk_repo_dir)
    git_index = File.join(sdk_repo_dir, '.git')
    if File.exist?(File.join(sdk_repo_dir, 'west.yml'))
      return true
    end
    return false unless File.exist?(git_index)

    # Git worktree
    if File.file? git_index
      git_dir = File.read(git_index).split()[1]
      sdk_repo_dir = git_dir.split('.git')[0].strip
    end

    Git.open(sdk_repo_dir).remote.url.include?('mcu-sdk-2.0')
  rescue StandardError
    return false
  end

  def self.sdk_superset?(superset_dir)
    File.exist?(File.join(superset_dir, 'index.yml')) && File.exist?(File.join(superset_dir, 'sdk_generator'))
  end

  def self.sdk_repo_commit(sdk_repo_dir)
    Git.open(sdk_repo_dir, repository: File.join(sdk_repo_dir, '.git')).object('HEAD').sha
  rescue StandardError
    return 'HEAD'
  end
end