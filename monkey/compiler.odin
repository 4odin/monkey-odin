package monkey_odin

import "core:fmt"
import "core:mem"
import "core:slice"
import st "core:strings"

import "core:log"

import "../utils"

_ :: fmt
_ :: log

@(private = "file")
Dap_Item :: union {
	Instructions,
	[dynamic]Compilation_Scope,
}

Emitted_Instruction :: struct {
	op_code: Opcode,
	pos:     int,
}

Bytecode :: struct {
	instructions: []byte,
	constants:    []Object_Base,
}

Compilation_Scope :: struct {
	instructions:         ^Instructions,
	last_instruction:     Emitted_Instruction,
	previous_instruction: Emitted_Instruction,
}

Compiler :: struct {
	compiler_state: ^Compiler_State,

	// current symbol table
	symbol_table:   ^Symbol_Table,

	// scopes
	scopes:         ^[dynamic]Compilation_Scope,
	scope_index:    int,

	// methods
	init:           proc(
		c: ^Compiler,
		compiler_state: ^Compiler_State,
		pool_reserved_block_size: uint = 1 * mem.Megabyte,
		dyn_arr_reserved: uint = 10,
	) -> mem.Allocator_Error,
	compile:        proc(c: ^Compiler, program: Node_Program) -> (err: string),
	emit:           proc(c: ^Compiler, op: Opcode, operands: ..int) -> int,
	bytecode:       proc(c: ^Compiler) -> Bytecode,
	enter_scope:    proc(c: ^Compiler),
	leave_scope:    proc(c: ^Compiler) -> ^Instructions,

	// Managed
	using managed:  utils.Mem_Manager(Dap_Item),
}

