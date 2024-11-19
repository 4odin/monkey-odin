package monkey_utils

import "core:strings"
import w "core:sys/windows"

foreign import advapi32 "system:Advapi32.lib"

@(default_calling_convention = "system")
foreign advapi32 {
	GetUserNameA :: proc(lpBuffer: w.LPSTR, pcbBuffer: w.LPDWORD) -> w.BOOL ---
}

get_username :: proc(allocator := context.allocator) -> string {
	username: [w.UNLEN + 1]byte
	username_len: w.DWORD = w.UNLEN + 1

	GetUserNameA(&username[0], &username_len)

	return strings.clone_from_ptr(&username[0], int(username_len), allocator)
}
