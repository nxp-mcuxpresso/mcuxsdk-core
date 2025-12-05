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
        pattern = /\s*(-include)\s+(\S+)\s*/
        # Process all matches in the line
        line.gsub(pattern) do |match|
          prefix = $1
          include_file = $2
          " #{prefix} #{File.join('${ProjDirPath}', include_file)} "
        end
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

