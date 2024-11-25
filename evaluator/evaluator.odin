package monkey_evaluator

import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"
import st "core:strings"

import ma "../ast"

@(private = "file")
NULL :: Obj_Null{}

Evaluator :: struct {
	// memory
	_arena:          vmem.Arena,
	pool:            mem.Allocator,

	// internal builders
	_sb:             st.Builder,

	// data storage
	_env:            Environment,

	// methods
	eval:            proc(e: ^Evaluator, node: ma.Node_Program) -> (Object_Base, bool),
	config:          proc(
		e: ^Evaluator,
		pool_reserved_block_size: uint = 1 * mem.Megabyte,
	) -> mem.Allocator_Error,
	free:            proc(e: ^Evaluator),
	pool_total_used: proc(e: ^Evaluator) -> uint,
}

evaluator :: proc() -> Evaluator {
	return {
		eval = eval_program_statements,
		config = evaluator_config,
		free = evaluator_free,
		pool_total_used = evaluator_pool_total_used,
	}
}

@(private = "file")
evaluator_config :: proc(
	e: ^Evaluator,
	pool_reserved_block_size: uint = 1 * mem.Megabyte,
) -> mem.Allocator_Error {
	err := vmem.arena_init_growing(&e._arena, pool_reserved_block_size)
	if err == .None {
		e.pool = vmem.arena_allocator(&e._arena)
		e._sb = st.builder_make(e.pool)
	}

	e._env = environment()

	return err
}

@(private = "file")
evaluator_pool_total_used :: proc(e: ^Evaluator) -> uint {
	return e._arena.total_reserved
}

@(private = "file")
evaluator_free :: proc(e: ^Evaluator) {
	vmem.arena_destroy(&e._arena)
	e._env->free()
}

@(private = "file")
new_error :: proc(e: ^Evaluator, str: string, args: ..any) -> string {
	st.builder_reset(&e._sb)
	fmt.sbprintf(&e._sb, str, ..args)

	err := st.to_string(e._sb)

	return st.clone(err, e.pool)
}

@(private = "file")
eval_program_statements :: proc(e: ^Evaluator, program: ma.Node_Program) -> (Object_Base, bool) {
	result: Object
	ok: bool

	for stmt in program {
		result, ok = eval(e, stmt, &e._env)
		if !ok do return result.(Object_Base), false

		if ret_val, ok_type := result.(Object_Return); ok_type do return to_object_base(ret_val), true
	}

	return to_object_base(result), true
}

@(private = "file")
eval_block_statements :: proc(
	e: ^Evaluator,
	program: ma.Node_Block_Expression,
	current_env: ^Environment,
) -> (
	Object,
	bool,
) {
	result: Object
	ok: bool

	for stmt in program {
		result, ok = eval(e, stmt, current_env)
		if !ok do return result, false

		if obj_is_return(result) do return result, true
	}

	return result, true
}

@(private = "file")
eval_bang_operator_expression :: proc(e: ^Evaluator, operand: Object_Base) -> Object_Base {
	#partial switch data in operand {
	case bool:
		return !data

	case Obj_Null:
		return true
	}

	return false
}

@(private = "file")
eval_minus_operator_expression :: proc(
	e: ^Evaluator,
	operand: Object_Base,
) -> (
	Object_Base,
	bool,
) {
	value, ok := operand.(int)
	if !ok do return new_error(e, "unknown operator: '-' on type '%v'", obj_type(operand)), false

	return -value, true
}

@(private = "file")
eval_prefix_expression :: proc(
	e: ^Evaluator,
	op: string,
	operand: Object_Base,
) -> (
	Object_Base,
	bool,
) {
	switch op {
	case "!":
		return eval_bang_operator_expression(e, operand), true

	case "-":
		return eval_minus_operator_expression(e, operand)
	}

	return new_error(e, "unknown operator: '%s' for type '%v'", op, obj_type(operand)), false
}

@(private = "file")
eval_integer_infix_expression :: proc(
	e: ^Evaluator,
	op: string,
	left: int,
	right: int,
) -> (
	Object_Base,
	bool,
) {
	switch op {
	case "+":
		return left + right, true

	case "-":
		return left - right, true

	case "*":
		return left * right, true

	case "/":
		return left / right, true

	case "<":
		return left < right, true

	case ">":
		return left > right, true

	case "==":
		return left == right, true

	case "!=":
		return left != right, true
	}

	return new_error(e, "unknown integer infix operator '%s'", op), false
}

