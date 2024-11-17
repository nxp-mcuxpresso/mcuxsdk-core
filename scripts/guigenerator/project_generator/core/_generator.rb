# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require 'logger'
require_relative '_hook'

module Core

    # abstract base class
    # provide logger class
    # provide script dir
    # provide ustruct
    class Generator

        attr_reader :logger
        attr_reader :script_dir
        attr_reader :ustruct
        attr_reader :cstruct
        attr_reader :generated_hook

        def initialize(
            ustruct:    nil,
            cstruct:    nil,
            script_dir: nil,
            logger:     nil,
            **kwarg
        )
            @logger         = logger ? logger : Logger.new(STDOUT)
            @script_dir     = script_dir
            @ustruct        = ustruct
            @cstruct        = cstruct
            @generated_hook = Hook.new()
        end
    end
end


