# SimpleTerm
**SimpleTerm** is a simple terminal control package for Odin \
It handles entering and exiting raw mode and getting user input \
 \
Currently, it only works on Linux, as I do not know how the Windows API for user input works. The Linux version, however is completed and should undergo minimal changes.

# Examples
Below is a simple setup for **SimpleTerm** that allows the user to exit the program by pressing `ctrl+c`:
```
package main

import "core:fmt"
import "terminal"
import "terminal/keys"

main :: proc() {
	cooked_state, handle, err := terminal.enable_raw_state()
	if err != nil {
		fmt.eprintfln("Error enabling raw mode: %v", err)
	}
	defer terminal.disable_raw_state(&cooked_state, handle)

	input_buf: [256]u8

	for true {
		key_event, ok, err := terminal.read_key_bytes(handle, input_buf[:])
		if err != nil {
			fmt.eprintfln("Failed to read key: %v", err)
		}

		if ok {
			fmt.println(key_event)
		}

		if key_event.key == 'c' && key_event.modifiers.ctrl {
			break
		}
	}
}
```
