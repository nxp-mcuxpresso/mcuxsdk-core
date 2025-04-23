# Insert_board_name_into_per_example_yml.py
## What?
* The script is used to insert board name and toolchians(include multiple targets) that should be supported by the board into example.yml in mcu-sdk-3.0/examples/demo_apps, mcu-sdk-3.0/examples/driver_examples and so oni(E.g mcu-sdk-3.0/examples/demo_apps/hello_world).
* Process flow
	* Search hardware_init.c in demos in directory examples/<board name>.
	* Replace path from examples/<board> to mcu-sdk-3.0/examples.
	* Find example.yml in demos/examples(E.g mcu-sdk-3.0/example/demo_apps/hello_world/example.yml).
	* When example.yml is not found.
		* Output log into the file mcu-sdk-3.0/error_demos.txt. Please check the file to update example.yml manually.
	* When example.yml is found.
		* Insert new sub key <board name> or <board name>@<core name> into example.yml.
		* Insert new item under the new sub key.
		* Output as below,
		```
		In mcu-sdk-3.0/examples/demo_apps/hello_world/example.yml
		imx95lpd5evk19@cm7:
		- +armgcc@debug
		- +armgcc@release

		```
## How?
* Command
```
mcu-sdk-3.0$ python scripts/misc/insert_board_name_into_per_example_yml.py imx95lpd5evk19 armgcc debug
```
