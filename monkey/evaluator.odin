package monkey_odin

import "core:fmt"
import "core:mem"
import st "core:strings"

import "../utils"

@(private = "file")
Dap_Item :: union {
	Obj_Array,
	Obj_Hash_Table,
}

Evaluator :: struct {
	// data storage
	_env:          Environment,

	// methods
	eval:          proc(
		e: ^Evaluator,
		node: Node_Program,
		allocator := context.allocator,
	) -> (
		Object_Base,
		bool,
	),
	init:          proc(
		e: ^Evaluator,
		pool_reserved_block_size: uint = 1 * mem.Megabyte,
	) -> mem.Allocator_Error,
	free:          proc(e: ^Evaluator),

	// Managed
	using managed: utils.Mem_Manager(Dap_Item),
}

evaluator :: proc() -> Evaluator {
	return {
		eval = eval_program_statements,
		init = evaluator_init,
		free = evaluator_free,
		managed = utils.mem_manager(Dap_Item, proc(dyn_pool: [dynamic]Dap_Item) {
			for element in dyn_pool {
				switch kind in element {
				case Obj_Array:
					delete(kind)

				case Obj_Hash_Table:
					delete(kind)
				}
			}}),
	}
}

// ***************************************************************************************
// PRIVATE TYPES AND PROCEDURES
// ***************************************************************************************

@(private = "file")
evaluator_init :: proc(
	e: ^Evaluator,
	pool_reserved_block_size: uint = 1 * mem.Megabyte,
) -> mem.Allocator_Error {
	err := e->mem_init(pool_reserved_block_size)

	e._env = environment()

	return err
}

@(private = "file")
evaluator_pool_total_used :: proc(e: ^Evaluator) -> uint {
	return e._arena.total_reserved
}

@(private = "file")
evaluator_free :: proc(e: ^Evaluator) {
	e->mem_free()
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
	program: Node_Program,
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

	if str_obj, is_str := to_object_base(result).(string); is_str {
		result = Object_Base(st.clone(str_obj, allocator))
	}

	return to_object_base(result), true
}

