# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../_flags'

module Internal
module Xcc

    class Flags < Internal::Flags

        attr_reader :file

        def initialize(file, logger: nil)
            @file   = file
            @logger = logger ? logger : Logger.new(STDOUT)
        end

        private

        ###
        ### generic settings
        ###
    end
end
end

