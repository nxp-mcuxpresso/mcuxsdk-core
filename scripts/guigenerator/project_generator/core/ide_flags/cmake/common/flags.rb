# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/cmake/_flags'
require_relative '../../internal/_flags_interface'


module CMake
  module Common

    class Flags < Internal::CMake::Flags

      # consuming interface
      include Internal::FlagsInterface

      # add ${ProjDirPath} prefix to armgcc standalone project
      # because vscode plugin may run command from different directory
      def preprocess_cmd_line(line)
        # a quoted path keeps its spaces (MCUX-81203 quotes it when the build folder has one);
        # an unquoted path with spaces still cannot be delimited here
        pattern = /\s*(-include)\s+(\\?"[^"]*\\?"|\S+)\s*/
        # Process all matches in the line
        line.gsub(pattern) do |match|
          prefix = $1
          include_file = $2
          if project_root_include?(include_file)
            " #{prefix} \\\"#{File.join('${ProjDirPath}', unquote_include(include_file))}\\\" "
          else
            " #{prefix} #{include_file} "
          end
        end
      end

      def unquote_include(path)
        path.gsub(/\\?"/, '')
      end

      # the directory ${ProjDirPath} expands to, already populated when flags are analyzed
      def project_dir_path
        return @project_dir_path if defined?(@project_dir_path)

        build_dir = ENV['build_dir']
        toolchain = ENV['toolchain']
        @project_dir_path =
          if build_dir.nil? || build_dir.empty? || toolchain.nil? || toolchain.empty?
            nil
          else
            File.join(build_dir, toolchain)
          end
      end

      # A -include path is project relative only when NinjaParser translated it from an absolute
      # path (mcux_config.h). A bare file name left for the compiler to resolve through -I must
      # stay untouched. Keep the prefix unless the project root proves the header is not there.
      def project_root_include?(include_file)
        candidate = unquote_include(include_file)
        return false if candidate.empty?
        # already anchored by a variable, or absolute
        return false if candidate.start_with?('${', '$(')
        return false if candidate.match?(%r{\A([A-Za-z]:)?[/\\]})

        root = project_dir_path
        # unknown root => assume the prefix is needed, i.e. keep the pre-fix behavior
        return true if root.nil? || !File.directory?(root)

        File.exist?(File.join(root, candidate))
      end

      def analyze_asflags(target, line)
        line = preprocess_cmd_line(line)
        lists = line.split()
        lists.each do |v|
          @file.add_as_flags(target, v)
        end
      end

      def analyze_ccflags(target, line)
        line = preprocess_cmd_line(line)
        lists = line.split()
        lists.each do |v|
          @file.add_cc_flags(target, v)
        end
      end

      def analyze_cxflags(target, line)
        line = preprocess_cmd_line(line)
        lists = line.split()
        lists.each do |v|
          @file.add_cxx_flags(target, v)
        end
      end
    end
  end
end

