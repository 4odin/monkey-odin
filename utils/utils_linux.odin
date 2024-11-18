package monkey_utils

import "core:os"

get_username :: proc() -> string {
	return os.get_env("USER")
}
