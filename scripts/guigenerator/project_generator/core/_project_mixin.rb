# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
module Mixin
  # ********************************************************************
  #
  # ********************************************************************
  module Project
    # --------------------------------------------------------
    # Create 'name' if not passed by argument as combination of 'project_name' and 'board_name'
    def standardize_name(name, board_name, project_name)
      if name.nil?
        "#{project_name}_#{board_name}"
      else
        name
      end
    end

    def path_mod(path, rootdir)
      if ENV['standalone'] == 'true'
        file_fullpath = File.join(@modifier.fullpath(@output_dir), path)
      else
        file_fullpath = File.join(ENV['SdkRootDirPath'], path)
      end
      path = File.relpath(@modifier.fullpath(@output_dir), file_fullpath)
      path = '.' if path == ''
      path
    end

    # ---------------------------------------------------------------------
    # Judge if a path is underneath the other path
    # @param [String] parent_path
    # @param [String] path The path to be judged
    # @return [nil]
    def is_underneath(parent_path, path)
      parent_rel = @modifier.fullpath(parent_path)
      path_rel = @modifier.fullpath(path)
      return true if parent_rel.tr('\\', '/') == path_rel.tr('\\', '/')
      return true if Pathname.new(path_rel.tr('\\', '/')).fnmatch?(File.join(parent_rel.tr('\\', '/'),'**'))

      false
    end
  end
end
# ********************************************************************
# EOF
# ********************************************************************