compiler :: proc(allocator := context.allocator) -> Compiler {
	return {
		init = compiler_init,
		compile = compiler_compile_program,
		emit = compiler_emit,
		bytecode = compiler_bytecode,
		enter_scope = compiler_enter_scope,
		leave_scope = compiler_leave_scope,
		managed = utils.mem_manager(Dap_Item, proc(dyn_pool: [dynamic]Dap_Item) {
			for element in dyn_pool {
				switch kind in element {
				case Instructions:
					delete(kind)

				case [dynamic]Compilation_Scope:
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
compiler_init :: proc(
	c: ^Compiler,
	compiler_state: ^Compiler_State,
	pool_reserved_block_size: uint = 1 * mem.Megabyte,
	dyn_arr_reserved: uint = 10,
) -> mem.Allocator_Error {
	err := c->mem_init(pool_reserved_block_size, dyn_arr_reserved)

	c.compiler_state = compiler_state
	c.symbol_table = &compiler_state.symbol_table

	if err == .None {
		c.scopes = utils.register_in_pool(&c.managed, [dynamic]Compilation_Scope)

		main_scope := Compilation_Scope{}
		main_scope.instructions = utils.register_in_pool(&c.managed, Instructions)

		append(c.scopes, main_scope)
	}

	return err
}

@(private = "file")
compiler_enter_scope :: proc(c: ^Compiler) {
	scope := Compilation_Scope{}
	scope.instructions = utils.register_in_pool(&c.managed, Instructions)

	append(c.scopes, scope)
	c.scope_index = len(c.scopes) - 1

	c.symbol_table = utils.register_in_pool(
		&c.compiler_state.managed,
		new_clone(symbol_table(c.compiler_state._pool, outer = c.symbol_table)),
	)
}

@(private = "file")
compiler_leave_scope :: proc(c: ^Compiler) -> ^Instructions {
	instructions := current_instructions(c)

	pop(c.scopes)
	c.scope_index = len(c.scopes) - 1

	c.symbol_table = c.symbol_table.outer

	return instructions
}

@(private = "file")
current_instructions :: proc(c: ^Compiler) -> ^Instructions {
	return c.scopes[c.scope_index].instructions
}

@(private = "file")
add_instructions :: proc(c: ^Compiler, ins: []byte) -> int {
	pos := len(current_instructions(c))
	append(current_instructions(c), ..ins)

	return pos
}

@(private = "file")
compiler_emit :: proc(c: ^Compiler, op: Opcode, operands: ..int) -> int {
	ins := make_instructions(c._pool, Opcode(op), ..operands)
	pos := add_instructions(c, ins[:])

	set_last_instruction(c, op, pos)

	return pos
}

@(private = "file")
set_last_instruction :: proc(c: ^Compiler, op: Opcode, pos: int) {
	previous := c.scopes[c.scope_index].last_instruction
	last := Emitted_Instruction{op, pos}

	c.scopes[c.scope_index].previous_instruction = previous
	c.scopes[c.scope_index].last_instruction = last
}

@(private = "file")
last_instruction_is :: proc(c: ^Compiler, op: Opcode) -> bool {
	if len(current_instructions(c)) == 0 do return false

	return c.scopes[c.scope_index].last_instruction.op_code == op
}

@(private = "file")
remove_last_pop :: proc(c: ^Compiler) {
	ordered_remove(
		c.scopes[c.scope_index].instructions,
		c.scopes[c.scope_index].last_instruction.pos,
	)

	c.scopes[c.scope_index].last_instruction = c.scopes[c.scope_index].previous_instruction
}

@(private = "file")
replace_instruction :: proc(c: ^Compiler, pos: int, new_instruction: []byte) {
	ins := current_instructions(c)

	for i := 0; i < len(new_instruction); i += 1 {
		ins[pos + i] = new_instruction[i]
	}
}

@(private = "file")
replace_last_pop_with_return :: proc(c: ^Compiler) {
	last_pos := c.scopes[c.scope_index].last_instruction.pos

	replace_instruction(c, last_pos, make_instructions(c.compiler_state._pool, .Ret_V)[:])

	c.scopes[c.scope_index].last_instruction.op_code = .Ret_V
}

@(private = "file")
change_operand :: proc(c: ^Compiler, op_pos: int, operand: int) {
	op := Opcode(current_instructions(c)[op_pos])
	new_instruction := make_instructions(c._pool, op, operand)

	replace_instruction(c, op_pos, new_instruction[:])
}

@(private = "file")
add_constant :: proc(c: ^Compiler, obj: Object_Base) -> int {
	append(&c.compiler_state.constants, obj)
	return len(c.compiler_state.constants) - 1
}

@(private = "file")
compiler_bytecode :: proc(c: ^Compiler) -> Bytecode {
	return {instructions = current_instructions(c)[:], constants = c.compiler_state.constants[:]}
}

@(private = "file")
compiler_compile :: proc(c: ^Compiler, ast: Node) -> (err: string) {
	err = ""

	#partial switch data in ast {
	case Node_Let_Statement:
		if err = compiler_compile(c, data.value^); err != "" do return
		symbol := c.symbol_table->define(data.name)

		compiler_emit(c, .Set_G if symbol.scope == .Global else .Set_L, symbol.index)

	case Node_Return_Statement:
		if err = compiler_compile(c, data.ret_val^); err != "" do return

		compiler_emit(c, .Ret_V)

	case Node_Identifier:
		symbol, ok := c.symbol_table->resolve(data.value)
		if !ok {
			st.builder_reset(&c._sb)
			fmt.sbprintf(&c._sb, "undefined symbol '%s'", data.value)
			err = st.to_string(c._sb)
			return
		}
		compiler_emit(c, .Get_G if symbol.scope == .Global else .Get_L, symbol.index)

	case Node_Infix_Expression:
		if data.op == "<" {
			if err = compiler_compile(c, data.right^); err != "" do return
			if err = compiler_compile(c, data.left^); err != "" do return

			compiler_emit(c, .Gt)
			return
		}

		if err = compiler_compile(c, data.left^); err != "" do return
		if err = compiler_compile(c, data.right^); err != "" do return

		switch data.op {
		case "+":
			compiler_emit(c, .Add)

		case "-":
			compiler_emit(c, .Sub)

		case "*":
			compiler_emit(c, .Mul)

		case "/":
			compiler_emit(c, .Div)

		case ">":
			compiler_emit(c, .Gt)

		case "==":
			compiler_emit(c, .Eq)

		case "!=":
			compiler_emit(c, .Neq)

		case:
			st.builder_reset(&c._sb)
			fmt.sbprintf(&c._sb, "unknown infix operator '%s'", data.op)
			err = st.to_string(c._sb)
		}

	case Node_Prefix_Expression:
		if err = compiler_compile(c, data.operand^); err != "" do return

		switch data.op {
		case "!":
			compiler_emit(c, .Not)

		case "-":
			compiler_emit(c, .Neg)

		case:
			st.builder_reset(&c._sb)
			fmt.sbprintf(&c._sb, "unknown prefix operator '%s'", data.op)
			err = st.to_string(c._sb)
		}

	case Node_If_Expression:
		if err = compiler_compile(c, data.condition^); err != "" do return

		// Emit an `OpJumpIfNotTrue` with bogus value
		jump_if_not_pos := compiler_emit(c, .Jmp_If_Not, 9999)

		if err = compiler_compile(c, data.consequence); err != "" do return

		if last_instruction_is(c, .Pop) do remove_last_pop(c)

		// Emit an `OpJump` with a bogus value
		jump_pos := compiler_emit(c, .Jmp, 9999)

		after_consequence_pos := len(current_instructions(c))
		change_operand(c, jump_if_not_pos, after_consequence_pos)

		if data.alternative == nil {
			compiler_emit(c, .Nil)
		} else {
			if err = compiler_compile(c, data.alternative); err != "" do return

			if last_instruction_is(c, .Pop) do remove_last_pop(c)

		}

		after_alternative_pos := len(current_instructions(c))
		change_operand(c, jump_pos, after_alternative_pos)

	case Node_Block_Expression:
		for s in data {
			if err = compiler_compile(c, s); err != "" do return

			if ast_is_expression_statement(s) {
				compiler_emit(c, .Pop)
			}
		}

	case Node_Array_Literal:
		for el in data {
			if err = compiler_compile(c, el); err != "" do return
		}

		compiler_emit(c, .Arr, len(data))

	case Node_Hash_Table_Literal:
		keys := make([]string, len(data), c._pool)
		i := 0
		for key in data {
			keys[i] = key
			i += 1
		}

		slice.reverse_sort(keys) // for tests only (not needed)


		for k in keys {
			if err = compiler_compile(c, k); err != "" do return
			if err = compiler_compile(c, data[k]); err != "" do return
		}

		compiler_emit(c, .Ht, len(data) * 2)

	case Node_Index_Expression:
		if err = compiler_compile(c, data.operand^); err != "" do return
		if err = compiler_compile(c, data.index^); err != "" do return

		compiler_emit(c, .Idx)

	case Node_Function_Literal:
		compiler_enter_scope(c)
		if err = compiler_compile(c, data.body); err != "" do return

		if last_instruction_is(c, .Pop) do replace_last_pop_with_return(c)

		if !last_instruction_is(c, .Ret_V) do compiler_emit(c, .Ret)

		instructions := compiler_leave_scope(c)
		compiled_fn := utils.register_in_pool(
			&c.compiler_state.managed,
			Obj_Compiled_Fn_Obj,
			len(instructions),
		)

		if len(instructions) > 0 {
			inject_at(compiled_fn, 0, ..instructions[:])
		}

		compiler_emit(c, .Cnst, add_constant(c, compiled_fn))

	case Node_Call_Expression:
		if err = compiler_compile(c, data.function^); err != "" do return
		compiler_emit(c, .Call)

	case int:
		compiler_emit(c, .Cnst, add_constant(c, data))

	case bool:
		compiler_emit(c, .True if data else .False)

	case string:
		string_cpy, _ := st.clone(data, c.compiler_state._pool)
		compiler_emit(c, .Cnst, add_constant(c, string_cpy))
	}

	return
}

@(private = "file")
compiler_compile_program :: proc(c: ^Compiler, program: Node_Program) -> (err: string) {
	err = ""

	for s in program {
		if err = compiler_compile(c, s); err != "" do return

		if ast_is_expression_statement(s) {
			compiler_emit(c, .Pop)
		}
	}

	return
}
