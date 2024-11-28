package monkey_vm

// todo:: import st "core:strings"
import "core:fmt"
import "core:mem"

import ma "../ast"
import me "../evaluator"

import "../utils"

_ :: fmt

@(private = "file")
Dap_Item :: union {
	Instructions,
	[dynamic]me.Object_Base,
}

Bytecode :: struct {
	instructions: []byte,
	constants:    []me.Object_Base,
}

Compiler :: struct {
	instructions:  ^Instructions,
	constants:     ^[dynamic]me.Object_Base,

	// methods
	config:        proc(
		c: ^Compiler,
		pool_reserved_block_size: uint = 1 * mem.Megabyte,
		dyn_arr_reserved: uint = 10,
	) -> mem.Allocator_Error,
	compile:       proc(c: ^Compiler, ast: ma.Node) -> (err: string),
	bytecode:      proc(c: ^Compiler) -> Bytecode,

	// Managed
	using managed: utils.Mem_Manager(Dap_Item),
}

compiler :: proc(allocator := context.allocator) -> Compiler {
	return {
		config = compiler_config,
		compile = compiler_compile,
		bytecode = compiler_bytecode,
		managed = utils.mem_manager(Dap_Item, proc(dyn_pool: [dynamic]Dap_Item) {
			for element in dyn_pool {
				switch kind in element {
				case Instructions:
					delete(kind)

				case [dynamic]me.Object_Base:
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
	c.constants = utils.register_in_pool(&c.managed, [dynamic]me.Object_Base)

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
add_constant :: proc(c: ^Compiler, obj: me.Object_Base) -> int {
	append(c.constants, obj)
	return len(c.constants) - 1
}

@(private = "file")
compiler_compile :: proc(c: ^Compiler, ast: ma.Node) -> (err: string) {
	err = ""

	#partial switch data in ast {
	case ma.Node_Program:
		for s in data {
			if err = c->compile(s); err != "" do return
		}

	case ma.Node_Infix_Expression:
		if err = c->compile(data.left^); err != "" do return
		if err = c->compile(data.right^); err != "" do return

	case int:
		emit(c, .Constant, add_constant(c, data))
	}

	return ""
}

@(private = "file")
compiler_bytecode :: proc(c: ^Compiler) -> Bytecode {
	return {instructions = c.instructions[:], constants = c.constants[:]}
}
