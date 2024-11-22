package tests

import me "../evaluator"

import "core:log"
import s "core:strings"
import "core:testing"

integer_object_is_valid :: proc(obj: me.Object, expected: int) -> bool {
	result, ok := obj.(int)
	if !ok {
		log.errorf("object is not integer, got='%v'", me.obj_type(obj))
		return false
	}

	if result != expected {
		log.errorf("object has wrong value. got='%d', expected='%d'", result, expected)
		return false
	}

	return true
}

test_eval_integer_expression :: proc(t: ^testing.T) {
	tests := [?]struct {
		input:    string,
		expected: int,
	}{{"5", 5}, {"10", 10}}

	for test_case in tests {
		// get evaluated object

		// integer_object_is_valid
	}
}
