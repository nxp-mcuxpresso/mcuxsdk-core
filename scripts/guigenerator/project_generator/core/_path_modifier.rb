# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require 'pathname'

# ********************************************************************
#
# ********************************************************************
class PathModifier
  attr_reader :rootdir
  def initialize(rootdir)
    @rootdir = rootdir
  end

  def fullpath(relpath)
    relpath = File.join(
        rootdir.gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR), relpath.gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)
    )
    relpath
  end

  def relpath(project_full_path, root_dir_path)
    Pathname.new(root_dir_path.gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)).relative_path_from(Pathname.new(project_full_path.gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR))).to_s
  end
end

