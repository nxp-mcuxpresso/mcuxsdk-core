rem(){ :;};rem '
@goto b
';
#!/bin/sh

build_target=$(echo $xt_build_target | tr [:upper:] [:lower:])

echo post all rule
echo ${xt_build_sysargs}
echo ${xt_build_project}
echo ${xt_exe}

bin_path=binary
if [ ! -d $bin_path ]; then
    mkdir $bin_path
fi

xt-objcopy ${xt_build_sysargs} -O binary ${xt_exe} binary/dsp_text_$build_target.bin \
--only-section=.WindowVectors.text \
--only-section=.Level2InterruptVector.text \
--only-section=.Level3InterruptVector.literal \
--only-section=.Level3InterruptVector.text \
--only-section=.DebugExceptionVector.literal \
--only-section=.DebugExceptionVector.text \
--only-section=.NMIExceptionVector.literal \
--only-section=.NMIExceptionVector.text \
--only-section=.KernelExceptionVector.text \
--only-section=.UserExceptionVector.text \
--only-section=.DoubleExceptionVector.text \
--only-section=.text

xt-objcopy ${xt_build_sysargs} -O binary ${xt_exe} binary/dsp_data_$build_target.bin \
--only-section=.clib.rodata \
--only-section=.rtos.rodata \
--only-section=.rodata \
--only-section=.clib.data \
--only-section=.rtos.percpu.data \
--only-section=.data \
--only-section=.bss

xt-objcopy ${xt_build_sysargs} -O binary ${xt_exe} binary/dsp_reset_$build_target.bin \
--only-section=.ResetVector.text
exit

:b
@echo off
:: get build target from the environment variable and make it's first letter lowercase
setlocal enabledelayedexpansion
set build_target=%xt_build_target%
set build_target=!build_target:D=d!
set build_target=!build_target:R=r!

@echo post all rule
@echo %xt_build_sysargs%
@echo %xt_build_project%
@echo %xt_exe%

if not exist binary mkdir binary

xt-objcopy %xt_build_sysargs% -O binary %xt_exe% binary/dsp_text_%build_target%.bin ^
--only-section=.WindowVectors.text ^
--only-section=.Level2InterruptVector.text ^
--only-section=.Level3InterruptVector.literal ^
--only-section=.Level3InterruptVector.text ^
--only-section=.DebugExceptionVector.literal ^
--only-section=.DebugExceptionVector.text ^
--only-section=.NMIExceptionVector.literal ^
--only-section=.NMIExceptionVector.text ^
--only-section=.KernelExceptionVector.text ^
--only-section=.UserExceptionVector.text ^
--only-section=.DoubleExceptionVector.text ^
--only-section=.text

xt-objcopy %xt_build_sysargs% -O binary %xt_exe% binary/dsp_data_%build_target%.bin ^
--only-section=.clib.rodata ^
--only-section=.rtos.rodata ^
--only-section=.rodata ^
--only-section=.clib.data ^
--only-section=.rtos.percpu.data ^
--only-section=.data ^
--only-section=.bss

xt-objcopy %xt_build_sysargs% -O binary %xt_exe% binary/dsp_reset_%build_target%.bin ^
--only-section=.ResetVector.text
