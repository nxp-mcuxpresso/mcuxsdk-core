# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
require_relative '../../internal/mdk/_project'
require_relative 'files/uvprojx_file'
require_relative '../../internal/_lib_project_interface'
require_relative '../common/project'

module Mdk
module Lib

    class UProject < Internal::Mdk::UProject

        # consuming interface
        include Internal::LibProjectInterface
        include Mdk::CommonProject
        attr_reader :uvprojx_file
        attr_reader :uvmpw_file
        attr_reader :uvprojx_template
        attr_reader :compiler

        def initialize(param)
            super(param)
            @compiler = param[:compiler]
            # .uvprojx
            @uvprojx_template = @templates.first_by_regex(/\.uvprojx$/)
            Core.assert(!@uvprojx_template.nil?) do
                "no '.uvprojx' file in templates"
            end
            @uvprojx_file = UvprojxFile.new(@uvprojx_template, logger: @logger)
            # setup new target name - otherwise project cannot be used in workspace
            @uvprojx_file.targets.each do | target |
                target_name = target.split(' ').map(&:capitalize).join(' ')
                @uvprojx_file.project_name(target, "#{@name} #{target_name}")
            end
            # .uvmpw
            @uvmpw_file = @templates.first_by_regex(/\.uvmpw$/) ? UvmpwFile.new : nil
        end

        def clear!()
            clear_sources!()
            clear_flashDriver!
            targets.each do | target |
                clear_assembler_include!(target)
                clear_compiler_include!(target)
                clear_compiler_macros!(target)
                clear_assembler_macros!(target)
            end
        end

        # save project
        def save(output_dir, shared_projects_info, using_shared_workspace, shared_workspace, *_args)
            Core.assert(output_dir.is_a?(String)) do
                "output dir is not a string '#{output_dir}'"
            end
            @logger.debug("generate project: #{@name}")
            generated_files = []
            # save .uvprojx file
            path = File.join(output_dir,"#{@name}.uvprojx")
            @uvprojx_file.save(path)
            generated_files.push_uniq path
            File.delete(@uvprojx_template) if File.exist? @uvprojx_template
            @generated_hook.notify(path)
            if @uvmpw_file
              @uvmpw_file.add_project(@name + '.uvprojx', true)
              @uvmpw_file.save(File.join(output_dir, "#{@name}.uvmpw"))
              generated_files.push_uniq File.join(output_dir, "#{@name}.uvmpw")

              # save the additional shared .uvmpw
              if !using_shared_workspace && shared_workspace
                  # add other projects to workspace
                  shared_projects_info&.each do |project_name, project_path|
                      @uvmpw_file.add_project(File.join(File.join(project_path, "#{project_name}.uvprojx")).to_s)
                  end
                  @uvmpw_file.save(File.join(output_dir, "#{shared_workspace}.uvmpw"))
                  generated_files.push_uniq File.join(output_dir, "#{shared_workspace}.uvmpw")
              end
            end
            generated_files
        end

    end
end
end


