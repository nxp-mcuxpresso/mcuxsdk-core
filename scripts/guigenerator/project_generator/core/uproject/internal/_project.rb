# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../../../utils/_assert'
require_relative '../../_array'
require 'logger'
require_relative '../../_hook'
require_relative '../../../../utils/utils'

module Internal

    # Abstract project class to provide common <Project> interface.
    # This interface should satisfy requirements for some simple basic project
    # Specific <Project> classes delegate the implementation
    # to low level <File> classes
    class Project
        include Utils

        attr_reader :name
        attr_reader :templates
        attr_reader :logger
        attr_reader :type
        attr_reader :generated_hook

        # initialize attributes, create logger instance
        # ==== arguments
        # name:             - name of the project
        # project_dir:      - root directory of project source files (path to git-repo directory)
        # output_dir:       - output directory of generated files
        # templates:        - list of template files
        def initialize(param)
            Core.assert(param[:name].is_a?(String) && !param[:name].empty?) do
                "unset param 'name'"
            end
            Core.assert(param[:templates].is_a?(Array)) do
                "unset param 'templates'"
            end
            @name           = param[:name]
            @templates      = param[:templates]
            @type           = !param[:type].nil? && param[:type] == 'cpp' ? 'cpp' : 'c'
            @logger         = param[:logger] ? param[:logger] : Logger.new(STDOUT)
            @toolchain_version = param[:toolchain_version]
            @generated_hook = Hook.new()
        end

        def is_cpp_type?
            return @type == 'cpp'
        end

        def is_c_type?
            return @type == 'c'
        end
    end
end

