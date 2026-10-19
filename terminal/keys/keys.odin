package keys

import "core:bytes"
import "core:strconv"

Modifiers :: struct {
	shift:     bool,
	alt:       bool,
	ctrl:      bool,
	super:     bool,
	hyper:     bool,
	meta:      bool,
	caps_lock: bool,
	num_lock:  bool,
}

Type :: enum {
	PRESS,
	REPEAT,
	RELEASE,
}

Key_Event :: struct {
	key:       rune,
	modifiers: Modifiers,
	type:      Type,
}

when ODIN_OS == .Linux {
	parse_key_linux :: proc(buf: []u8, report_releases := false) -> (Key_Event, bool) {
		if len(buf) < 3 || buf[0] != 0x1b || buf[1] != 0x5b || buf[len(buf) - 1] != 0x75 { 	// verify key event identifiers exist
			return {}, false
		}

		buf := buf[2:len(buf) - 1] // cut out key event identifiers

		split_terms := bytes.split(buf, {';'}) // split key event at ';'
		defer delete(split_terms)

		// key code is the pressed key, in byte form
		key_pressed: rune
		{
			split_key_code := bytes.split(split_terms[0], {':'}) // split key code at ':'
			defer delete(split_key_code)

			key_code, ok := strconv.parse_int(string(split_key_code[0])) // first element is the key code, second is shifted key, third is code point
			if !ok {
				return {}, false
			}
			key_pressed = rune(key_code) // rune of pressed key
		}

		// modifiers are... modifier keys (ctrl, shift, alt, etc.)
		modifiers: Modifiers
		type: Type
		{
			split_modifer_value := bytes.split(split_terms[1], {':'}) // split modifier value at ':'
			defer delete(split_modifer_value)

			modifier_value, ok := strconv.parse_int(string(split_modifer_value[0])) // first element is modifer value, second is event type
			if !ok {
				return {}, false
			}

			modifier_value -= 1 // modifer is a bitmask, plus 1

			if (modifier_value & (1 << 0)) != 0 { 	// if first bit it 1, shift is pressed
				modifiers.shift = true
			}
			if (modifier_value & (1 << 1)) != 0 { 	// if first bit it 1, alt is pressed
				modifiers.alt = true
			}
			if (modifier_value & (1 << 2)) != 0 { 	// if third bit it 1, ctrl is ressed
				modifiers.ctrl = true
			}
			if (modifier_value & (1 << 3)) != 0 { 	// if the four... you get the idea
				modifiers.super = true
			}
			if (modifier_value & (1 << 4)) != 0 {
				modifiers.hyper = true
			}
			if (modifier_value & (1 << 5)) != 0 {
				modifiers.meta = true
			}
			if (modifier_value & (1 << 6)) != 0 {
				modifiers.caps_lock = true
			}
			if (modifier_value & (1 << 7)) != 0 {
				modifiers.num_lock = true
			}

			// optional event type, 1 for press, 2 for hold, 3 for release
			if len(split_modifer_value) > 1 { 	// could not exist, make sure to check if it does
				event_type: int
				event_type, ok = strconv.parse_int(string(split_modifer_value[1])) // second element is event type
				if !ok {
					return {}, false
				}

				if !report_releases && event_type == 3 { 	// if user doesn't want key ups and one occurs, return nothing
					return {}, false
				}

				event_type -= 1 // type is 1-3, enum is 0-2

				type = Type(event_type)
			}
		}


		return Key_Event{key = key_pressed, modifiers = modifiers, type = type}, true
	}
}
