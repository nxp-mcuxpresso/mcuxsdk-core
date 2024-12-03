# ********************************************************************
# Copyright 2022 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
# ********************************************************************
module Mixin
module CollectLibFlags

    def analyze_enabled?
        return not(not(@analyze_enabled))
    end

    def enable_analyze(value)
        # ensure for boolean value
        @analyze_enabled = value ? true : false
    end

   def collect_chipdefines_flags(target, flag)
        return unless(analyze_enabled?)
        @chipdefines_flags = {} unless(@chipdefines_flags)
        @chipdefines_flags[ target ] = [] unless (@chipdefines_flags[ target ])
        @chipdefines_flags[ target ].push(flag)
    end

    def collect_assembler_flags(target, flag)
        return unless(analyze_enabled?)
        @assembler_flags = {} unless(@assembler_flags)
        @assembler_flags[ target ] = [] unless (@assembler_flags[ target ])
        @assembler_flags[ target ].push(flag)
    end

    def collect_compiler_flags(target, flag)
        return unless(analyze_enabled?)
        @compiler_flags = {} unless(@compiler_flags)
        @compiler_flags[ target ] = [] unless (@compiler_flags[ target ])
        @compiler_flags[ target ].push(flag)
    end

    def collect_cpp_compiler_flags(target, flag)
      return unless(analyze_enabled?)
      @cpp_compiler_flags = {} unless(@cpp_compiler_flags)
      @cpp_compiler_flags[ target ] = [] unless (@cpp_compiler_flags[ target ])
      @cpp_compiler_flags[ target ].push(flag)
    end

    def collect_archiver_flags(target, flag)
        return unless(analyze_enabled?)
        @archiver_flags = {} unless(@archiver_flags)
        @archiver_flags[ target ] = [] unless (@archiver_flags[ target ])
        @archiver_flags[ target ].push(flag)
    end

    def chipdefines_flagsline(target)
        return '' unless(analyze_enabled?)
        return '' unless (@chipdefines_flags)
        return '' unless (@chipdefines_flags[ target ])
        return "#{@chipdefines_flags[ target ].join('  ')}"
    end


    def assembler_flagsline(target)
        return '' unless(analyze_enabled?)
        return '' unless (@assembler_flags)
        return '' unless (@assembler_flags[ target ])
        return " #{@assembler_flags[ target ].join('  ')} "
    end

    def compiler_flagsline(target)
        return '' unless(analyze_enabled?)
        return '' unless (@compiler_flags)
        return '' unless (@compiler_flags[ target ])
        return " #{@compiler_flags[ target ].join('  ')} "
    end

    def cpp_compiler_flagsline(target)
      return '' unless(analyze_enabled?)
      return '' unless (@cpp_compiler_flags)
      return '' unless (@cpp_compiler_flags[ target ])
      return " #{@cpp_compiler_flags[ target ].join('  ')} "
    end

    def archiver_flagsline(target)
        return '' unless(analyze_enabled?)
        return '' unless (@archiver_flags)
        return '' unless (@archiver_flags[ target ])
        return " #{@archiver_flags[ target ].join('  ')} "
    end

end
end

