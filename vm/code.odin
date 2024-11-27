package monkey_vm

import "core:encoding/endian"

Op_Code :: enum u8 {
	Constant,
}

Definition :: struct {
	name:           string,
	operand_widths: []int,
}

definitions := [Op_Code]Definition {
	.Constant = {"OpConstant", {2}},
}

lookup :: proc(op: byte) -> (Definition, bool) {
	def := definitions[Op_Code(op)]

	if def.name == "" do return {}, false

	return def, true
}

instruction_make :: proc(allocator := context.allocator, op: Op_Code, operands: ..int) -> []byte {
	def, ok := lookup(byte(op))
	if !ok do return {}

	inst_len := 1
	for w in def.operand_widths {
		inst_len += w
	}

	instruction := make([]byte, inst_len, allocator)
	instruction[0] = byte(op)

	offset := 1
	for o, i in operands {
		width := def.operand_widths[i]
		switch width {
		case 2:
			endian.put_u16(instruction[offset:], .Big, u16(o))
		}
		offset += width
	}

	return instruction
}
