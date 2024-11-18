package monkey_utils

import "core:strings"
import "core:sys/windows"

foreign import advapi32 "system:Advapi32.lib"

@(default_calling_convention = "system")
foreign advapi32 {
	GetUserNameA :: proc(lpBuffer: windows.LPSTR, pcbBuffer: windows.LPDWORD) -> windows.BOOL ---
}

get_username :: proc() -> string {
	username: [windows.UNLEN + 1]byte
	username_len: windows.DWORD = windows.UNLEN + 1

	GetUserNameA(&username[0], &username_len)

	return strings.clone_from_ptr(&username[0], int(username_len))
}
