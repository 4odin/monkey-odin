package monkey_odin

import "core:fmt"
import "core:mem"
import st "core:strings"

import "../utils"

_ :: fmt

@(private = "file")
Dap_Item :: union {
	Instructions,
	[dynamic]Object_Base,
}

Emitted_Instruction :: struct {
	op_code: Opcode,
	pos:     int,
}

Bytecode :: struct {
	instructions: []byte,
	constants:    []Object_Base,
}

Compiler :: struct {
	instructions:         ^Instructions,
	constants:            ^[dynamic]Object_Base,
	symbol_table:         Symbol_Table,

	// tracking instructions
	last_instruction:     Emitted_Instruction,
	previous_instruction: Emitted_Instruction,

	// methods
	config:               proc(
		c: ^Compiler,
		pool_reserved_block_size: uint = 1 * mem.Megabyte,
		dyn_arr_reserved: uint = 10,
	) -> mem.Allocator_Error,
	compile:              proc(c: ^Compiler, program: Node_Program) -> (err: string),
	bytecode:             proc(c: ^Compiler) -> Bytecode,
	reset:                proc(c: ^Compiler, keep_state := true),
	free:                 proc(c: ^Compiler),

	// Managed
	using managed:        utils.Mem_Manager(Dap_Item),
}

compiler :: proc(allocator := context.allocator) -> Compiler {
	return {
		config = compiler_config,
		compile = compiler_compile_program,
		bytecode = compiler_bytecode,
		reset = proc(c: ^Compiler, keep_state := true) {
			clear(c.instructions)

			if !keep_state {
				clear(c.constants)
				c.symbol_table->reset()
			}
		},
		free = proc(c: ^Compiler) {
			c->mem_free()
			c.symbol_table->free()
		},
		managed = utils.mem_manager(Dap_Item, proc(dyn_pool: [dynamic]Dap_Item) {
			for element in dyn_pool {
				switch kind in element {
				case Instructions:
					delete(kind)

				case [dynamic]Object_Base:
					delete(kind)
				}
			}
		}),
	}
}

// ***************************************************************************************
// PRIVATE TYPES AND PROCEDURES
// ***************************************************************************************

@(private = "file")
compiler_config :: proc(
	c: ^Compiler,
	pool_reserved_block_size: uint = 1 * mem.Megabyte,
	dyn_arr_reserved: uint = 10,
) -> mem.Allocator_Error {
	err := c->mem_config(pool_reserved_block_size, dyn_arr_reserved)

	c.symbol_table = symbol_table()

	if err == .None {
		c.instructions = utils.register_in_pool(&c.managed, Instructions)
		c.constants = utils.register_in_pool(&c.managed, [dynamic]Object_Base)
	}

	return err
}

@(private = "file")
add_instructions :: proc(c: ^Compiler, ins: []byte) -> int {
	pos := len(c.instructions)
	append(c.instructions, ..ins)

	return pos
}

@(private = "file")
emit :: proc(c: ^Compiler, op: Opcode, operands: ..int) -> int {
	ins := instructions(c._pool, Opcode(op), ..operands)
	pos := add_instructions(c, ins[:])

	set_last_instruction(c, op, pos)

	return pos
}

@(private = "file")
set_last_instruction :: proc(c: ^Compiler, op: Opcode, pos: int) {
	previous := c.last_instruction
	last := Emitted_Instruction{op, pos}

	c.previous_instruction = previous
	c.last_instruction = last
}

@(private = "file")
last_instruction_is_pop :: proc(c: ^Compiler) -> bool {
	return c.last_instruction.op_code == .Pop
}

@(private = "file")
remove_last_pop :: proc(c: ^Compiler) {
	unordered_remove(c.instructions, c.last_instruction.pos)
	c.last_instruction = c.previous_instruction
}

@(private = "file")
replace_instruction :: proc(c: ^Compiler, pos: int, new_instruction: []byte) {
	for i := 0; i < len(new_instruction); i += 1 {
		c.instructions[pos + i] = new_instruction[i]
	}
}

