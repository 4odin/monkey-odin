package monkey_tests

import u "../utils"

import "core:testing"

@(test)
test_utils_get_username :: proc(t: ^testing.T) {
	username := u.get_username()
	defer delete(username)
	testing.expect(t, username != "", "username must not be nil")
}
