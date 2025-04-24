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
        if ENV['TEMP_BUILD_DIR']
          tmp_dir = File.basename(ENV['TEMP_BUILD_DIR'])
        else
          tmp_dir = nil
        end

        path_full = File.join(ENV['SdkRootDirPath'], path)
        build_common_root = File.dirname(ENV['build_dir'])

        # For multicore standalone project, if the path is inside common root build dir but not inside the project build dir, it
        # means the path comes from other project, so we need to translate it to full path and caclulate relative path from project build dir,
        #not just suppose it is inside the project build dir
        if ENV['SYSBUILD'] && Utils.path_inside?(path_full, build_common_root) && !Utils.path_inside?(path_full, ENV['build_dir'])
          # remove tmp dir to calculate the real relative path
          if tmp_dir && path.include?(tmp_dir)
            rel_path = path.tr('\\', '/').gsub("#{tmp_dir}/", '')

            rel_output_dir = @modifier.fullpath(@output_dir).tr('\\', '/').gsub("#{tmp_dir}/", '')

            file_rel_fullpath = File.join(rel_output_dir, '../../..', rel_path)

            return File.relpath(rel_output_dir, file_rel_fullpath)
          else
            file_fullpath = File.join(@modifier.fullpath(@output_dir), '../../..', path).tr('\\', '/')
          end
        else
          file_fullpath = File.join(@modifier.fullpath(@output_dir), path)
        end
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