@(private = "file")
eval_infix_expression :: proc(
	e: ^Evaluator,
	op: string,
	left: Object_Base,
	right: Object_Base,
) -> (
	Object_Base,
	bool,
) {
	if ma.ast_type(left) == int && ma.ast_type(right) == int do return eval_integer_infix_expression(e, op, left.(int), right.(int))

	switch op {
	case "==":
		return left == right, true

	case "!=":
		return left != right, true
	}

	return new_error(
			e,
			"unknown operator '%s' for 'types '%v' and '%v'",
			op,
			obj_type(left),
			obj_type(right),
		),
		false
}

@(private = "file")
is_truthy :: proc(obj: Object) -> bool {
	#partial switch data in to_object_base(obj) {
	case Obj_Null:
		return false

	case bool:
		return data
	}

	return true
}

@(private = "file")
eval_if_expression :: proc(
	e: ^Evaluator,
	node: ma.Node_If_Expression,
	current_env: ^Environment,
) -> (
	Object,
	bool,
) {
	condition, ok := eval(e, node.condition^, current_env)
	if !ok do return condition, false

	if is_truthy(condition) {
		return eval(e, node.consequence, current_env)
	} else if node.alternative != nil {
		return eval(e, node.alternative, current_env)
	}

	return Object_Base(NULL), true
}

@(private = "file")
eval_identifier :: proc(
	e: ^Evaluator,
	node: ma.Node_Identifier,
	current_env: ^Environment,
) -> (
	Object_Base,
	bool,
) {
	val, ok := current_env->get(node.value)
	if !ok do return new_error(e, "identifier '%s' is not declared", node.value), false

	return val, true
}

@(private = "file")
eval :: proc(e: ^Evaluator, node: ma.Node, current_env: ^Environment) -> (Object, bool) {
	#partial switch &data in node {

	// statements
	case ma.Node_Return_Statement:
		val, ok := eval(e, data.ret_val^, current_env)
		if !ok do return val, false
		return Object_Return(to_object_base(val)), true

	case ma.Node_Let_Statement:
		val, ok := eval(e, data.value^, current_env)
		if !ok do return val, false

		_, ok = current_env->get(data.name)
		if ok do return Object_Base(new_error(e, "identifier '%s' is already declared", data.name)), false

		current_env->set(st.clone(data.name, e.pool), to_object_base(val))
		return Object_Base(NULL), true

	// expressions
	case ma.Node_Identifier:
		return eval_identifier(e, data, current_env)

	case ma.Node_Prefix_Expression:
		operand, ok := eval(e, data.operand^, current_env)
		if !ok do return operand, false
		return eval_prefix_expression(e, data.op, to_object_base(operand))

	case ma.Node_Infix_Expression:
		left, ok := eval(e, data.left^, current_env)
		if !ok do return left, false
		right, ok2 := eval(e, data.right^, current_env)
		if !ok2 do return right, ok2
		return eval_infix_expression(e, data.op, to_object_base(left), to_object_base(right))

	case ma.Node_Block_Expression:
		return eval_block_statements(e, data, current_env)

	case ma.Node_If_Expression:
		return eval_if_expression(e, data, current_env)

	case ma.Node_Function_Literal:
		fn := new(Obj_Function, e.pool)

		fn.parameters = make(
			[dynamic]ma.Node_Identifier,
			len(data.parameters),
			cap(data.parameters),
			e.pool,
		)
		copy(fn.parameters[:], data.parameters[:])

		fn.body = make(ma.Node_Block_Expression, 0, cap(data.body), e.pool)

		ma.ast_copy_multiple(&data.body, &fn.body, e.pool)

		fn.env = current_env

		return Object_Base(fn), true

	// literals
	case int:
		return Object_Base(data), true

	case bool:
		return Object_Base(data), true

	case string:
		return Object_Base(data), true
	}

	return Object_Base(new_error(e, "unrecognized Node of type '%v'", ma.ast_type(node))), false
}
