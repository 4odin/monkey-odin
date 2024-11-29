package monkey_odin

import "core:encoding/endian"
import "core:fmt"
import st "core:strings"

Instructions :: distinct [dynamic]byte

Opcode :: enum byte {
	Constant,
	Pop,
	Add,
	Sub,
	Mul,
	Div,
}

Definition :: struct {
	name:           string,
	operand_widths: []int,
}

definitions := [Opcode]Definition {
	.Constant = {"OpConstant", {2}},
	.Pop      = {"OpPop", {}},
	.Add      = {"OpAdd", {}},
	.Sub      = {"OpSub", {}},
	.Mul      = {"OpMul", {}},
	.Div      = {"OpDiv", {}},
}

lookup :: proc(op: Opcode) -> (Definition, bool) {
	def := definitions[Opcode(op)]

	if def.name == "" do return {}, false

	return def, true
}

instruction_make :: proc(
	allocator := context.allocator,
	op: Opcode,
	operands: ..int,
) -> Instructions {
	def, ok := lookup(op)
	if !ok do return {}

	inst_len := 1
	for w in def.operand_widths {
		inst_len += w
	}

	instruction := make(Instructions, inst_len, inst_len, allocator)
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

@(private = "file")
format_instruction :: proc(sb: ^st.Builder, def: Definition, operands: []int) {
	operand_count := len(def.operand_widths)

	if len(operands) != operand_count {
		fmt.sbprintfln(
			sb,
			"ERROR: operand len '%d' does not match defined '%d'",
			len(operands),
			operand_count,
		)
		return
	}

	switch operand_count {
	case 0:
		fmt.sbprint(sb, def.name)
		return

	case 1:
		fmt.sbprintf(sb, "%s %d", def.name, operands[0])
		return
	}

	fmt.sbprintfln(sb, "ERROR: unhandled operand_count for %s", def.name)
}

instructions_to_string :: proc(
	instructions: Instructions,
	allocator := context.allocator,
) -> string {
	sb := st.builder_make(allocator)

	i := 0
	for i < len(instructions) {
		def, ok := lookup(Opcode(instructions[i]))
		if !ok {
			fmt.sbprintfln(&sb, "ERROR: instruction is not defined: %v", instructions[i])
			continue
		}

		operands, read := read_operands(def, instructions[i + 1:], allocator)

		fmt.sbprintf(&sb, "%04d ", i)
		format_instruction(&sb, def, operands)
		fmt.sbprintln(&sb)

		i += 1 + read
	}

	return st.to_string(sb)
}

read_operands :: proc(
	def: Definition,
	ins: []byte,
	allocator := context.allocator,
) -> (
	[]int,
	int,
) {
	operands := make([]int, len(def.operand_widths), allocator)
	offset := 0

	for width, i in def.operand_widths {
		switch width {
		case 2:
			val, _ := read_u16(ins[offset:])
			operands[i] = int(val)
		}

		offset += width
	}

	return operands, offset
}

read_u16 :: proc(ins: []byte) -> (u16, bool) {
	return endian.get_u16(ins, .Big)
}