@(private = "file")
eval_block_statements :: proc(
	e: ^Evaluator,
	program: Node_Block_Expression,
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

		if obj_is_return(result) do break
	}

	if str_obj, is_str := to_object_base(result).(string); is_str {
		result = Object_Base(st.clone(str_obj, e._pool))
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
	if ast_type(left) == int && ast_type(right) == int {
		return eval_integer_infix_expression(e, op, left.(int), right.(int))
	} else if ast_type(left) == string && ast_type(right) == string {
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
	node: Node_If_Expression,
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
	node: Node_Identifier,
	current_env: ^Environment,
) -> (
	Object_Base,
	bool,
) {
	if val, ok := current_env->get(node.value); ok do return val, true

	if builtin := find_builtin_fn(node.value); builtin != nil do return builtin, true

	return new_error(e, "identifier '%s' is not declared", node.value), false
}

@(private = "file")
eval_array_of_expressions_fixed :: proc(
	e: ^Evaluator,
	expressions: [dynamic]Node,
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
eval_array_of_expressions_registered :: proc(
	e: ^Evaluator,
	expressions: Node_Array_Literal,
	current_env: ^Environment,
) -> (
	^Obj_Array,
	bool,
) {
	args := utils.register_in_pool(&e.managed, Obj_Array)

	for expr in expressions {
		evaluated, ok := eval(e, expr, current_env)
		append(args, to_object_base(evaluated))
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
	#partial switch function in fn {
	case ^Obj_Function:
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

	case Obj_Builtin_Fn:
		return function(e, args)
	}

	return new_error(e, "not a function: '%v'", obj_type(fn)), false
}

@(private = "file")
eval_hash_table_literal :: proc(
	e: ^Evaluator,
	node: Node_Hash_Table_Literal,
	current_env: ^Environment,
) -> (
	Object,
	bool,
) {
	ht := utils.register_in_pool(&e.managed, Obj_Hash_Table)

	for key_node, value_node in node {
		key, key_is_valid := eval(e, key_node, current_env)
		if !key_is_valid do return key, false

		value, value_is_valid := eval(e, value_node, current_env)
		if !value_is_valid do return value, false

		ht[(to_object_base(key)).(string)] = to_object_base(value)
	}

	return Object_Base(ht), true
}

@(private = "file")
eval_array_index_expression :: proc(
	e: ^Evaluator,
	array: ^Obj_Array,
	index: int,
) -> (
	Object_Base,
	bool,
) {
	max := len(array) - 1

	if index < 0 || index > max {
		return new_error(e, "index out of boundary expect '0..%d', got='%d'", max, index), false
	}

	return array[index], true
}

@(private = "file")
eval_hash_table_index_expression :: proc(
	e: ^Evaluator,
	ht: ^Obj_Hash_Table,
	key: string,
) -> (
	Object_Base,
	bool,
) {
	value, ok := ht[key]

	if !ok {
		return new_error(e, "key '%s' does not exists", key), false
	}

	return value, true
}

@(private = "file")
eval_index_expression :: proc(
	e: ^Evaluator,
	operand: Object_Base,
	index: Object_Base,
) -> (
	Object_Base,
	bool,
) {
	if obj_type(operand) == ^Obj_Array && obj_type(index) == int {
		return eval_array_index_expression(e, operand.(^Obj_Array), index.(int))
	}

	if obj_type(operand) == ^Obj_Hash_Table && obj_type(index) == string {
		return eval_hash_table_index_expression(e, operand.(^Obj_Hash_Table), index.(string))
	}

	return new_error(e, "index operator does not support: '%v'", obj_type(operand)), false
}

@(private = "file")
find_builtin_fn :: proc(name: string) -> Obj_Builtin_Fn {
	switch name {
	case "len":
		return proc(e: ^Evaluator, args: [dynamic]Object_Base) -> (Object_Base, bool) {
				if len(args) != 1 {
					return new_error(
							e,
							"'len' function error: wrong number of arguments, wants='1', got='%d'",
							len(args),
						),
						false
				}

				#partial switch arg in args[0] {
				case string:
					return len(arg), true

				case ^Obj_Array:
					return len(arg), true
				}

				return new_error(
						e,
						"'len' function error: not supported for argument of type '%v'",
						obj_type(args[0]),
					),
					false
			}

	case "first":
		return proc(e: ^Evaluator, args: [dynamic]Object_Base) -> (Object_Base, bool) {
				if len(args) != 1 {
					return new_error(
							e,
							"'first' function error: wrong number of arguments, wants='1', got='%d'",
							len(args),
						),
						false
				}

				arr, ok := args[0].(^Obj_Array)
				if !ok {
					return new_error(
							e,
							"'first' function error: not supported for argument of type '%v'",
							obj_type(args[0]),
						),
						false
				}

				if len(arr) > 0 do return arr[0], true

				return NULL, true
			}

	case "last":
		return proc(e: ^Evaluator, args: [dynamic]Object_Base) -> (Object_Base, bool) {
				if len(args) != 1 {
					return new_error(
							e,
							"'last' function error: wrong number of arguments, wants='1', got='%d'",
							len(args),
						),
						false
				}

				arr, ok := args[0].(^Obj_Array)
				if !ok {
					return new_error(
							e,
							"'last' function error: not supported for argument of type '%v'",
							obj_type(args[0]),
						),
						false
				}

				if len(arr) > 0 do return arr[len(arr) - 1], true

				return NULL, true
			}

	case "rest":
		return proc(e: ^Evaluator, args: [dynamic]Object_Base) -> (Object_Base, bool) {
				if len(args) != 1 {
					return new_error(
							e,
							"'rest' function error: wrong number of arguments, wants='1', got='%d'",
							len(args),
						),
						false
				}

				arr, ok := args[0].(^Obj_Array)
				if !ok {
					return new_error(
							e,
							"'rest' function error: not supported for argument of type '%v'",
							obj_type(args[0]),
						),
						false
				}

				if len(arr) > 0 {
					new_arr := utils.register_in_pool(&e.managed, Obj_Array, len(arr) - 1)
					inject_at(new_arr, 0, ..arr[1:])

					return new_arr, true
				}

				return NULL, true
			}

	case "push":
		return proc(e: ^Evaluator, args: [dynamic]Object_Base) -> (Object_Base, bool) {
				if len(args) != 2 {
					return new_error(
							e,
							"'push' function error: wrong number of arguments, wants='2', got='%d'",
							len(args),
						),
						false
				}

				arr, ok := args[0].(^Obj_Array)
				if !ok {
					return new_error(
							e,
							"'push' function error: not supported for argument of type '%v'",
							obj_type(args[0]),
						),
						false
				}

				append(arr, args[1])

				return NULL, true
			}

	case "puts":
		return proc(e: ^Evaluator, args: [dynamic]Object_Base) -> (Object_Base, bool) {
				st.builder_reset(&e._sb)

				for arg in args {
					obj_inspect(arg, &e._sb)
					fmt.sbprintln(&e._sb)
				}

				fmt.print(st.to_string(e._sb))

				return NULL, true
			}
	}

	return nil
}

@(private = "file")
eval :: proc(e: ^Evaluator, node: Node, current_env: ^Environment) -> (Object, bool) {
	#partial switch &data in node {

	// statements
	case Node_Return_Statement:
		val, ok := eval(e, data.ret_val^, current_env)
		if !ok do return val, false
		return Object_Return(to_object_base(val)), true

	case Node_Let_Statement:
		val, ok := eval(e, data.value^, current_env)
		if !ok do return val, false

		_, ok = current_env->get(data.name)
		if ok do return Object_Base(new_error(e, "identifier '%s' is already declared", data.name)), false

		current_env->set(st.clone(data.name, e._pool), to_object_base(val))
		return Object_Base(NULL), true

	// expressions
	case Node_Identifier:
		return eval_identifier(e, data, current_env)

	case Node_Prefix_Expression:
		operand, ok := eval(e, data.operand^, current_env)
		if !ok do return operand, false
		return eval_prefix_expression(e, data.op, to_object_base(operand))

	case Node_Infix_Expression:
		left, ok := eval(e, data.left^, current_env)
		if !ok do return left, false
		right, ok2 := eval(e, data.right^, current_env)
		if !ok2 do return right, ok2
		return eval_infix_expression(e, data.op, to_object_base(left), to_object_base(right))

	case Node_Block_Expression:
		return eval_block_statements(e, data, current_env)

	case Node_If_Expression:
		return eval_if_expression(e, data, current_env)

	case Node_Function_Literal:
		fn := new(Obj_Function, e._pool)

		fn.parameters = make([dynamic]Node_Identifier, 0, cap(data.parameters), e._pool)
		ast_copy_multiple(&data.parameters, &fn.parameters, e._pool)

		fn.body = make(Node_Block_Expression, 0, cap(data.body), e._pool)
		ast_copy_multiple(&data.body, &fn.body, e._pool)

		fn.env = current_env

		return Object_Base(fn), true

	case Node_Call_Expression:
		function, ok := eval(e, data.function^, current_env)
		if !ok do return function, false

		args, args_success := eval_array_of_expressions_fixed(e, data.arguments, current_env)
		if !args_success do return args[0], false

		return apply_function(e, to_object_base(function), args)

	case Node_Index_Expression:
		operand, ok := eval(e, data.operand^, current_env)
		if !ok do return operand, false

		index, index_ok := eval(e, data.index^, current_env)
		if !index_ok do return index, false

		return eval_index_expression(e, to_object_base(operand), to_object_base(index))

	// literals
	case int:
		return Object_Base(data), true

	case bool:
		return Object_Base(data), true

	case string:
		return Object_Base(st.clone(data, e._pool)), true

	case Node_Array_Literal:
		elements, ok := eval_array_of_expressions_registered(e, data, current_env)
		if !ok do return Object_Base(elements), false

		return Object_Base(elements), true

	case Node_Hash_Table_Literal:
		return eval_hash_table_literal(e, data, current_env)
	}

	return Object_Base(new_error(e, "unrecognized Node of type '%v'", ast_type(node))), false
}
