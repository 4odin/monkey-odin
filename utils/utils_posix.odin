#+build !windows
package monkey_utils

import "core:os"

get_username :: proc(allocator := context.allocator) -> string {
	return os.get_env("USER", allocator)
}
