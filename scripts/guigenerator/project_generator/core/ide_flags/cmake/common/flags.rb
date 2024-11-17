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

      def analyze_asflags(target, line)
        lists = line.split()
        lists.each do |v|
          @file.add_as_flags(target, v)
        end
      end

      def analyze_ccflags(target, line)
        lists = line.split()
        lists.each do |v|
          @file.add_cc_flags(target, v)
        end
      end

      def analyze_cxflags(target, line)
        lists = line.split()
        lists.each do |v|
          @file.add_cxx_flags(target, v)
        end
      end
    end
  end
end

