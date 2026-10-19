package terminal

import "core:os"
import "core:sys/posix"
import "core:sys/windows"
import "keys"

when ODIN_OS == .Windows {
	Cooked_State :: windows.DWORD
	Handle :: windows.HANDLE
} else when ODIN_OS == .Linux {
	Cooked_State :: posix.termios
	Handle :: posix.FD
}

Terminal_Error :: union {
	Get_State_Error,
	Set_State_Error,
	Unknown_OS_Error,
	Unknown_Handle_Error,
	Get_Key_Error,
}

Get_State_Error :: struct {}

Set_State_Error :: struct {}

Unknown_OS_Error :: struct {
	os: type_of(ODIN_OS),
}

Unknown_Handle_Error :: struct {}

Get_Key_Error :: struct {}

enable_raw_state :: proc(nonblocking := false) -> (Cooked_State, Handle, Terminal_Error) {
	when ODIN_OS == .Linux {
		return enable_raw_state_linux(nonblocking)
	} else {
		return 0, nil, Unknown_OS_Error{ODIN_OS}
	}
}

disable_raw_state :: proc(cooked_state: ^Cooked_State, handle: Handle) -> Terminal_Error {
	when ODIN_OS == .Linux {
		disable_raw_state_linux(cooked_state, handle)
		return nil
	}

	return Unknown_OS_Error{ODIN_OS}
}

read_key_bytes :: proc(handle: Handle, buf: []u8) -> (keys.Key_Event, bool, Terminal_Error) {
	when ODIN_OS == .Linux {
		return read_key_bytes_linux(handle, buf)
	} else {
		return {}, false, Unknown_OS_Error{ODIN_OS}
	}
}

when ODIN_OS == .Linux {
	enable_raw_state_linux :: proc(
		nonblocking := false,
	) -> (
		Cooked_State,
		Handle,
		Terminal_Error,
	) {
		cooked_state: posix.termios
		res := posix.tcgetattr(posix.STDIN_FILENO, &cooked_state)
		assert(res == .OK)

		raw_state := cooked_state
		raw_state.c_lflag -= {.ECHO, .ICANON}

		res = posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &raw_state)
		assert(res == .OK)

		if nonblocking {
			flags := posix.fcntl(posix.STDIN_FILENO, posix.FCNTL_Cmd(posix.F_GETFL), 0)
			assert(flags >= 0)

			res_flags := posix.fcntl(
				posix.STDIN_FILENO,
				posix.FCNTL_Cmd(posix.F_SETFL),
				flags | posix.O_NONBLOCK,
			)
			assert(res_flags >= 0)
		}

		os.write(os.stdout, transmute([]u8)string("\033[>31u")) // enable Kitty Keyboard Protocol

		return cooked_state, Handle(posix.STDIN_FILENO), nil
	}

	disable_raw_state_linux :: proc(cooked_state: ^Cooked_State, handle: Handle) {
		res := posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, cooked_state)

		os.write(os.stdout, transmute([]u8)string("\033[<u"))
	}

	read_key_bytes_linux :: proc(
		handle: Handle,
		buf: []u8,
		report_releases := false,
	) -> (
		keys.Key_Event,
		bool,
		Terminal_Error,
	) {
		bytes_read := posix.read(posix.STDIN_FILENO, raw_data(buf), len(buf))

		if bytes_read < 0 {
			errno := posix.errno()

			if errno == posix.Errno(posix.EAGAIN) || errno == posix.Errno(posix.EWOULDBLOCK) {
				return {}, false, nil
			}

			return {}, false, Get_Key_Error{}
		}

		key_event, ok := keys.parse_key_linux(buf[:bytes_read], report_releases)
		if !ok {
			return {}, false, nil
		}

		return key_event, true, nil
	}
}
