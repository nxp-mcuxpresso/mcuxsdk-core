# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************

module Internal
module LibProjectInterface

    def is_app?() return false end
    def is_lib?() return true end

    # Save project
    def save(output_dir)
        raise NotImplementedError.new("unimplemented abstract method '#{__method__}'")
    end

    # Clear document - remove sources and include paths
    def clear!()
        raise NotImplementedError.new("unimplemented abstract method '#{__method__}'")
    end

    # Get list of all available targets
    def targets()
        raise NotImplementedError.new("unimplemented abstract method '#{__method__}'")
    end
    
    # Add 'path' source into 'vdir' hierarchy
    def add_source(path, vdir, *args, **kwargs)
        raise NotImplementedError.new("unimplemented abstract method '#{__method__}'")
    end

    # clear all project sources
    def clear_sources!()
        raise NotImplementedError.new("unimplemented abstract method '#{__method__}'")
    end

    # Add assembler user include path 'path' to target 'target'
    def add_assembler_include(target, path, *args, **kwargs)
        raise NotImplementedError.new("unimplemented abstract method '#{__method__}'")
    end

    # Clear assembler user include paths of target
    def clear_assembler_include!(target)
        raise NotImplementedError.new("unimplemented abstract method '#{__method__}'")
    end

    # Add compiler user include path 'path' to target 'target'
    def add_compiler_include(target, path, *args, **kwargs)
        raise NotImplementedError.new("unimplemented abstract method '#{__method__}'")
    end

    # Clear compiler user include paths of target
    def clear_compiler_include!(target)
        raise NotImplementedError.new("unimplemented abstract method '#{__method__}'")
    end

    # Add assembler 'name' macro of 'value' to target
    def add_assembler_macro(target, name, value, *args, **kwargs)
        raise NotImplementedError.new("unimplemented abstract method '#{__method__}'")
    end

    # Clear all assembler macros of target
    def clear_assembler_macros!(target)
        raise NotImplementedError.new("unimplemented abstract method '#{__method__}'")
    end

    # Add compiler 'name' macro of 'value' to target
    def add_compiler_macro(target, name, value, *args, **kwargs)
        raise NotImplementedError.new("unimplemented abstract method '#{__method__}'")
    end

    # Clear all compiler macros of target
    def clear_compiler_macros!(target)
        raise NotImplementedError.new("unimplemented abstract method '#{__method__}'")
    end
end
end

