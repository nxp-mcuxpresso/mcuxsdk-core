# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../cdt/files/_cproject_file'
require 'logger'
require 'nokogiri'


module Internal
module Armds

    class CprojectFile < Internal::Cdt::CprojectFile

        # attr_reader :xml
        attr_reader :logger
        # attr_reader :operations

        def initialize(template, *args, logger: nil, **kwargs)
            @xml    = XmlUtils.load(template)
            @logger = logger ? logger : Logger.new(STDOUT)
        end

        private

        # Save file
        # ==== arguments
        # path      - string, file path to save
        def save(path, *args, **kargs)
            Core.assert(path.is_a?(String) && !path.empty?) do
                "param must be non-empty string"
            end
            @logger.debug("generate file: #{path}")
            XmlUtils::save(@xml, path)
        end

        def get_target_name(*args, **kwargs)
            return @operations.get_target_name(*args, **kwargs)
        end

        def set_target_name(*args, **kwargs)
            @operations.set_target_name(*args, **kwargs)
        end

        # Return list of all targets found in xml file
        def targets(*args, **kargs)
            return @operations.targets
        end

        def clear_unused_targets!(*args, **kargs)
            @operations.clear_unused_targets!
        end

        def update_rteConfig_scope(target, project_name, used: true)
            Core.assert(project_name.is_a?(String) && !project_name.empty?) do
                "param must be a non empty string"
            end
            refresh_path = "/cproject/storageModule[\@moduleId=\"com.arm.cmsis.project\"]"
            refresh_node = @xml.xpath(refresh_path )
            node = refresh_node.at_xpath("rteConfig")
            return if node.nil?
            node["name"] = "#{project_name}.rteconfig"
            Core.assert(!refresh_node.nil?) do
                "no <storageModule moduleID=\"refreshScope\"> in template"
            end
        end

        def update_refresh_scope(target, project_name, used: true)
            Core.assert(project_name.is_a?(String) && !project_name.empty?) do
                "param must be a non empty string"
            end
            # refresh_path = "/cproject/storageModule[\@moduleId=\"refreshScope\"]/configuration"
            # refresh_node = @xml.xpath(refresh_path + "[\@configurationName=\"#{target}\"]")
            # refresh_node = @xml.xpath(refresh_path + "[\@configurationName=\"#{target.capitalize}\"]") if refresh_node.count == 0
            # Core.assert(!refresh_node.nil?) do
            #     "no <storageModule moduleID=\"refreshScope\"> in template"
            # end
            # resource_node = refresh_node.at_xpath("resource[\@resourceType=\"PROJECT\"]")
            # resource_node['workspacePath'] = '/' + project_name + '/'
        end

        def add_variable(target, name, value, used: true)
            Core.assert(name.is_a?(String) && !name.empty?) do
                "param must be non empty string"
            end
            Core.assert(value.is_a?(String) && !value.empty?) do
                "param must be non empty string"
            end
            target_node = @operations.target_node(target, used: used)
            parent_node = target_node.at_xpath("storageModule[\@moduleId=\"org.eclipse.cdt.core.settings\"]/macros")
            if (parent_node.nil?)
                storage_node = target_node.at_xpath("storageModule[\@moduleId=\"org.eclipse.cdt.core.settings\"]")
                Core.assert(!storage_node.nil?) do
                    "no <storageModule>"
                end
                parent_node = Nokogiri::XML::Node.new("macros", @operations.xml)
                storage_node << parent_node
            end
            macro_node = Nokogiri::XML::Node.new("stringMacro", @operations.xml)
            macro_node[ 'name' ] = name
            macro_node[ 'value' ] = value
            parent_node << macro_node
        end

        def clear_variables!(target, *args, used: false, **kargs)
            target_node = @operations.target_node(target, used: used)
            collection = target_node.xpath("storageModule[\@moduleId=\"org.eclipse.cdt.core.settings\"]/macros/*")
            collection.remove() unless (collection.nil?)
        end

        def artifact_name(target, value, compiler, *args, used: true, **kargs)
            target_node = @operations.target_node(target, used: used)
            configuration_node = target_node.at_xpath("storageModule/configuration\[\@artifactName\]")
            Core.assert(!configuration_node.nil?) do
                "<configuration> node does not exists"
            end
            configuration_node[ 'artifactName' ] = value
        end

        def artifact_extension(target, value, compiler, *args, used: true, **kargs)
            target_node = @operations.target_node(target, used: used)
            configuration_node = target_node.at_xpath("storageModule/configuration\[\@artifactName\]")
            Core.assert(!configuration_node.nil?) do
                "<configuration> node does not exists"
            end
            configuration_node[ 'artifactExtension' ] = value
        end

        def artifact_prefix_linker(target, value, compiler, *args, used: true, **kargs)
            superClass = if compiler == 'armcc'
                             'com.arm.tool.c.linker.base.var.arm_compiler_5-5'
                         elsif compiler == 'armclang'
                             'com.arm.tool.c.linker.v6.base.var.arm_compiler_6-6'
                         end
            xpath = @operations.xpath_variant("storageModule/configuration/folderInfo/toolChain/tool[\@superClass = \"#{superClass}\"]")
            tool_node = @operations.target_node(target, used: used).at_xpath(xpath)
            Core.assert(!tool_node.nil?) do
                "missing tool node"
            end
            tool_node[ 'outputPrefix' ] = value
        end

        def prebuildstep_command(target, value, compiler, *args, used: true, **kargs)
            target_node = @operations.target_node(target, used: used)
            configuration_node = target_node.at_xpath("storageModule/configuration\[\@artifactName\]")
            Core.assert(!configuration_node.nil?) do
                "<configuration> node does not exists"
            end
            configuration_node[ 'prebuildStep' ] = value
        end

        def postbuildstep_command(target, value, compiler, *args, used: true, **kargs)
            target_node = @operations.target_node(target, used: used)
            configuration_node = target_node.at_xpath("storageModule/configuration\[\@artifactName\]")
            Core.assert(!configuration_node.nil?) do
                "<configuration> node does not exists"
            end
            configuration_node[ 'postbuildStep' ] = value
        end
        def builder(target, value, compiler, *args, used: true, **kargs)
            Core.assert(['external', 'internal'].include?(value)) do
                "invalud vaue '#{value}' use one of 'external, internal'"
            end
            builder_node = @operations.get_general_node(target, used: used).at_xpath('builder[@superClass="org.eclipse.cdt.build.core.internal.builder"]')
            unless(builder_node)
                builder_node = @operations.get_general_node(target, used: used).at_xpath('builder[@superClass="com.arm.toolchain.baremetal.builder"]')
            end
            unless(builder_node)
                builder_node =  @operations.get_general_node(target, used: used).at_xpath("builder")
            end
            Core.assert(builder_node, "builder node does not exists")
            if (value == 'internal')
                builder_node[ 'superClass' ] = 'org.eclipse.cdt.build.core.internal.builder'
            else (value == 'external')
                builder_node[ 'superClass' ] = 'com.arm.toolchain.baremetal.builder'
            end
        end


        #now in the DS-MDK tool project template not have those option.

        def create_flash_image(target, value, compiler, *args, used: true, **kargs)
            # @operations.set_general_option(
            #     target, 'ilg.gnuarmeclipse.managedbuild.cross.option.addtools.createflash', "boolean", @operations.convert_boolean(value), used: used
            # )
        end

        def create_flash_choice(target, value, compiler, *args, used: true, **kargs)
            # format_map = {
            #     'srec' => 'srec',
            #     'symbolsrec' => 'symbolsrec',
            #     'bin'  => 'binary',
            #     'hex'  => 'ihex',
            # }
            # Core.assert(format_map.has_key?(value)) do
            #             "type '#{value}' is not valid"
            # end
            # name = 'ilg.gnuarmeclipse.managedbuild.cross.option.createflash.choice'
            # @operations.set_flash_image_option(
            #     target, name, "enumerated", "#{name}.#{format_map[value]}", used: used
            # )
        end

        def create_extended_listing(target, value, compiler, *args, used: true, **kargs)
            # @operations.set_general_option(
            #     target, 'ilg.gnuarmeclipse.managedbuild.cross.option.addtools.createlisting', "boolean", @operations.convert_boolean(value), used: used
            # )
        end

        def print_size(target, value, compiler, *args, used: true, **kargs)
            # @operations.set_general_option(
            #     target, 'ilg.gnuarmeclipse.managedbuild.cross.option.addtools.printsize', "boolean", @operations.convert_boolean(value), used: used
            # )
        end

        private

        # Base tab class to inherit @operations attribute
        class TabBase

            attr_reader :operations

            def initialize(operations, *args, **kwargs)
                @operations = operations
            end
        end

        class DocumentOperations < DocumentOperations

            # attr_reader :variant

            def initialize(xml, variant, *args, **kwargs)
                Core.assert(!xml.nil?) do
                    "param cannot be nil"
                end
                Core.assert(variant.is_a?(String)) do
                    "param must be string"
                end
                Core.assert(['lib', 'exe'].include?(variant)) do
                    "invalid variant '#{variant}'"
                end
                super
                @variant = variant
            end

            # perform trick and modify xpath according 'exe' or 'lib' type
            def xpath_variant(xpath)
                # xpath.gsub!('.lib.', ".#{@variant}.")
                # xpath.gsub!('.exe.', ".#{@variant}.")
                # xpath.gsub!('.lib', ".#{@variant}")
                # xpath.gsub!('.exe', ".#{@variant}")
                return xpath
            end

            def get_compiler_node(target, compiler, used: nil)
                superClass = if compiler == 'armcc'
                                 'com.arm.tool.c.compiler.baremetal.exe'
                             elsif compiler == 'armclang'
                                 'com.arm.tool.c.compiler.v6.base.var.arm_compiler_6-6'
                             end
                xpath = xpath_variant(
                    "storageModule/configuration/folderInfo/toolChain/tool[contains(\@superClass,#{superClass})]"
                )
                parent_node = target_node(target, used: used).at_xpath(xpath)
                Core.assert(!parent_node.nil?)
                return parent_node
            end

            def get_cpp_compiler_node(target, compiler, used: nil)
                superClass = if compiler == 'armcc'
                                 'com.arm.tool.cpp.compiler.baremetal.exe'
                             elsif compiler == 'armclang'
                                 'com.arm.tool.cpp.compiler.v6.base.var.arm_compiler_6-6'
                             end
                xpath = xpath_variant(
                    "storageModule/configuration/folderInfo/toolChain/tool[contains(\@superClass,#{superClass})]"
                )
                parent_node = target_node(target, used: used).at_xpath(xpath)
                Core.assert(!parent_node.nil?)
                return parent_node
            end

            def create_compiler_option(target, superclass, valtype, compiler, used: nil)
                # allowed = {'boolean' => 1, 'enumerated' => 1, 'string' => 1, 'definedSymbols' => 1, 'includePath' => 1, 'stringList' => 1}
                allowed = {
                    'boolean'               => 1,
                    'definedSymbols'        => 1,
                    'includePath'           => 1,
                    'undefDefinedSymbols'   => 1,
                    'includeFiles'          => 1,
                    'enumerated'            => 1,
                    'string'                => 1,
                    'stringList'            => 1,
                }
                Core.assert(superclass.is_a?(String) && !superclass.empty?) do
                    "param must be non empty string"
                end
                Core.assert(valtype.is_a?(String) && !valtype.empty?) do
                    "param must be non empty string"
                end
                # prevent typo, check the 'valtype' against list of valid/supported types
                Core.assert(allowed.has_key?(valtype)) do
                    "type '#{valtype}' is not valid"
                end
                # convert 'superclass' to current 'variant' type
                superclass = xpath_variant(superclass)
                # try to find superclass '<option>' node
                option_node = target_node(target, used: used).at_xpath(
                    "storageModule/configuration/folderInfo/toolChain/tool/option[\@superClass=\"#{superclass}\"]"
                )
                # if not present, create new one
                if (option_node.nil?)
                    option_node = create_option_node(
                        get_compiler_node(target, compiler, used: used), superclass, valtype
                    )
                end
                return option_node
            end

            def create_cpp_compiler_option(target, superclass, valtype, compiler, used: nil)
                # allowed = {'boolean' => 1, 'enumerated' => 1, 'string' => 1, 'definedSymbols' => 1, 'includePath' => 1, 'stringList' => 1}
                allowed = {
                    'boolean'               => 1,
                    'definedSymbols'        => 1,
                    'includePath'           => 1,
                    'undefDefinedSymbols'   => 1,
                    'includeFiles'          => 1,
                    'enumerated'            => 1,
                    'string'                => 1,
                }
                Core.assert(superclass.is_a?(String) && !superclass.empty?) do
                    "param must be non empty string"
                end
                Core.assert(valtype.is_a?(String) && !valtype.empty?) do
                    "param must be non empty string"
                end
                # prevent typo, check the 'valtype' against list of valid/supported types
                Core.assert(allowed.has_key?(valtype)) do
                    "type '#{valtype}' is not valid"
                end
                # convert 'superclass' to current 'variant' type
                superclass = xpath_variant(superclass)
                # try to find superclass '<option>' node
                option_node = target_node(target, used: used).at_xpath(
                    "storageModule/configuration/folderInfo/toolChain/tool/option[\@superClass = \"#{superclass}\"]"
                )
                # if not present, create new one
                if (option_node.nil?)
                    option_node = create_option_node(
                        get_cpp_compiler_node(target, compiler, used: used), superclass, valtype
                    )
                end
                return option_node
            end

            def set_compiler_option(target, superclass, valtype, compiler, value, used: nil)
                option_node = create_compiler_option(target, superclass, valtype, compiler, used: used)
                option_node[ 'value' ] = value.to_s
            end

            def set_cpp_compiler_option(target, superclass, valtype, compiler, value, used: nil)
                option_node = create_cpp_compiler_option(target, superclass, valtype, compiler, used: used)
                option_node[ 'value' ] = value.to_s
            end

            def get_assembler_node(target, compiler, used: nil)
                superClass = if compiler == 'armcc'
                                 'com.arm.tool.assembler.base.var.arm_compiler_5-5'
                             elsif compiler == 'armclang'
                                 'com.arm.tool.assembler.v6.base.var.arm_compiler_6-6'
                             end
                xpath = xpath_variant(
                    "storageModule/configuration/folderInfo/toolChain/tool[\@superClass=\"#{superClass}\"]"
                )
                parent_node = target_node(target, used: used).at_xpath(xpath)
                Core.assert(!parent_node.nil?)
                return parent_node
            end

            def create_assembler_option(target, superclass, valtype, compiler, used: nil)
                # allowed = {'boolean' => 1, 'enumerated' => 1, 'string' => 1, 'stringList' => 1}
                allowed = {
                    'boolean'               => 1,
                    'definedSymbols'        => 1,
                    'includePath'           => 1,
                    'undefDefinedSymbols'   => 1,
                    'includeFiles'          => 1,
                    'enumerated'            => 1,
                    'string'                => 1,
                    'stringList'            => 1,
                }
                Core.assert(superclass.is_a?(String) && !superclass.empty?) do
                    "param must be non empty string"
                end
                Core.assert(valtype.is_a?(String) && !valtype.empty?) do
                    "param must be non empty string"
                end
                # prevent typo, check the 'valtype' against list of valid/supported types
                Core.assert(allowed.has_key?(valtype)) do
                    "type '#{valtype}' is not valid"
                end
                # convert 'superclass' to current 'variant' type
                superclass = xpath_variant(superclass)
                # try to find superclass '<option>' node
                option_node = target_node(target, used: used).at_xpath(
                    "storageModule/configuration/folderInfo/toolChain/tool/option[\@superClass = \"#{superclass}\"]"
                )
                # if not present, create new one
                if (option_node.nil?)
                    option_node = create_option_node(
                        get_assembler_node(target, compiler, used: used), superclass, valtype
                    )
                end
                return option_node
            end

            def set_assembler_option(target, superclass, valtype, compiler, value, used: nil)
                option_node = create_assembler_option(target, superclass, valtype, compiler, used: used)
                option_node[ 'value' ] = value.to_s
            end

            def get_linker_node(target, compiler, used: nil)
                superClass = if compiler == 'armcc'
                                 'com.arm.tool.c.linker.base.var.arm_compiler_5-5'
                             elsif compiler == 'armclang'
                                 'com.arm.tool.c.linker.v6.base.var.arm_compiler_6-6'
                             end
                xpath = xpath_variant(
                    "storageModule/configuration/folderInfo/toolChain/tool[\@superClass=\"#{superClass}\"]"
                )
                parent_node = target_node(target, used: used).at_xpath(xpath)
                Core.assert(!parent_node.nil?)
                return parent_node
            end

            def get_cpp_linker_node(target, used: nil)
                xpath = xpath_variant(
                    "storageModule/configuration/folderInfo/toolChain/tool[\@superClass = \"com.arm.tool.cpp.linker.base.var.arm_compiler_5-5\"]"
                )
                parent_node = target_node(target, used: used).at_xpath(xpath)
                Core.assert(!parent_node.nil?)
                return parent_node
            end

            def create_linker_option(target, superclass, valtype, compiler, used: nil)
                allowed = {
                    'boolean'               => 1,
                    'userObjs'              => 1,
                    'stringList'            => 1,
                    'enumerated'            => 1,
                    'libs'                  => 1,
                    'libPaths'              => 1,
                    'string'                => 1,
                }
                #, 'enumerated' => 1, 'string' => 1, 'stringList' => 1}
                Core.assert(superclass.is_a?(String) && !superclass.empty?) do
                    "param must be non empty string"
                end
                Core.assert(valtype.is_a?(String) && !valtype.empty?) do
                    "param must be non empty string"
                end
            # prevent typo, check the 'valtype' against list of valid/supported types
                Core.assert(allowed.has_key?(valtype)) do
                    "type '#{valtype}' is not valid"
                end
            # convert 'superclass' to current 'variant' type
                superclass = xpath_variant(superclass)
            # try to find superclass '<option>' node
                option_node = target_node(target, used: used).at_xpath(
                    "storageModule/configuration/folderInfo/toolChain/tool/option[\@superClass = \"#{superclass}\"]"
                )
            # if not present, create new one
                if (option_node.nil?)
                    option_node = create_option_node(
                        get_linker_node(target, compiler, used: used), superclass, valtype
                    )
                end
                return option_node
            end


            def create_cpp_linker_option(target, superclass, valtype, used: nil)
                allowed = {
                    'boolean'               => 1,
                    'userObjs'              => 1,
                    'stringList'            => 1,
                    'enumerated'            => 1,
                    'libs'                  => 1,
                    'libPaths'              => 1,
                    'string'                => 1,
                }
                #, 'enumerated' => 1, 'string' => 1, 'stringList' => 1}
                Core.assert(superclass.is_a?(String) && !superclass.empty?) do
                    "param must be non empty string"
                end
                Core.assert(valtype.is_a?(String) && !valtype.empty?) do
                    "param must be non empty string"
                end
            # prevent typo, check the 'valtype' against list of valid/supported types
                Core.assert(allowed.has_key?(valtype)) do
                    "type '#{valtype}' is not valid"
                end
            # convert 'superclass' to current 'variant' type
                superclass = xpath_variant(superclass)
            # try to find superclass '<option>' node
                option_node = target_node(target, used: used).at_xpath(
                    "storageModule/configuration/folderInfo/toolChain/tool/option[\@superClass = \"#{superclass}\"]"
                )
            # if not present, create new one
                if (option_node.nil?)
                    option_node = create_option_node(
                        get_cpp_linker_node(target, used: used), superclass, valtype
                    )
                end
                return option_node
            end

            def set_linker_option(target, superclass, valtype, compiler, value, used: nil)
                option_node = create_linker_option(target, superclass, valtype, compiler, used: used)
                option_node[ 'value' ] = value.to_s
            end

            def set_cpp_linker_option(target, superclass, valtype, value, used: nil)
                option_node = create_cpp_linker_option(target, superclass, valtype, used: used)
                option_node[ 'value' ] = value.to_s
            end

            def get_general_node(target, used: nil)
                xpath = "storageModule/configuration/folderInfo/toolChain[contains(\@superClass,'com.arm.toolchain.baremetal.exe')]"
                parent_node = target_node(target, used: used).at_xpath(xpath)
                Core.assert(!parent_node.nil?)
                return parent_node
            end

            def create_general_option(target, superclass, valtype, used: nil, parent_node: "storageModule/configuration/folderInfo/toolChain/option")
                allowed = {
                    'string'                => 1,
                    'enumerated'            => 1,
                    'boolean'               => 1,
                }
                Core.assert(superclass.is_a?(String) && !superclass.empty?) do
                    "param must be non empty string"
                end
                Core.assert(valtype.is_a?(String) && !valtype.empty?) do
                    "param must be non empty string"
                end
            # prevent typo, check the 'valtype' against list of valid/supported types
                Core.assert(allowed.has_key?(valtype)) do
                    "type '#{valtype}' is not valid"
                end
            # convert 'superclass' to current 'variant' type
                superclass = xpath_variant(superclass)
            # try to find superclass '<option>' node
                option_node = target_node(target, used: used).at_xpath(
                    "#{parent_node}[\@superClass=\"#{superclass}\"]"
                )
            # if not present, create new one
                if (option_node.nil?)
                    option_node = create_option_node(
                        get_general_node(target, used: used), superclass, valtype
                    )
                end
                return option_node
            end

            def set_general_option(target, superclass, valtype, value, used: nil, parent_node: "storageModule/configuration/folderInfo/toolChain/option")
                option_node = create_general_option(target, superclass, valtype, used: used, parent_node: parent_node)
                option_node[ 'value' ] = value.to_s
            end
        end


        class GenericTab < TabBase

            class TargetProcessorTab < TabBase

                private

                def cpu_fpu_type(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_general_option(
                        target, "com.arm.toolchain.ac5.option.target.cpu_fpu", "string",
                        @operations.convert_string(value), used: used
                    )
                    option_node = @operations.set_general_option(
                        target, "com.arm.tool.c.compiler.option.targetcpu", "string",
                        @operations.convert_string(value), used: used
                    )
                end

                def endian(target, value, compiler, *args, used: true, **kargs)
                    conv = { 'little' => 'little', 'big' => 'big', 'default' => 'default' }
                    @operations.set_general_option(
                        target, 'com.arm.toolchain.ac5.option.endian', "enumerated", "com.arm.toolchain.ac5.option.endian.#{@operations.convert_enum(value, conv)}", used: used
                    )
                end

                 def set_fppcs(target, value, compiler, *args, used: true, **kargs)
                     node_value = if value == ''
                                      ''
                                  else
                                      ".#{value}"
                                  end
                    @operations.set_general_option(
                        target, 'com.arm.toolchain.ac5.option.fppcs', "enumerated", "com.arm.toolchain.ac5.option.fppcs#{node_value}", used: used
                    )
                end

                def set_inst(target, value, compiler, *args, used: true, **kargs)
                    conv = { 'arm' => 'arm', 'thumb' => 'thumb', 'default' => 'default' }
                    @operations.set_general_option(
                        target, 'com.arm.toolchain.ac5.option.inst', "enumerated", "com.arm.toolchain.ac5.option.inst.#{@operations.convert_enum(value, conv)}", used: used
                    )
                end

                def add_other_flag(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.create_general_option(
                        target, "com.arm.toolchain.ac5.option.other", "string", used: used
                    )
                    option_node[ 'value' ] = option_node[ 'value' ] ? "#{option_node[ 'value' ]} #{value}" : "#{value}"
                end

                def clear_other_flags!(target, *args, used: true, **kargs)
                   @operations.set_general_option(
                        target, "com.arm.toolchain.ac5.option.other", "string", '', used: used
                    )
                end
            end

            class OptimizationTab < TabBase

                private
            end

            class  WarningsTab < TabBase
                private
            end

            class DebuggingTab < TabBase
                private
            end

        end


        class ArmAssemblerTab < TabBase

            private

            class TargetTab < TabBase

                def enable_tool_setting(target, value, compiler, *args, used: true, **kargs)
                    superClass =  if compiler == 'armcc'
                                      "com.arm.tool.assembler.option.target.enableToolSpecificSettings"
                                  else
                                      "com.arm.tool.assembler.v6.base.options.target.enableToolSpecificSettings"
                                  end
                    option_node = @operations.set_assembler_option(
                        target, superClass, "boolean", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

                def cpu_fpu_type(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.option.cpu", "string", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

                def set_fppcs(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    if compiler == 'armcc'
                        superClass = 'com.arm.tool.assembler.option.fppcs'
                        fpu = convert[value]
                    else
                        superClass = 'com.arm.tool.assembler.v6.base.option.floatabi'
                        fpu = "com.arm.tool.c.compiler.v6.base.option.floatabi.#{value}"
                    end
                    option_node = @operations.set_assembler_option(
                        target, superClass, "enumerated",compiler,
                        @operations.convert_string(fpu), used: used
                    )
                end

                def set_fp_mode(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.option.fpmode", "enumerated",
                        @operations.convert_string("com.arm.tool.c.compiler.option.fpmode.#{value}"), used: used
                    )
                end

                def set_inst(target, value, compiler, *args, used: true, **kargs)
                    if compiler ==  'armcc'
                        superClass = 'com.arm.tool.assembler.option.inst'
                        inst = "com.arm.tool.assembler.option.inst.#{value}"
                    else
                        superClass = 'com.arm.tool.assembler.v6.base.option.inst'
                        inst = "com.arm.tool.c.compiler.v6.base.option.inst.#{value}"
                    end
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_assembler_option(
                        target, superClass, "enumerated", compiler,
                        @operations.convert_string(inst), used: used
                    )
                end

                def endian(target, value, compiler, *args, used: true, **kargs)
                    convert = {
                        'bigend' => 'com.arm.tool.c.compiler.option.endian.big',
                        'littleend' => 'com.arm.tool.c.compiler.option.endian.little',
                        'auto' => 'com.arm.tool.c.compiler.option.endian.auto'
                    }
                    if compiler == 'armcc'
                        superClass = "com.arm.tool.assembler.option.endian"
                        order = convert[value]
                    else
                        superClass = "com.arm.tool.assembler.v6.base.option.endian"
                        order = "com.arm.tool.c.compiler.v6.base.option.endian.#{value}"
                    end
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_assembler_option(
                        target, superClass, "enumerated", compiler,
                        @operations.convert_string(order), used: used
                    )
                end

                def interwork(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.option.inter", "boolean", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

                def aligned_access(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.option.unalign", "boolean", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

                #armclang specific
                def target(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.v6.base.option.target", "string", compiler, value, used: used
                    )
                end

                def arch(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.v6.base.option.arch", "string", compiler, value, used: used
                    )
                end

                def cpu_type(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_assembler_option(
                        target, 'com.arm.tool.assembler.v6.base.option.cpu', "string", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

                def fpu_type(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_assembler_option(
                        target, 'com.arm.tool.assembler.v6.base.option.fpu', "string", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

            end

            class PreprocessorTab < TabBase

                def use_microlib(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     'com.arm.tool.assembler.option.useMicroLib'
                                 else
                                     'com.arm.tool.assembler.v6.base.useMicroLib'
                                 end
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_assembler_option(
                        target, superClass, "boolean", compiler, @operations.convert_string(value), used: used
                    )
                end

                def preprocess_input(target, value, compiler, *args, used: true, **kargs)
                    superClass = 'com.arm.tool.assembler.v6.base.option.force.preproc'
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_assembler_option(
                        target, superClass, "boolean", compiler, @operations.convert_string(value), used: used
                    )
                end

                def preprocess_only(target, value, compiler, *args, used: true, **kargs)
                    superClass = 'com.arm.tool.assembler.v6.base.option.preproconly'
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_assembler_option(
                        target, superClass, "boolean", compiler, @operations.convert_string(value), used: used
                    )
                end

                def preprocess(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.option.preproc", "boolean", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

                def preprocess_options(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.option.preprocflags", "string", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

                def add_define(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     "com.arm.tool.assembler.option.predefine"
                                 else
                                     "com.arm.tool.assembler.v6.base.option.defmac"
                                 end
                    option_node = @operations.create_assembler_option(
                        target, superClass, "stringList", compiler, used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = value
                    option_node << listopt_node
                end

                def clear_defines!(target, compiler, *args, used: false, **kargs)
                    option_node = if compiler == 'armcc'
                                      @operations.create_assembler_option(
                                          target, "com.arm.tool.assembler.option.implicit.incpath", "stringList", compiler, used: used
                                      )
                                  elsif compiler == 'armclang'
                                      @operations.create_assembler_option(
                                          target, "com.arm.tool.assembler.v6.base.option.incpath", "stringList", compiler, used: used
                                      )
                                  end
                    collection = option_node.xpath('*')
                    collection.remove() unless(collection.nil?)
                end

                private

                def enable_tool_setting(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.v6.base.options.preproc.enableToolSpecificSettings", "boolean", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

            end

            class IncludesTab < TabBase

                private
                def add_include(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     "com.arm.tool.assembler.option.incpath"
                                 else
                                     "com.arm.tool.assembler.v6.base.option.incpath"
                                 end
                    option_node = @operations.create_assembler_option(
                        target, superClass, "includePath", compiler, used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = @operations.convert_string(value)
                    option_node << listopt_node
                end

                def clear_include!(target, compiler, *args, used: false, **kargs)
                    option_node = if compiler == 'armcc'
                                      @operations.create_assembler_option(
                                          target, "com.arm.tool.assembler.option.implicit.incpath", "includePath", compiler, used: used
                                      )
                                  elsif compiler == 'armclang'
                                      @operations.create_assembler_option(
                                          target, "com.arm.tool.assembler.v6.base.option.incpath", "includePath", compiler, used: used
                                      )
                                  end
                    collection = option_node.xpath('*')
                    collection.remove() unless(collection.nil?)
                end
            end

            class DebuggingTab < TabBase

                private

                def enable_debug(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.option.debug", "boolean", value, used: used
                    )
                end

                def debug_format(target, value, compiler, *args, used: false, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.option.debug.format", "enumerated", compiler,
                        "com.arm.tool.c.compiler.options.debug.format.#{value}", used: used
                    )
                end

                def debug_level(target, value, compiler, *args, used: false, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.v6.base.options.debug.level", "enumerated", compiler,
                        "com.arm.tool.assembler.v6.base.options.debug.level.#{value}", used: used
                    )
                end

                def enable_tool_setting(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     "com.arm.tool.assembler.option.debug.enableToolSpecificSettings"
                                 else
                                     "com.arm.tool.assembler.v6.base.options.debug.enableToolSpecificSettings"
                                 end
                    option_node = @operations.set_assembler_option(
                        target, superClass, "boolean", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

            end

            class WarningsAndErrorsTab < TabBase

                private

                def error_severity(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.option.err", "string", compiler, value, used: used
                    )
                end

                def warning_severity(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.option.warn", "string", compiler, value, used: used
                    )
                end

                def remark_severity(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.option.rem", "string", compiler, value, used: used
                    )
                end

                def suppress(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.option.sup", "string", compiler, value, used: used
                    )
                end

                def suppress_warnings(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.v6.base.option.suppresswarn", "boolean", compiler, value, used: used
                    )
                end

                def warning_as_error(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.v6.base.option.warnaserr", "boolean", compiler, value, used: used
                    )
                end

                def all_warnings(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.v6.base.option.warnall", "boolean", compiler, value, used: used
                    )
                end
            end

            class MiscellaneousTab < TabBase

                private

                def add_other_flag(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     "com.arm.tool.assembler.option.flags"
                                 else
                                     "com.arm.tool.assembler.v6.base.option.flags"
                                 end
                    option_node = @operations.create_assembler_option(
                        target, superClass, "stringList", compiler, used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = value
                    option_node << listopt_node
                end

                def syntax(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_assembler_option(
                        target, "com.arm.tool.assembler.v6.base.option.masm", "enumerated", compiler, "masm.val.#{value}", used: used
                    )
                end
            end
        end


        class ArmCCompilerTab < TabBase

            private

            class TargetTab < TabBase

                @@parent_node = "storageModule/configuration/folderInfo/toolChain/tool/option"

                def enable_tool_setting(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     'com.arm.tool.c.compiler.option.target.enableToolSpecificSettings'
                                 else
                                     'com.arm.tool.c.compiler.v6.base.options.target.enableToolSpecificSettings'
                                 end
                    option_node = @operations.set_compiler_option(
                        target, superClass, "boolean", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

                def set_inst(target, value, compiler, *args, used: true, **kargs)
                    if compiler ==  'armcc'
                        superClass = 'com.arm.tool.c.compiler.option.inst'
                        inst = "com.arm.tool.c.compiler.option.inst.#{value}"
                    else
                        superClass = 'com.arm.tool.c.compiler.v6.base.option.inst'
                        inst = "com.arm.tool.c.compiler.v6.base.option.inst.#{value}"
                    end
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_compiler_option(
                        target, superClass, "enumerated", compiler,
                        @operations.convert_string(inst), used: used
                    )
                end

                def endian(target, value, compiler, *args, used: true, **kargs)
                    convert = {
                        'bigend' => 'com.arm.tool.c.compiler.option.endian.big',
                        'littleend' => 'com.arm.tool.c.compiler.option.endian.little',
                        'auto' => 'com.arm.tool.c.compiler.option.endian.auto'
                    }
                    if compiler == 'armcc'
                        superClass = "com.arm.tool.c.compiler.option.endian"
                        order = convert[value]
                    else
                        superClass = "com.arm.tool.c.compiler.v6.base.option.endian"
                        order = "com.arm.tool.c.compiler.v6.base.option.endian.#{value}"
                    end
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_compiler_option(
                        target, superClass, "enumerated", compiler,
                        @operations.convert_string(order), used: used
                    )
                end

                def char_size(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.option.charsize", "enumerated",
                        "com.arm.tool.c.compiler.option.enum.#{value}", used: used
                    )
                end

                def interwork(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.option.inter", "boolean", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

                def aligned_access(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.option.unalign", "boolean",
                        @operations.convert_string(value), used: used
                    )
                end

                def enum_as_int(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.option.enum", "boolean",
                        @operations.convert_string(value), used: used
                    )
                end

                def cpu_fpu_type(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     'com.arm.tool.c.compiler.option.targetcpu'
                                 else
                                     'com.arm.tool.c.compiler.v6.base.option.cpu'
                                 end
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_compiler_option(
                        target, superClass, "string", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

                def set_fppcs(target, value, compiler, *args, used: true, **kargs)
                    convert = {
                        'hard' => 'com.arm.tool.c.compiler.option.fppcs.hard',
                        'soft' => 'com.arm.tool.c.compiler.option.fppcs',
                        'auto' => 'com.arm.tool.c.compiler.option.fppcs.auto'
                    }
                    enable_tool_setting(target,'true', compiler)
                    if compiler == 'armcc'
                        superClass = 'com.arm.tool.c.compiler.option.fppcs'
                        fpu = convert[value]
                    else
                        superClass = 'com.arm.tool.c.compiler.v6.base.option.floatabi'
                        fpu = "com.arm.tool.c.compiler.v6.base.option.floatabi.#{value}"
                    end
                    option_node = @operations.set_compiler_option(
                        target, superClass, "enumerated", compiler,
                        @operations.convert_string(fpu), used: used
                    )
                end

                def set_fp_mode(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.option.fpmode", "enumerated", compiler,
                        @operations.convert_string("com.arm.tool.c.compiler.option.fpmode.#{value}"), used: used
                    )
                end

                #armclang specific
                def target(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.v6.base.option.target", "string", compiler, value, used: used
                    )
                end

                def arch(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.v6.base.option.arch", "string", compiler, value, used: used
                    )
                end

                def cpu_type(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_compiler_option(
                        target, 'com.arm.tool.c.compiler.v6.base.option.cpu', "string", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

                def fpu_type(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_compiler_option(
                        target, 'com.arm.tool.c.compiler.v6.base.option.fpu', "string", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

                def vectorization(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_compiler_option(
                        target, 'com.arm.tool.c.compiler.v6.base.option.vector', "boolean", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

            end

            class PreprocessorTab < TabBase

                private

                def enable_tool_setting(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     'com.arm.tool.c.compiler.option.preproc.enableToolSpecificSettings'
                                 else
                                     'com.arm.tool.c.compiler.v6.base.options.preproc.enableToolSpecificSettings'
                                 end
                    option_node = @operations.set_compiler_option(
                        target, superClass, "boolean", compiler, @operations.convert_string(value), used: used
                    )
                end

                def use_microlib(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     'com.arm.tool.c.compiler.option.useMicroLib'
                                 else
                                     'com.arm.tool.c.compiler.v6.base.useMicroLib'
                                 end
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_compiler_option(
                        target, superClass, "boolean", compiler, @operations.convert_string(value), used: used
                    )
                end

                def preprocess_only(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     'com.arm.tool.c.compiler.option.preproconly'
                                 else
                                     'com.arm.tool.c.compiler.v6.base.option.preproconly'
                                 end
                    option_node = @operations.set_compiler_option(
                        target, superClass, "boolean", compiler, @operations.convert_string(value), used: used
                    )
                end

                def add_implicit_define(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.option.implicit.defmac", "definedSymbols", used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = @operations.convert_string(value)
                    option_node << listopt_node
                end

                def add_define(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     'com.arm.tool.c.compiler.option.defmac'
                                 else
                                     'com.arm.tool.c.compiler.v6.base.option.defmac'
                                 end
                    option_node = @operations.create_compiler_option(
                        target, superClass, "definedSymbols", compiler, used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = @operations.convert_string(value)
                    option_node << listopt_node
                end

                def add_undefine(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     'com.arm.tool.c.compiler.option.undefmac'
                                 else
                                     'com.arm.tool.c.compiler.v6.base.option.undefmac'
                                 end
                    option_node = @operations.create_compiler_option(
                        target, superClass, "undefDefinedSymbols", compiler, used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = @operations.convert_string(value)
                    option_node << listopt_node
                end

                def clear_defines!(target, compiler, *args, used: false, **kargs)
                    option_node = if compiler == 'armcc'
                                      @operations.create_compiler_option(
                                          target, "com.arm.tool.c.compiler.option.defmac", "definedSymbols", compiler, used: used
                                      )
                                  elsif compiler == 'armclang'
                                      @operations.create_compiler_option(
                                          target, "com.arm.tool.c.compiler.v6.base.option.defmac", "definedSymbols", compiler, used: used
                                      )
                                  end
                    collection = option_node.xpath('*')
                    collection.remove() unless(collection.nil?)
                end
            end

            class IncludesTab < TabBase

                private

                def add_include(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     'com.arm.tool.c.compiler.option.incpath'
                                 else
                                     'com.arm.tool.c.compiler.v6.base.option.incpath'
                                 end
                    option_node = @operations.create_compiler_option(
                        target, superClass, "includePath", compiler, used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = @operations.convert_string(value)
                    option_node << listopt_node
                end

                def add_pre_include(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     'com.arm.tool.c.compiler.option.preinc'
                                 else
                                     'com.arm.tool.c.compiler.v6.base.option.preinc'
                                 end
                    option_node = @operations.create_compiler_option(
                        target, superClass, "includeFiles", compiler, used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = @operations.convert_string(value)
                    option_node << listopt_node
                end

                def add_sys_include(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     'com.arm.tool.c.compiler.option.sysincpath'
                                 else
                                     'com.arm.tool.c.compiler.v6.base.option.sysincpath'
                                 end
                    option_node = @operations.create_compiler_option(
                        target, superClass, "stringList", compiler, used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = @operations.convert_string(value)
                    option_node << listopt_node
                end

                def clear_include!(target, compiler, *args, used: false, **kargs)
                    option_node = if compiler == 'armcc'
                                      @operations.create_compiler_option(
                                          target, "com.arm.tool.c.compiler.option.incpath", "includePath", compiler, used: used
                                      )
                                  elsif compiler == 'armclang'
                                      @operations.create_compiler_option(
                                          target, "com.arm.tool.c.compiler.v6.base.option.incpath", "includePath", compiler, used: used
                                      )
                                  end
                    collection = option_node.xpath('*')
                    collection.remove() unless(collection.nil?)
                end
            end

            class SourceLanguageTab < TabBase

                private

                def language_mode(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_compiler_option(
                        target, "com.arm.tool.c.compile.option.lang", "enumerated", compiler, "com.arm.tool.c.compile.option.lang.#{value}", used: used
                    )
                end

                def gnu_extensions(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.option.gnu", "boolean", compiler, value, used: used
                    )
                end

                def strict_language_conformance(target, value, compiler, *args, used: false, **kargs)
                    superClass = if compiler == 'armcc'
                                     "com.arm.tool.c.compiler.option.strict"
                                 else
                                     "com.arm.tool.c.compiler.v6.base.option.strict"
                                 end
                    @operations.set_compiler_option(
                        target, superClass, "enumerated", compiler, "#{superClass}.#{value}", used: used
                    )
                end

                def enable_cpp_exceptions(target, value, compiler, *args, used: false, **kargs)
                    superClass = if compiler == 'armcc'
                                     "com.arm.tool.c.compiler.option.exceptions"
                                 else
                                     "com.arm.tool.c.compiler.v6.base.option.exceptions"
                                 end
                    @operations.set_compiler_option(
                        target, superClass, "boolean", compiler, value, used: used
                    )
                end

                #armclang specific
                def language_std(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.v6.base.option.lang", "enumerated", compiler,
                        "com.arm.tool.c.compiler.v6.base.option.lang.#{value}", used: used
                    )
                end

            end

            class OptimizationTab < TabBase

                private

                def optimization(target, value, compiler, *args, used: false, **kargs)
                    if compiler=='armcc'
                        target_part = if target.downcase.include?('debug')
                                          'debug'
                                      else
                                          'release'
                                      end
                        superClass = "com.arm.tool.c.compiler.baremetal.exe.#{target_part}.base.option.opt.base.var.arm_compiler_5-5"
                        level = "com.arm.tool.c.compiler.option.optlevel.#{value}"
                    else
                        superClass = "com.arm.tool.c.compiler.v6.base.option.optlevel"
                        level = "com.arm.tool.c.compiler.v6.base.option.optlevel.#{value}"
                    end

                    @operations.set_compiler_option(
                        target, superClass, "enumerated", compiler, level, used: used
                    )
                end

                def optimization_strategy(target, value, compiler, *args, used: false, **kargs)
                    if compiler == 'armcc'
                        superClass = "com.arm.tool.c.compiler.option.optfor"
                        strategy = "#{superClass}.#{value}"
                    else
                        superClass = "com.arm.tool.c.compiler.v6.base.option.lto"
                        strategy = value
                        enable_tool_setting(target,'true', compiler)
                    end
                    @operations.set_compiler_option(
                        target, superClass, "enumerated", compiler, strategy, used: used
                    )
                end

                def loop_optimization(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.option.loopopt", "enumerated", compiler,
                        "com.arm.tool.c.compiler.option.loopopt.#{value}", used: used
                    )
                end

                def vectorization(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.option.vector", "boolean", compiler,
                        value, used: used
                    )
                end

                def feedback(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.option.feedback", "string", compiler,
                        value, used: used
                    )
                end

                def enable_tool_setting(target, value, compiler, *args, used: true, **kargs)
                    if compiler == 'armclang'
                        superClass = 'com.arm.tool.c.compiler.v6.base.options.opt.enableToolSpecificSettings'
                        option_node = @operations.set_compiler_option(
                            target, superClass, "boolean", compiler, @operations.convert_string(value), used: used
                        )
                    end
                end

            end

            class DebuggingTab < TabBase

                def enable_debug(target, value, compiler, *args, used: false, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.options.debug.enabled", "boolean", compiler, value, used: used
                    )
                end

                def debug_format(target, value, compiler, *args, used: false, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.options.debug.format", "enumerated", compiler,
                        "com.arm.tool.c.compiler.options.debug.format.#{value}", used: used
                    )
                end

                def debug_level(target, value, compiler, *args, used: false, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.v6.base.options.debug.level", "enumerated", compiler,
                        "com.arm.tool.c.compiler.v6.base.options.debug.level.#{value}", used: used
                    )
                end

                private

                def enable_tool_setting(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler === 'armcc'
                                     "com.arm.tool.c.compiler.option.debug.enableToolSpecificSettings"
                                 else
                                     "com.arm.tool.c.compiler.v6.base.options.debug.enableToolSpecificSettings"
                                 end
                    option_node = @operations.set_compiler_option(
                        target, superClass, "boolean", compiler,
                        @operations.convert_string(value), used: used
                    )
                end
            end

            class WarningsAndErrorsTab < TabBase

                def suppress_all_warnings(target, value, compiler, *args, used: false, **kargs)
                    superClass = if compiler == 'armcc'
                                     "com.arm.tool.c.compiler.option.suppresswarn"
                                 else
                                     "com.arm.tool.c.compiler.v6.base.option.suppresswarn"
                                 end
                    @operations.set_compiler_option(
                        target, superClass, "boolean", compiler, value, used: used
                    )
                end

                def warning_as_error(target, value, compiler, *args, used: false, **kargs)
                    superClass = if compiler == 'armcc'
                                     "com.arm.tool.c.compiler.option.warnaserr"
                                 else
                                     "com.arm.tool.c.compiler.v6.base.option.warnaserr"
                                 end
                    @operations.set_compiler_option(
                        target, superClass, "boolean", compiler,
                        value, used: used
                    )
                end

                def all_warnings(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.v6.base.option.warnall", "boolean", compiler,
                        value, used: used
                    )
                end

                def error_severity(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.option.errsev", "string", compiler,
                        value, used: used
                    )
                end

                def warning_severity(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.option.warnsev", "string", compiler,
                        value, used: used
                    )
                end

                def enable_remarks(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.option.enablerem", "boolean", compiler,
                        value, used: used
                    )
                end

                def remark_severity(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.option.remarksev", "string", compiler,
                        value, used: used
                    )
                end

                def suppress(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.option.suppress", "string", compiler, value, used: used
                    )
                end

            end

            class MiscellaneousTab < TabBase

                private

                def complier_other_flags(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     "com.arm.tool.c.compiler.option.flags"
                                 else
                                     "com.arm.tool.c.compiler.v6.base.option.flags"
                                 end
                    option_node = @operations.create_compiler_option(
                        target, superClass, "stringList", compiler, used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = value
                    option_node << listopt_node
                end

                def short_enum_wchar(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_compiler_option(
                        target, "com.arm.tool.c.compiler.v6.base.option.shortEnumsWchar", "boolean", compiler, value, used: used
                    )
                end
            end

        end

        class ArmCppCompilerTab < TabBase

          private

          class TargetTab < TabBase

            def enable_tool_setting(target, value, compiler, *args, used: true, **kargs)
              superClass = if compiler == 'armcc'
                             'com.arm.tool.c.compiler.option.target.enableToolSpecificSettings'
                           else
                             'com.arm.tool.c.compiler.v6.base.options.target.enableToolSpecificSettings'
                           end
              option_node = @operations.set_cpp_compiler_option(
                  target, superClass, "boolean", compiler,
                  @operations.convert_string(value), used: used
              )
            end

            def set_inst(target, value, compiler, *args, used: true, **kargs)
              if compiler ==  'armcc'
                superClass = 'com.arm.tool.c.compiler.option.inst'
                inst = "com.arm.tool.c.compiler.option.inst.#{value}"
              else
                superClass = 'com.arm.tool.c.compiler.v6.base.option.inst'
                inst = "com.arm.tool.c.compiler.v6.base.option.inst.#{value}"
              end
              enable_tool_setting(target,'true', compiler)
              option_node = @operations.set_cpp_compiler_option(
                  target, superClass, "enumerated", compiler,
                  @operations.convert_string(inst), used: used
              )
            end

            def endian(target, value, compiler, *args, used: true, **kargs)
              convert = {
                  'bigend' => 'com.arm.tool.c.compiler.option.endian.big',
                  'littleend' => 'com.arm.tool.c.compiler.option.endian.little',
                  'auto' => 'com.arm.tool.c.compiler.option.endian.auto'
              }
              if compiler == 'armcc'
                superClass = "com.arm.tool.c.compiler.option.endian"
                order = convert[value]
              else
                superClass = "com.arm.tool.c.compiler.v6.base.option.endian"
                order = "com.arm.tool.c.compiler.v6.base.option.endian.#{value}"
              end
              enable_tool_setting(target,'true', compiler)
              option_node = @operations.set_cpp_compiler_option(
                  target, superClass, "enumerated", compiler,
                  @operations.convert_string(order), used: used
              )
            end

            def char_size(target, value, compiler, *args, used: true, **kargs)
              enable_tool_setting(target,'true', compiler)
              option_node = @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.option.charsize", "enumerated",
                  "com.arm.tool.c.compiler.option.enum.#{value}", used: used
              )
            end

            def interwork(target, value, compiler, *args, used: true, **kargs)
              enable_tool_setting(target,'true', compiler)
              option_node = @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.option.inter", "boolean", compiler,
                  @operations.convert_string(value), used: used
              )
            end

            def aligned_access(target, value, compiler, *args, used: true, **kargs)
              enable_tool_setting(target,'true', compiler)
              option_node = @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.option.unalign", "boolean",
                  @operations.convert_string(value), used: used
              )
            end

            def enum_as_int(target, value, compiler, *args, used: true, **kargs)
              enable_tool_setting(target,'true', compiler)
              option_node = @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.option.enum", "boolean",
                  @operations.convert_string(value), used: used
              )
            end

            def cpu_fpu_type(target, value, compiler, *args, used: true, **kargs)
              superClass = if compiler == 'armcc'
                             'com.arm.tool.c.compiler.option.targetcpu'
                           else
                             'com.arm.tool.c.compiler.v6.base.option.cpu'
                           end
              enable_tool_setting(target,'true', compiler)
              option_node = @operations.set_cpp_compiler_option(
                  target, superClass, "string", compiler,
                  @operations.convert_string(value), used: used
              )
            end

            def set_fppcs(target, value, compiler, *args, used: true, **kargs)
              convert = {
                  'hard' => 'com.arm.tool.c.compiler.option.fppcs.hard',
                  'soft' => 'com.arm.tool.c.compiler.option.fppcs',
                  'auto' => 'com.arm.tool.c.compiler.option.fppcs.auto'
              }
              enable_tool_setting(target,'true', compiler)
              if compiler == 'armcc'
                superClass = 'com.arm.tool.c.compiler.option.fppcs'
                fpu = convert[value]
              else
                superClass = 'com.arm.tool.c.compiler.v6.base.option.floatabi'
                fpu = "com.arm.tool.c.compiler.v6.base.option.floatabi.#{value}"
              end
              option_node = @operations.set_cpp_compiler_option(
                  target, superClass, "enumerated", compiler,
                  @operations.convert_string(fpu), used: used
              )
            end

            def set_fp_mode(target, value, compiler, *args, used: true, **kargs)
              enable_tool_setting(target,'true', compiler)
              option_node = @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.option.fpmode", "enumerated", compiler,
                  @operations.convert_string("com.arm.tool.c.compiler.option.fpmode.#{value}"), used: used
              )
            end

            #armclang specific
            def target(target, value, compiler, *args, used: true, **kargs)
              enable_tool_setting(target,'true', compiler)
              option_node = @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.v6.base.option.target", "string", compiler, value, used: used
              )
            end

            def arch(target, value, compiler, *args, used: true, **kargs)
              enable_tool_setting(target,'true', compiler)
              option_node = @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.v6.base.option.arch", "string", compiler, value, used: used
              )
            end

            def cpu_type(target, value, compiler, *args, used: true, **kargs)
              enable_tool_setting(target,'true', compiler)
              option_node = @operations.set_cpp_compiler_option(
                  target, 'com.arm.tool.c.compiler.v6.base.option.cpu', "string", compiler,
                  @operations.convert_string(value), used: used
              )
            end

            def fpu_type(target, value, compiler, *args, used: true, **kargs)
              enable_tool_setting(target,'true', compiler)
              option_node = @operations.set_cpp_compiler_option(
                  target, 'com.arm.tool.c.compiler.v6.base.option.fpu', "string", compiler,
                  @operations.convert_string(value), used: used
              )
            end

            def vectorization(target, value, compiler, *args, used: true, **kargs)
              enable_tool_setting(target,'true', compiler)
              option_node = @operations.set_cpp_compiler_option(
                  target, 'com.arm.tool.c.compiler.v6.base.option.vector', "boolean", compiler,
                  @operations.convert_string(value), used: used
              )
            end

          end

          class PreprocessorTab < TabBase

            private

            def enable_tool_setting(target, value, compiler, *args, used: true, **kargs)
              superClass = if compiler == 'armcc'
                             'com.arm.tool.c.compiler.option.preproc.enableToolSpecificSettings'
                           else
                             'com.arm.tool.c.compiler.v6.base.options.preproc.enableToolSpecificSettings'
                           end
              option_node = @operations.set_cpp_compiler_option(
                  target, superClass, "boolean", compiler, @operations.convert_string(value), used: used
              )
            end

            def use_microlib(target, value, compiler, *args, used: true, **kargs)
              superClass = if compiler == 'armcc'
                             'com.arm.tool.c.compiler.option.useMicroLib'
                           else
                             'com.arm.tool.c.compiler.v6.base.useMicroLib'
                           end
              enable_tool_setting(target,'true', compiler)
              option_node = @operations.set_cpp_compiler_option(
                  target, superClass, "boolean", compiler, @operations.convert_string(value), used: used
              )
            end

            def preprocess_only(target, value, compiler, *args, used: true, **kargs)
              superClass = if compiler == 'armcc'
                             'com.arm.tool.c.compiler.option.preproconly'
                           else
                             'com.arm.tool.c.compiler.v6.base.option.preproconly'
                           end
              option_node = @operations.set_cpp_compiler_option(
                  target, superClass, "boolean", compiler, @operations.convert_string(value), used: used
              )
            end

            def add_implicit_define(target, value, compiler, *args, used: true, **kargs)
              option_node = @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.option.implicit.defmac", "definedSymbols", used: used
              )
              listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
              listopt_node[ 'builtIn' ] = 'false'
              listopt_node[ 'value' ] = @operations.convert_string(value)
              option_node << listopt_node
            end

            def add_define(target, value, compiler, *args, used: true, **kargs)
              superClass = if compiler == 'armcc'
                             'com.arm.tool.c.compiler.option.defmac'
                           else
                             'com.arm.tool.c.compiler.v6.base.option.defmac'
                           end
              option_node = @operations.create_compiler_option(
                  target, superClass, "definedSymbols", compiler, used: used
              )
              listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
              listopt_node[ 'builtIn' ] = 'false'
              listopt_node[ 'value' ] = @operations.convert_string(value)
              option_node << listopt_node
            end

            def add_undefine(target, value, compiler, *args, used: true, **kargs)
              superClass = if compiler == 'armcc'
                             'com.arm.tool.c.compiler.option.undefmac'
                           else
                             'com.arm.tool.c.compiler.v6.base.option.undefmac'
                           end
              option_node = @operations.create_compiler_option(
                  target, superClass, "undefDefinedSymbols", compiler, used: used
              )
              listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
              listopt_node[ 'builtIn' ] = 'false'
              listopt_node[ 'value' ] = @operations.convert_string(value)
              option_node << listopt_node
            end

            def clear_defines!(target, compiler, *args, used: false, **kargs)
              option_node = if compiler == 'armcc'
                              @operations.create_compiler_option(
                                  target, "com.arm.tool.c.compiler.option.defmac", "definedSymbols", compiler, used: used
                              )
                            elsif compiler == 'armclang'
                              @operations.create_compiler_option(
                                  target, "com.arm.tool.c.compiler.v6.base.option.defmac", "definedSymbols", compiler, used: used
                              )
                            end
              collection = option_node.xpath('*')
              collection.remove() unless(collection.nil?)
            end
          end

          class IncludesTab < TabBase

            private

            def add_include(target, value, compiler, *args, used: true, **kargs)
              superClass = if compiler == 'armcc'
                             'com.arm.tool.c.compiler.option.incpath'
                           else
                             'com.arm.tool.c.compiler.v6.base.option.incpath'
                           end
              option_node = @operations.create_compiler_option(
                  target, superClass, "includePath", compiler, used: used
              )
              listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
              listopt_node[ 'builtIn' ] = 'false'
              listopt_node[ 'value' ] = @operations.convert_string(value)
              option_node << listopt_node
            end

            def add_pre_include(target, value, compiler, *args, used: true, **kargs)
              superClass = if compiler == 'armcc'
                             'com.arm.tool.c.compiler.option.preinc'
                           else
                             'com.arm.tool.c.compiler.v6.base.option.preinc'
                           end
              option_node = @operations.create_compiler_option(
                  target, superClass, "includeFiles", compiler, used: used
              )
              listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
              listopt_node[ 'builtIn' ] = 'false'
              listopt_node[ 'value' ] = @operations.convert_string(value)
              option_node << listopt_node
            end

            def add_sys_include(target, value, compiler, *args, used: true, **kargs)
              superClass = if compiler == 'armcc'
                             'com.arm.tool.c.compiler.option.sysincpath'
                           else
                             'com.arm.tool.c.compiler.v6.base.option.sysincpath'
                           end
              option_node = @operations.create_compiler_option(
                  target, superClass, "stringList", compiler, used: used
              )
              listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
              listopt_node[ 'builtIn' ] = 'false'
              listopt_node[ 'value' ] = @operations.convert_string(value)
              option_node << listopt_node
            end

            def clear_include!(target, compiler, *args, used: false, **kargs)
              option_node = if compiler == 'armcc'
                              @operations.create_compiler_option(
                                  target, "com.arm.tool.c.compiler.option.incpath", "includePath", compiler, used: used
                              )
                            elsif compiler == 'armclang'
                              @operations.create_compiler_option(
                                  target, "com.arm.tool.c.compiler.v6.base.option.incpath", "includePath", compiler, used: used
                              )
                            end
              collection = option_node.xpath('*')
              collection.remove() unless(collection.nil?)
            end
          end

          class SourceLanguageTab < TabBase

            private

            def language_mode(target, value, compiler, *args, used: false, **kargs)
              @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compile.option.lang", "enumerated", compiler, "com.arm.tool.c.compile.option.lang.#{value}", used: used
              )
            end

            def gnu_extensions(target, value, compiler, *args, used: false, **kargs)
              @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.option.gnu", "boolean", compiler, value, used: used
              )
            end

            def strict_language_conformance(target, value, compiler, *args, used: false, **kargs)
              superClass = if compiler == 'armcc'
                             "com.arm.tool.c.compiler.option.strict"
                           else
                             "com.arm.tool.c.compiler.v6.base.option.strict"
                           end
              @operations.set_cpp_compiler_option(
                  target, superClass, "enumerated", compiler, "#{superClass}.#{value}", used: used
              )
            end

            def enable_cpp_exceptions(target, value, compiler, *args, used: false, **kargs)
              superClass = if compiler == 'armcc'
                             "com.arm.tool.c.compiler.option.exceptions"
                           else
                             "com.arm.tool.c.compiler.v6.base.option.exceptions"
                           end
              @operations.set_cpp_compiler_option(
                  target, superClass, "boolean", compiler, value, used: used
              )
            end

            #armclang specific
            def language_std(target, value, compiler, *args, used: false, **kargs)
              @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.v6.base.option.lang", "enumerated", compiler,
                  "com.arm.tool.c.compiler.v6.base.option.lang.#{value}", used: used
              )
            end

          end

          class OptimizationTab < TabBase

            private

            def optimization(target, value, compiler, *args, used: false, **kargs)
              if compiler=='armcc'
                target_part = if target.downcase.include?('debug')
                                'debug'
                              else
                                'release'
                              end
                superClass = "com.arm.tool.c.compiler.baremetal.exe.#{target_part}.base.option.opt.base.var.arm_compiler_5-5"
                level = "com.arm.tool.c.compiler.option.optlevel.#{value}"
              else
                superClass = "com.arm.tool.c.compiler.v6.base.option.optlevel"
                level = "com.arm.tool.c.compiler.v6.base.option.optlevel.#{value}"
              end

              @operations.set_cpp_compiler_option(
                  target, superClass, "enumerated", compiler, level, used: used
              )
            end

            def optimization_strategy(target, value, compiler, *args, used: false, **kargs)
              if compiler == 'armcc'
                superClass = "com.arm.tool.c.compiler.option.optfor"
                strategy = "#{superClass}.#{value}"
              else
                superClass = "com.arm.tool.c.compiler.v6.base.option.lto"
                strategy = value
                enable_tool_setting(target,'true', compiler)
              end
              @operations.set_cpp_compiler_option(
                  target, superClass, "enumerated", compiler, strategy, used: used
              )
            end

            def loop_optimization(target, value, compiler, *args, used: false, **kargs)
              @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.option.loopopt", "enumerated", compiler,
                  "com.arm.tool.c.compiler.option.loopopt.#{value}", used: used
              )
            end

            def vectorization(target, value, compiler, *args, used: false, **kargs)
              @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.option.vector", "boolean", compiler,
                  value, used: used
              )
            end

            def feedback(target, value, compiler, *args, used: false, **kargs)
              @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.option.feedback", "string", compiler,
                  value, used: used
              )
            end

            def enable_tool_setting(target, value, compiler, *args, used: true, **kargs)
              if compiler == 'armclang'
                superClass = 'com.arm.tool.c.compiler.v6.base.options.opt.enableToolSpecificSettings'
                option_node = @operations.set_cpp_compiler_option(
                    target, superClass, "boolean", compiler, @operations.convert_string(value), used: used
                )
              end
            end

          end

          class DebuggingTab < TabBase

            def enable_debug(target, value, compiler, *args, used: false, **kargs)
              enable_tool_setting(target,'true', compiler)
              @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.options.debug.enabled", "boolean", compiler, value, used: used
              )
            end

            def debug_format(target, value, compiler, *args, used: false, **kargs)
              enable_tool_setting(target,'true', compiler)
              @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.options.debug.format", "enumerated", compiler,
                  "com.arm.tool.c.compiler.options.debug.format.#{value}", used: used
              )
            end

            def debug_level(target, value, compiler, *args, used: false, **kargs)
              enable_tool_setting(target,'true', compiler)
              @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.v6.base.options.debug.level", "enumerated", compiler,
                  "com.arm.tool.c.compiler.v6.base.options.debug.level.#{value}", used: used
              )
            end

            private

            def enable_tool_setting(target, value, compiler, *args, used: true, **kargs)
              superClass = if compiler === 'armcc'
                             "com.arm.tool.c.compiler.option.debug.enableToolSpecificSettings"
                           else
                             "com.arm.tool.c.compiler.v6.base.options.debug.enableToolSpecificSettings"
                           end
              option_node = @operations.set_cpp_compiler_option(
                  target, superClass, "boolean", compiler,
                  @operations.convert_string(value), used: used
              )
            end
          end

          class WarningsAndErrorsTab < TabBase

            def suppress_all_warnings(target, value, compiler, *args, used: false, **kargs)
              superClass = if compiler == 'armcc'
                             "com.arm.tool.c.compiler.option.suppresswarn"
                           else
                             "com.arm.tool.c.compiler.v6.base.option.suppresswarn"
                           end
              @operations.set_cpp_compiler_option(
                  target, superClass, "boolean", compiler, value, used: used
              )
            end

            def warning_as_error(target, value, compiler, *args, used: false, **kargs)
              superClass = if compiler == 'armcc'
                             "com.arm.tool.c.compiler.option.warnaserr"
                           else
                             "com.arm.tool.c.compiler.v6.base.option.warnaserr"
                           end
              @operations.set_cpp_compiler_option(
                  target, superClass, "boolean", compiler,
                  value, used: used
              )
            end

            def all_warnings(target, value, compiler, *args, used: false, **kargs)
              @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.v6.base.option.warnall", "boolean", compiler,
                  value, used: used
              )
            end

            def error_severity(target, value, compiler, *args, used: false, **kargs)
              @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.option.errsev", "string", compiler,
                  value, used: used
              )
            end

            def warning_severity(target, value, compiler, *args, used: false, **kargs)
              @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.option.warnsev", "string", compiler,
                  value, used: used
              )
            end

            def enable_remarks(target, value, compiler, *args, used: false, **kargs)
              @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.option.enablerem", "boolean", compiler,
                  value, used: used
              )
            end

            def remark_severity(target, value, compiler, *args, used: false, **kargs)
              @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.option.remarksev", "string", compiler,
                  value, used: used
              )
            end

            def suppress(target, value, compiler, *args, used: false, **kargs)
              @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.option.suppress", "string", compiler, value, used: used
              )
            end

          end

          class MiscellaneousTab < TabBase

            private

            def complier_other_flags(target, value, compiler, *args, used: true, **kargs)
              superClass = if compiler == 'armcc'
                             "com.arm.tool.c.compiler.option.flags"
                           else
                             "com.arm.tool.c.compiler.v6.base.option.flags"
                           end
              option_node = @operations.create_compiler_option(
                  target, superClass, "stringList", compiler, used: used
              )
              listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
              listopt_node[ 'builtIn' ] = 'false'
              listopt_node[ 'value' ] = value
              option_node << listopt_node
            end

            def short_enum_wchar(target, value, compiler, *args, used: false, **kargs)
              @operations.set_cpp_compiler_option(
                  target, "com.arm.tool.c.compiler.v6.base.option.shortEnumsWchar", "boolean", compiler, value, used: used
              )
            end
          end

        end

        class ArmCLinkerTab < TabBase

            private



            def command_pattern(target, value, compiler, *args, used: true, **kargs)
                linker_node = @operations.get_linker_node(target, used: used)
                linker_node[ 'commandLinePattern' ] = @operations.convert_string(value)
            end

            class TargetTab < TabBase

                private

                def cpu_fpu_type(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     "com.arm.tool.c.linker.option.cpu"
                                 else
                                     "com.arm.tool.c.linker.v6.option.cpu"
                                 end
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_linker_option(
                        target, superClass, "string", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

                def enable_tool_setting(target, value, compiler, *args, used: true, **kargs)
                    superClass = if compiler == 'armcc'
                                     "com.arm.tool.c.linker.option.target.enableToolSpecificSettings"
                                 else
                                     "com.arm.tool.linker.v6.base.options.target.enableToolSpecificSettings"
                                 end
                    option_node = @operations.set_linker_option(
                        target, superClass, "boolean", compiler, @operations.convert_string(value), used: used
                    )
                end
            end

            class ImageLayoutTab < TargetTab

                private
                def entry_point(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.entry", "string", compiler, value, used: used
                    )
                end

                def ro_base(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.robase", "string", compiler, value, used: used
                    )
                end

                def rw_base(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.rwbase", "string", compiler, value, used: used
                    )
                end

                def zi_base(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.zibase", "string", compiler, value, used: used
                    )
                end

                def add_script_file(target, value, compiler, *args, used: true, **kargs)
                    if compiler == 'armcc'
                        option_node = @operations.create_linker_option(
                            target, "com.arm.tool.c.linker.option.scatter", "stringList", compiler, used: used
                        )
                        listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                        listopt_node[ 'builtIn' ] = 'false'
                        listopt_node[ 'value' ] = @operations.convert_string(value)
                        option_node << listopt_node
                    else
                        option_node = @operations.create_linker_option(
                            target, "com.arm.tool.c.linker.option.scatter", "string", compiler, used: used
                        )
                        option_node[ 'value' ] = value.to_s
                    end
                end

                def clear_script_files!(target, compiler, *args, used: true, **kargs)
                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.option.scatter", "stringList", compiler, used: used
                    )
                    collection = option_node.xpath('*')
                    collection.remove() unless(collection.nil?)
                end

                def add_predefine(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.option.predefine", "stringList", compiler, used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = @operations.convert_string(value)
                    option_node << listopt_node
                end

            end


            class GeneralTab < TabBase

                private



                def cpu_type(target, value, compiler, *args, used: true, **kargs)
                    conv = {
                        'default'               => 'default',
                        'Cortex-M4.fp.sp'    => 'Cortex-M4.fp.sp',
                    }
                    # option_node = @operations.create_linker_option(
                    #     target, "com.arm.tool.c.linker.option.cpu", "string", @operations.convert_enum(value, conv), used: used
                    # )
                end

                def linker_eleminate_remove(target, value, compiler, *args, used: true, **kargs)

                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.option.eleminate", "boolean", used: used
                    )
                    option_node[ 'value' ] = value.to_s
                end

                def linker_verbose(target, value, compiler, *args, used: true, **kargs)

                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.option.verbose", "boolean", used: used
                    )
                    option_node[ 'value' ] = value.to_s
                end

                def linker_list_total(target, value, compiler, *args, used: true, **kargs)

                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.option.totals", "boolean", used: used
                    )
                    option_node[ 'value' ] = value.to_s
                end

                def linker_list_stack(target, value, compiler, *args, used: true, **kargs)

                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.option.stack", "boolean", used: used
                    )
                    option_node[ 'value' ] = value.to_s
                end



                def linker_list_compression(target, value, compiler, *args, used: true, **kargs)

                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.option.compress", "boolean", used: used
                    )
                    option_node[ 'value' ] = value.to_s
                end

                def linker_list_unused(target, value, compiler, *args, used: true, **kargs)

                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.option.elim", "boolean", used: used
                    )
                    option_node[ 'value' ] = value.to_s
                end



                def linker_callgraph(target, value, compiler, *args, used: true, **kargs)

                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.option.callgraph", "boolean", used: used
                    )
                    option_node[ 'value' ] = value.to_s
                end

                def linker_veneers(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.option.flags", "stringList", used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = '--info=veneers'
                    option_node << listopt_node
                end

                def linker_xref(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.option.flags", "stringList", used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = value
                    option_node << listopt_node
                end

                def linker_strict(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.option.flags", "stringList", used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = value
                    option_node << listopt_node
                end

                def linker_symbols(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.option.flags", "stringList", used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = value
                    option_node << listopt_node
                end

            end

            class LibrariesTab < TabBase
                private

                def enable_tool_setting(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.libs.enableToolSpecificSettings", "boolean", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

                def use_microlib(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target,'true', compiler)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.useMicroLib", "boolean", compiler,
                        @operations.convert_string(value), used: used
                    )
                end

                def add_user_library(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.libs", "libs", compiler, used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = @operations.convert_string(value)
                    option_node << listopt_node
                end

                def bypass_syslib(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.preventsys", "boolean", compiler,
                        @operations.convert_string(value), used: used
                    )
                end
            end

            class OptimizationsTab < TabBase
                private
                def linker_eleminate_remove(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.eleminate", "boolean", compiler, value.to_s, used: used
                    )
                end

                def allow_inline(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.inline", "boolean", compiler, value.to_s, used: used
                    )
                end

                def specific_sections(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.option.keep", "stringList", compiler, used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = value
                    option_node << listopt_node
                end

                def time_optimization(target, value, compiler, *args, used: true, **kargs)
                    enable_tool_setting(target, 'true', compiler)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.linker.v6.option.optimization.lto", "enumerated", compiler, value, used: used
                    )
                end

                def enable_tool_setting(target, value, compiler, *args, used: true, **kargs)
                    superClass = "com.arm.tool.linker.v6.option.opt.enableToolSpecificSettings"
                    option_node = @operations.set_linker_option(
                        target, superClass, "boolean", compiler,
                        @operations.convert_string(value), used: used
                    )
                end
            end

            class AdditionalTab < TabBase
                private

                def linker_callgraph(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.option.callgraph", "boolean", compiler, used: used
                    )
                    option_node[ 'value' ] = value.to_s
                end

                def callgraph_filename(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.graphfile", "string", compiler, value, used: used
                    )
                end

                def callgraph_format(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.graphformat", "enumerated", compiler,
                        "com.arm.tool.c.linker.option.graphformat.#{value}", used: used
                    )
                end

                def linker_image_map(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.imagemap", "boolean", compiler,
                        value.to_s, used: used
                    )
                end

                def linker_verbose(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.verbose", "boolean", compiler,
                        value.to_s, used: used
                    )
                end

                def linker_list_sizes(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.sizes", "boolean", compiler,
                        value.to_s, used: used
                    )
                end

                def linker_list_total(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.totals", "boolean", compiler,
                        value.to_s, used: used
                    )
                end

                def linker_list_unused(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.elim", "boolean", compiler,
                        value.to_s, used: used
                    )
                end

                def linker_list_compression(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.compress", "boolean", compiler,
                        value.to_s, used: used
                    )
                end

                def linker_list_stack(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.stack", "boolean", compiler,
                        value.to_s, used: used
                    )
                end

                def linker_list_inline(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.inlineinfo", "boolean", compiler,
                        value.to_s, used: used
                    )
                end

                def diagnostics_file(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.redirectoutput", "string", compiler,
                        value, used: used
                    )
                end
            end

            class WarningsAndErrorsTab < TabBase

                private

                def error_severity(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.err", "string", compiler,
                        value, used: used
                    )
                end

                def warning_severity(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.warn", "string", compiler,
                        value, used: used
                    )
                end

                def enable_remarks(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.enablerem", "boolean", compiler,
                        value.to_s, used: used
                    )
                end

                def remark_severity(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_linker_option(
                        target, "com.arm.tool.c.linker.option.rem", "string", compiler,
                        value, used: used
                    )
                end

                def suppress(target, value, compiler, *args, used: false, **kargs)
                    @operations.set_linker_option(
                        target, "com.arm.tool.c.link.option.suppress", "string", compiler,
                        value, used: used
                    )
                end
            end

            class MiscellaneousTab < TabBase

                private

                def add_other_flags(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.option.flags", "stringList", compiler, used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = @operations.convert_string(value)
                    option_node << listopt_node
                end

                def add_user_object(target, value, compiler, *args, used: true, **kargs)
                    option_node = @operations.create_linker_option(
                        target, "com.arm.tool.c.linker.userobjs", "userObjs", compiler, used: used
                    )
                    listopt_node = Nokogiri::XML::Node.new("listOptionValue", @operations.xml)
                    listopt_node[ 'builtIn' ] = 'false'
                    listopt_node[ 'value' ] = @operations.convert_string(value)
                    option_node << listopt_node
                end

            end

        end


        class ArmCppLinkerTab < TabBase

            private

            class GeneralTab < TabBase

                private
                def clear_script_files!(target, value, compiler, *args, used: true, **kargs)

                end

                def add_script_file(target, value, compiler, *args, used: true, **kargs)

                end
            end

            class LibrariesTab < TabBase

                private
            end

            class MiscellaneousTab < TabBase

                private
            end

        end

        class ArmArchiverTab < TabBase

            private

            class GeneralTab < TabBase

                private

                # def add_flag(target, value, compiler, *args, used: true, **kargs)
                #     option_node = @operations.create_archiver_option(
                #         target, "gnu.both.lib.option.flags", "string", used: used
                #     )
                #     value = @operations.convert_string(value)
                #     option_node[ 'value' ] = option_node[ 'value' ] ? "#{option_node[ 'value' ]} #{value}" : "#{value}"
                # end

                # def clear_flags!(target, *args, used: false, **kargs)
                #     option_node = @operations.set_archiver_option(
                #         target, "gnu.both.lib.option.flags", "string", '', used: used
                #     )
                # end
            end
        end
    end
end
end

