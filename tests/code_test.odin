package tests

import "core:log"

import mv "../vm"

import "core:testing"

concat_instructions :: proc(s: []mv.Instructions) -> mv.Instructions {
	length := 0
	for ins in s {
		length += len(ins)
	}

	out := make(mv.Instructions, length, context.temp_allocator)

	i := 0
	for ins_slice in s {
		for ins in ins_slice {
			out[i] = ins
			i += 1
		}
	}

	return out
}

@(test)
test_code_make :: proc(t: ^testing.T) {
	tests := [?]struct {
		op:       mv.Opcodes,
		operands: []int,
		expected: []byte,
	}{{.Constant, {65534}, {u8(mv.Opcodes.Constant), 255, 254}}}

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

@(test)
test_instructions_string :: proc(t: ^testing.T) {
	instructions := [?]mv.Instructions {
		mv.instruction_make(context.temp_allocator, .Constant, 1),
		mv.instruction_make(context.temp_allocator, .Constant, 2),
		mv.instruction_make(context.temp_allocator, .Constant, 65535),
	}

	defer free_all(context.temp_allocator)

	expected := `0000 OpConstant 1
0003 OpConstant 2
0006 OpConstant 65535
`


	concatenated := concat_instructions(instructions[:])

	instructions_str := mv.instructions_to_string(concatenated, context.temp_allocator)

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
		op:         mv.Opcodes,
		operands:   []int,
		bytes_read: int,
	}{{.Constant, {65535}, 2}}

	defer free_all(context.temp_allocator)

	for test_case, i in tests {
		instruction := mv.instruction_make(
			context.temp_allocator,
			test_case.op,
			..test_case.operands,
		)

		def, ok := mv.lookup(test_case.op)
		if !ok {
			log.errorf("definition not found: %q", test_case.op)
			testing.fail(t)
			continue
		}

		operands_read, n := mv.read_operands(def, instruction[1:], context.temp_allocator)
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
