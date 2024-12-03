# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
module Mixin
module ProjectUtils


    # we need additional prebuid script to create an output directory
    # of binary file because otherwise realview compiler might fail
    def makedir_sh(path)
        content = "#!/bin/sh \n"
        content = "mkdir -p ${1} \n"
        @logger.debug("generate file: #{path}")
        File.force_write(path, content)
        File.chmod(0755, path)
        @generated_hook.notify(path)
    end


    def makedir_bat(path, windows: true)
        content = "set TARGETDIR=%1" + "\n"
        content += "set TARGETDIR=%TARGETDIR:/=\\%" + "\n"
        content += "set TARGETDIR=%TARGETDIR:\"=%" + "\n"
        content += "IF NOT EXIST \"%TARGETDIR%\" mkdir \"%TARGETDIR%\"" + "\n"
        @logger.debug("generate file: #{path}")
        File.force_write(path, content)
        @generated_hook.notify(path)
    end

    def get_file_type(src, toolchain)
        type_map = {
            '.c' => 'src',
            '.cpp' => 'src',
            '.ldt' => 'src',
            '.h' => 'c_include',
            '.s' => 'src',
            '.S' => 'src',
            '.def' => 'src',
            '.asm' => 'src',
            '.a' => 'lib',
            '.lib' => 'lib',
            '.erpc' => 'script',
            '.txt'  => 'doc',
            '.pdf'  => 'doc',
            '.board'  => 'configuration',
            '.ld' => 'linker'
        }
        if toolchain == 'mcuxpresso' and '.a' == File.extname(src)
            if src.gsub('\\','/').split('/')[-1].start_with?('lib')
                return 'lib'
            else
                return 'object'
            end
        else
            return type_map[File.extname(src)]
        end
    end

end
end

