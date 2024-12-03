# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../common/files/uvprojx_file'


module Mdk
  module Lib

    class UvprojxFile < Mdk::Common::UvprojxFile

      def initialize(*args, **kwargs)
        super(*args, **kwargs)
        # create shared "operations" instance
        @operations = DocumentOperations.new(@xml, logger: @logger)
        # create tab instances
        @compilerTab = CompilerTab.new(@operations)
        @assemblerTab = AssemblerTab.new(@operations)
        @linkerTab = LinkerTab.new(@operations)
        # force "library" switch
        targets.each do |target|
          @outputTab.create_library(target, true, used: false)
        end
      end
    end
  end
end

