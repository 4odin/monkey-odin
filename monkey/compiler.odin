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

Bytecode :: struct {
	instructions: []byte,
	constants:    []Object_Base,
}

Compiler :: struct {
	instructions:  ^Instructions,
	constants:     ^[dynamic]Object_Base,

	// methods
	config:        proc(
		c: ^Compiler,
		pool_reserved_block_size: uint = 1 * mem.Megabyte,
		dyn_arr_reserved: uint = 10,
	) -> mem.Allocator_Error,
	compile:       proc(c: ^Compiler, program: Node_Program) -> (err: string),
	bytecode:      proc(c: ^Compiler) -> Bytecode,
	reset:         proc(c: ^Compiler),

	// Managed
	using managed: utils.Mem_Manager(Dap_Item),
}

compiler :: proc(allocator := context.allocator) -> Compiler {
	return {
		config = compiler_config,
		compile = compiler_compile_program,
		bytecode = compiler_bytecode,
		reset = proc(c: ^Compiler) {
			clear(c.instructions)
			clear(c.constants)
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

	c.instructions = utils.register_in_pool(&c.managed, Instructions)
	c.constants = utils.register_in_pool(&c.managed, [dynamic]Object_Base)

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
	ins := instruction_make(c._pool, Opcode(op), ..operands)
	pos := add_instructions(c, ins[:])

	return pos
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
