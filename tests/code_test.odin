package tests

import "core:log"

import mv "../vm"

import "core:testing"

@(test)
test_code_make :: proc(t: ^testing.T) {
	tests := []struct {
		op:       mv.Op_Code,
		operands: []int,
		expected: []byte,
	}{{.Constant, {65534}, {u8(mv.Op_Code.Constant), 255, 254}}}

	defer free_all(context.temp_allocator)

	for test_case, i in tests {
		instruction := mv.instruction_make(
			context.temp_allocator,
			test_case.op,
			..test_case.operands,
		)

		if len(instruction) != len(test_case.expected) {
			log.errorf(
				"test[%d] has failed: instruction has wrong length. wants='%d', got='%d'",
				i,
				len(test_case.expected),
				len(instruction),
			)
			testing.fail(t)
			continue
		}

		for b, idx in test_case.expected {
			if instruction[idx] != test_case.expected[idx] {
				log.errorf(
					"test[%d] has failed: wrong byte at pos %d. wants='%d', got='%d'",
					i,
					idx,
					b,
					instruction[idx],
				)

				testing.fail(t)
			}
		}
	}
}
