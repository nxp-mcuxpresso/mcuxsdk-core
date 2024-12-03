# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/_xml_utils'

module Internal
module Cdt

    class CprojectFile

        attr_reader :xml

        private

        class DocumentOperations

            attr_reader :xml
            attr_reader :targets

            @@uid_range = 10 ** 10

            def initialize(xml, *args, logger: nil, **kwargs)
                @xml            = xml
                @logger         = logger
                @targets        = {}
                # Load all available targets in XML document and
                # mark them with no-used flag !
                nodes = @xml.xpath("/cproject/storageModule/cconfiguration")
                nodes.each do | target_node |
                    storage_node = target_node.at_xpath("./storageModule[\@moduleId=\"org.eclipse.cdt.core.settings\"]")
                    Core.assert(!storage_node.nil?) do "missing 'name' node" end
                    # and use stripped version of target name
                    target = storage_node[ 'name' ].strip.downcase
                    @targets[ target ] = {
                        'node'  => target_node,
                        'used'  => false
                    }
                end
            end

            def clear_unused_targets!()
                @targets.each do | target_key, target_item |
                    if (target_item[ 'used' ] == false)
                        target_item[ 'node' ].remove
                        @targets.delete(target_key)
                    end
                end
            end

            def get_target_name(target, *args, used: false, **kwargs)
                target_node = target_node(target, used: used)
                storage_node = target_node.at_xpath("./storageModule[\@moduleId=\"org.eclipse.cdt.core.settings\"]")
                Core.assert(!storage_node.nil?) do "missing 'name' node" end
                return storage_node[ 'name' ]
            end

            def set_target_name(target, value, *args, used: false, update_table: false, **kwargs)
                Core.assert(!update_table) do "not implemented" end
                target_node = target_node(target, used: used)
                # update '<storageModule>'
                storage_node = target_node.at_xpath("./storageModule[\@moduleId=\"org.eclipse.cdt.core.settings\"]")
                Core.assert(!storage_node.nil?) do "missing 'name' node" end
                storage_node[ 'name' ] = value
                # update '<configuration>'
                configuration_node = target_node.at_xpath("storageModule/configuration\[\@artifactName\]")
                Core.assert(!configuration_node.nil?) do
                    "<configuration> node does not exists"
                end
                configuration_node[ 'name' ] = value
            end

            def targets()
                return @targets.keys
            end

            # Get target node by target name and change it's flag to used
            # ==== arguments
            # target    - name of target
            def target_node(target, used: nil)
                Core.assert(target.is_a?(String) && !target.empty?) do
                    "param must be non-empty string"
                end
                Core.assert(!used.nil?) do 
                    "cannot be nil !"
                end
                # use stripped downcase target name as key
                target = target.strip.downcase
                Core.assert(@targets.has_key?(target)) do
                    "target '#{target}' is not present. use one of: #{@targets.keys} "
                end
                target_node = @targets[ target ][ 'node' ]
                if (used)
                    @targets[ target ][ 'used' ] = true
                end
                Core.assert(!target_node.nil?) do
                    "name '#{target}' does not exist"
                end
                return target_node
            end

            # Generate unique random number
            # TODO: force unique number
            def uid
                return rand(@@uid_range)
            end

            # create option name according arguments
            def create_option_node(parent_node, superclass, type)
                Core.assert(!parent_node.nil?) do
                    "param cannot be null"
                end
                Core.assert(superclass.is_a?(String) && !superclass.empty?) do
                    "param must be non-empty string"
                end
                Core.assert(superclass.is_a?(String) && !superclass.empty?) do
                    "param must be non-empty string"
                end
                option_node = parent_node.at_xpath("option[\@superClass = \"#{superclass}\"]")
                if (option_node.nil?)
                    option_node = Nokogiri::XML::Node.new("option", @xml)
                    option_node[ 'id' ] = "#{superclass}.#{uid}"
                    option_node[ 'superClass' ] = "#{superclass}"
                    option_node[ 'valueType' ] = type
                    parent_node << option_node
                end
                return option_node
            end

            def convert_string(value)
                Core.assert(value.is_a?(String)) do 
                    "conversion error, value '#{value}' is not a String type"
                end
                return value
            end

            def convert_enum(value, convert)
                Core.assert(convert.has_key?(value)) do
                    "conversion error, value '#{value}' does not exists in enum '#{convert.keys.join(', ')}'"
                end
                return convert[ value ]
            end

            def convert_boolean(value)
                Core.assert(value.is_a?(TrueClass) || value.is_a?(FalseClass)) do
                    "conversion error, value '#{value}' must be a 'true' or 'false'"
                end
                return value ? 'true' : 'false'
            end
        end
    end


end
end

