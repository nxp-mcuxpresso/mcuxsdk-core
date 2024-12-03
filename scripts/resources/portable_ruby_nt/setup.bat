@echo off
rem Extract portable ruby to User's harddrive and register it to tne environment variables.
rem TODO: Batch has many limitations like 1024 bytes of PATH variable.
rem TODO: Powershell script requires system policy update.
rem TODO: Add a small exe in future to make this program/script better.

rem Cannot support specified install directory as the script cannot find it when need upgrade.
setlocal enabledelayedexpansion

set DEFAULT_INSTALL_DIR=C:\portable_ruby
set RUBY_BIN=%DEFAULT_INSTALL_DIR%\bin
set WORKSPACE=%cd%
cd /D "%~dp0"
set RUBY_ARCHIEVE=ruby.7z
set ZIPPER=7zr.exe
call md5.bat %RUBY_ARCHIEVE% MD5
set /p C_MD5=<%DEFAULT_INSTALL_DIR%\md5

if not exist "%DEFAULT_INSTALL_DIR%" (
    echo Start extract portable ruby for the first time...
    goto install
) else (
    rem Check version.
	rem Clean variables set in memory.
	echo md5 of latest portable ruby: %MD5%
	echo md5 of installed portable ruby: %C_MD5%
    if "%MD5%" equ "%C_MD5%" (
        echo No update found.
        goto exit
    ) else (
        echo Delete prvious version of portable ruby.
        rd /s /q %DEFAULT_INSTALL_DIR% 1>nul
        set FIRST_RUN=1
        goto install
    )
)

:install
cmd /c %ZIPPER% x -t7z %RUBY_ARCHIEVE% -o%DEFAULT_INSTALL_DIR%
echo %md5%>%DEFAULT_INSTALL_DIR%\md5

rem User PATH variable must exist.
reg query HKCU\Environment /v PATH 2>&1 >nul && (
    reg query HKCU\Environment /v PATH | findstr /C:"%RUBY_BIN%">nul && (
        echo Portable ruby is already in user path.
        goto exit
    )
    rem NOTE: 1024 bytes limitation with setx.
    for /f "skip=2 tokens=3*" %%a in ('reg query HKCU\Environment /v PATH') do (
        if [%%b]==[] ( 
            setx PATH "%RUBY_BIN%;%%~a"
        ) else (
            setx PATH "%RUBY_BIN%;%%~a %%~b"
        )
    )
    echo Please restart the terminal to make the PATH update workable.
) || (
    echo Please add "C:\portable_ruby\bin" at top of your user environment variables.
)
goto exit

:realpath
  SET RETVAL=%~f1
  EXIT /B

:exit
cd /D %WORKSPACE%
