# Portable ruby
SDK Generator provided a portable version of a stable ruby environment together with required gems.

If you have already installed a ruby and added it in PATH, please remove it from PATH. Otherwise, the portable ruby will not work. And please ensure PATH variable is in your user environment variables.

The configuration of portable ruby is quite easy, just run the batch file in `<mcu-sdk-2.0>/bin/install_portable_ruby.bat` or `<mcu-sdk-generator/bin/windows/setup>`. Re-run the script will automatically check for updates and install if exists.

If you see something like `WARNING: The data being saved is truncated to 1024 characters.` You have to add `C:\portable_ruby\bin` to your user PATH manually.

You can check the installation by following command:
```shell
$ which ruby
/c/portable_ruby/bin/ruby
```