@(private = "file")
change_operand :: proc(c: ^Compiler, op_pos: int, operand: int) {
	op := Opcode(c.instructions[op_pos])
	new_instruction := instructions(c._pool, op, operand)

	replace_instruction(c, op_pos, new_instruction[:])
}

@(private = "file")
add_constant :: proc(c: ^Compiler, obj: Object_Base) -> int {
	append(c.constants, obj)
	return len(c.constants) - 1
}

@(private = "file")
compiler_bytecode :: proc(c: ^Compiler) -> Bytecode {
	return {instructions = c.instructions[:], constants = c.constants[:]}
}

@(private = "file")
compiler_compile :: proc(c: ^Compiler, ast: Node) -> (err: string) {
	err = ""

	#partial switch data in ast {
	case Node_Let_Statement:
		if err = compiler_compile(c, data.value^); err != "" do return
		sym_name_copy, _ := st.clone(data.name, c._pool)
		symbol := c.symbol_table->define(sym_name_copy)

		emit(c, .Set_G, symbol.index)

	case Node_Identifier:
		symbol, ok := c.symbol_table->resolve(data.value)
		if !ok {
			st.builder_reset(&c._sb)
			fmt.sbprintf(&c._sb, "undefined symbol '%s'", data.value)
			err = st.to_string(c._sb)
			return
		}

		emit(c, .Get_G, symbol.index)

	case Node_Infix_Expression:
		if data.op == "<" {
			if err = compiler_compile(c, data.right^); err != "" do return
			if err = compiler_compile(c, data.left^); err != "" do return

			emit(c, .Gt)
			return
		}

		if err = compiler_compile(c, data.left^); err != "" do return
		if err = compiler_compile(c, data.right^); err != "" do return

		switch data.op {
		case "+":
			emit(c, .Add)

		case "-":
			emit(c, .Sub)

		case "*":
			emit(c, .Mul)

		case "/":
			emit(c, .Div)

		case ">":
			emit(c, .Gt)

		case "==":
			emit(c, .Eq)

		case "!=":
			emit(c, .Neq)

		case:
			st.builder_reset(&c._sb)
			fmt.sbprintf(&c._sb, "unknown infix operator '%s'", data.op)
			err = st.to_string(c._sb)
		}

	case Node_Prefix_Expression:
		if err = compiler_compile(c, data.operand^); err != "" do return

		switch data.op {
		case "!":
			emit(c, .Not)

		case "-":
			emit(c, .Neg)

		case:
			st.builder_reset(&c._sb)
			fmt.sbprintf(&c._sb, "unknown prefix operator '%s'", data.op)
			err = st.to_string(c._sb)
		}

	case Node_If_Expression:
		if err = compiler_compile(c, data.condition^); err != "" do return

		// Emit an `OpJumpIfNotTrue` with bogus value
		jump_if_not_pos := emit(c, .Jmp_If_Not, 9999)

		if err = compiler_compile(c, data.consequence); err != "" do return

		if last_instruction_is_pop(c) do remove_last_pop(c)

		// Emit an `OpJump` with a bogus value
		jump_pos := emit(c, .Jmp, 9999)

		after_consequence_pos := len(c.instructions)
		change_operand(c, jump_if_not_pos, after_consequence_pos)

		if data.alternative == nil {
			emit(c, .Nil)
		} else {
			if err = compiler_compile(c, data.alternative); err != "" do return

			if last_instruction_is_pop(c) do remove_last_pop(c)

		}

		after_alternative_pos := len(c.instructions)
		change_operand(c, jump_pos, after_alternative_pos)

	case Node_Block_Expression:
		for s in data {
			if err = compiler_compile(c, s); err != "" do return

			if ast_is_expression_statement(s) {
				emit(c, .Pop)
			}
		}

	case int:
		emit(c, .Constant, add_constant(c, data))

	case bool:
		emit(c, .True if data else .False)
	}

	return
}

@(private = "file")
compiler_compile_program :: proc(c: ^Compiler, program: Node_Program) -> (err: string) {
	err = ""

	for s in program {
		if err = compiler_compile(c, s); err != "" do return

		if ast_is_expression_statement(s) {
			emit(c, .Pop)
		}
	}

	return
}
