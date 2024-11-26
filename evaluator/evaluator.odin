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
	_pool:           mem.Allocator,

	// internal builders
	_sb:             st.Builder,

	// data storage
	_env:            Environment,

	// methods
	eval:            proc(
		e: ^Evaluator,
		node: ma.Node_Program,
		allocator := context.allocator,
	) -> (
		Object_Base,
		bool,
	),
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
		e._pool = vmem.arena_allocator(&e._arena)
		e._sb = st.builder_make(e._pool)
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

	return st.clone(err, e._pool)
}

@(private = "file")
eval_program_statements :: proc(
	e: ^Evaluator,
	program: ma.Node_Program,
	allocator := context.allocator,
) -> (
	Object_Base,
	bool,
) {
	result: Object
	ok: bool

	for stmt in program {
		result, ok = eval(e, stmt, &e._env)
		if !ok do return result.(Object_Base), false

		if _, ok_type := result.(Object_Return); ok_type do break
	}

	temp, is_str := to_object_base(result).(string)
	if is_str {
		result = Object_Base(st.clone(temp, allocator))
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
eval_string_infix_expression :: proc(
	e: ^Evaluator,
	op: string,
	left: string,
	right: string,
) -> (
	Object_Base,
	bool,
) {
	if op != "+" do return new_error(e, "unknown string infix operator '%s'", op), false

	st.builder_reset(&e._sb)
	fmt.sbprintf(&e._sb, "%s%s", left, right)

	result := st.to_string(e._sb)

	return st.clone(result, e._pool), true
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
	if ma.ast_type(left) == int && ma.ast_type(right) == int {
		return eval_integer_infix_expression(e, op, left.(int), right.(int))
	} else if ma.ast_type(left) == string && ma.ast_type(right) == string {
		return eval_string_infix_expression(e, op, left.(string), right.(string))
	}

	switch op {
	case "==":
		return left == right, true

	case "!=":
		return left != right, true
	}

	return new_error(
			e,
			"unknown operator '%s' for types '%v' and '%v'",
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
eval_array_of_expressions :: proc(
	e: ^Evaluator,
	expressions: [dynamic]ma.Node,
	current_env: ^Environment,
) -> (
	[dynamic]Object_Base,
	bool,
) {
	args := make([dynamic]Object_Base, 0, len(expressions), e._pool)

	for expr in expressions {
		evaluated, ok := eval(e, expr, current_env)
		append(&args, to_object_base(evaluated))
		if !ok do return args, false
	}

	return args, true
}

@(private = "file")
extend_function_env :: proc(
	e: ^Evaluator,
	fn: ^Obj_Function,
	args: [dynamic]Object_Base,
) -> ^Environment {
	env := new_enclosed_environment(fn.env, len(fn.parameters), e._pool)

	for param, idx in fn.parameters {
		env->set(param.value, args[idx])
	}

	return env
}

@(private = "file")
apply_function :: proc(
	e: ^Evaluator,
	fn: Object_Base,
	args: [dynamic]Object_Base,
) -> (
	Object_Base,
	bool,
) {
	function, ok := fn.(^Obj_Function)
	if !ok do return new_error(e, "not a function: '%v'", obj_type(fn)), false

	if len(function.parameters) != len(args) {
		return new_error(
				e,
				"number of passed arguments does not match the number of needed parameters, need='%d', got='%d'",
				len(function.parameters),
				len(args),
			),
			false

	}

	extended_env := extend_function_env(e, function, args)
	evaluated, success := eval(e, function.body, extended_env)
	return to_object_base(evaluated), success
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

		current_env->set(st.clone(data.name, e._pool), to_object_base(val))
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
		fn := new(Obj_Function, e._pool)

		fn.parameters = make([dynamic]ma.Node_Identifier, 0, cap(data.parameters), e._pool)
		ma.ast_copy_multiple(&data.parameters, &fn.parameters, e._pool)

		fn.body = make(ma.Node_Block_Expression, 0, cap(data.body), e._pool)
		ma.ast_copy_multiple(&data.body, &fn.body, e._pool)

		fn.env = current_env

		return Object_Base(fn), true

	case ma.Node_Call_Expression:
		function, ok := eval(e, data.function^, current_env)
		if !ok do return function, false

		args, args_success := eval_array_of_expressions(e, data.arguments, current_env)
		if !args_success do return args[0], false

		return apply_function(e, to_object_base(function), args)

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
