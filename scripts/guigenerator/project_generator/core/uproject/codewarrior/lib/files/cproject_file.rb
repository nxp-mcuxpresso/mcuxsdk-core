# frozen_string_literal: true

# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../common/files/cproject_file'

module CodeWarrior
  module Lib
    class CprojectFile < CodeWarrior::Common::CprojectFile

      def initialize(*args, **kwargs)
        super(*args, **kwargs)
        @operations = DocumentOperations.new(@xml, 'exe', logger: @logger)
      end

      class DSCCompilerTab < DSCCompilerTab
        class InputTab < InputTab
        end

        class AccessPathsTab < AccessPathsTab
        end

        class WarningsTab < WarningsTab
        end

        class OptimizationTab < OptimizationTab
        end


        class ProcessorTab < ProcessorTab
        end

        class LanguageTab < LanguageTab
        end
      end

      class DSCAssemblerTab < DSCAssemblerTab
        class InputTab < InputTab
        end

        class GeneralTab < GeneralTab
        end

        class OutputTab < OutputTab
        end
      end

      class DSCLinkerTab < DSCLinkerTab

        class InputTab < InputTab
        end

        class LinkorderTab < LinkorderTab

        end

        class GeneralTab < GeneralTab
        end

        class OutputTab < OutputTab

        end
      end
  end
  end
end
