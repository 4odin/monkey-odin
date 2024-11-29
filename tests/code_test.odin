package monkey_tests

import "core:log"

import m "../monkey"

import "core:testing"

concat_instructions :: proc(s: []m.Instructions) -> m.Instructions {
	out := make(m.Instructions, 0, context.temp_allocator)

	for ins_slice in s {
		append(&out, ..ins_slice[:])
	}

	return out
}

@(test)
test_code_make :: proc(t: ^testing.T) {
	tests := [?]struct {
		op:       m.Opcode,
		operands: []int,
		expected: []byte,
	}{{.Constant, {65534}, {u8(m.Opcode.Constant), 255, 254}}, {.Add, {}, {u8(m.Opcode.Add)}}}

	defer free_all(context.temp_allocator)

	for test_case, i in tests {
		instruction := m.instructions(context.temp_allocator, test_case.op, ..test_case.operands)

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

@(test)
test_instructions_string :: proc(t: ^testing.T) {
	instructions := [?]m.Instructions {
		m.instructions(context.temp_allocator, .Add),
		m.instructions(context.temp_allocator, .Constant, 2),
		m.instructions(context.temp_allocator, .Constant, 65535),
	}

	defer free_all(context.temp_allocator)

	expected := `0000 OpAdd
0001 OpConstant 2
0004 OpConstant 65535
`


	concatenated := concat_instructions(instructions[:])

	instructions_str := m.instructions_to_string(concatenated, context.temp_allocator)

	if instructions_str != expected {
		log.errorf(
			"instruction wrongly formatted.\nwants='%s'\ngot='%s'",
			expected,
			instructions_str,
		)
		testing.fail(t)
	}
}

@(test)
test_read_operands :: proc(t: ^testing.T) {
	tests := []struct {
		op:         m.Opcode,
		operands:   []int,
		bytes_read: int,
	}{{.Constant, {65535}, 2}}

	defer free_all(context.temp_allocator)

	for test_case, i in tests {
		instruction := m.instructions(context.temp_allocator, test_case.op, ..test_case.operands)

		def, ok := m.lookup(test_case.op)
		if !ok {
			log.errorf("definition not found: %q", test_case.op)
			testing.fail(t)
			continue
		}

		operands_read, n := m.read_operands(def, instruction[1:], context.temp_allocator)
		if n != test_case.bytes_read {
			log.errorf(
				"test[%d] has failed: n wrong. wants='%d', got='%d'",
				i,
				test_case.bytes_read,
				n,
			)
		}

		for want, b_idx in test_case.operands {
			if operands_read[b_idx] != want {
				log.errorf(
					"test[%d] has failed: operand wrong. wants='%d', got='%d'",
					i,
					want,
					operands_read[b_idx],
				)
				testing.fail(t)
			}
		}
	}
}
