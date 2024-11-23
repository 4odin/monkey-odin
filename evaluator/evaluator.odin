package monkey_evaluator

import ma "../ast"

@(private = "file")
NULL :: Null{}

Evaluator :: struct {
	// methods
	eval: proc(e: ^Evaluator, node: ma.Node_Program) -> Object_Base,
}

evaluator :: proc() -> Evaluator {
	return {eval = eval_program_statements}
}

@(private = "file")
eval_program_statements :: proc(e: ^Evaluator, program: ma.Node_Program) -> Object_Base {
	result: Object

	for stmt in program {
		result = eval(e, stmt)

		if ret_val, ok := result.(Object_Return); ok do return to_object_base(ret_val)
	}

	return to_object_base(result)
}

@(private = "file")
eval_block_statements :: proc(e: ^Evaluator, program: ma.Node_Block_Expression) -> Object {
	result: Object

	for stmt in program {
		result = eval(e, stmt)

		if obj_is_return(result) do return result
	}

	return result
}

@(private = "file")
eval_bang_operator_expression :: proc(e: ^Evaluator, operand: Object_Base) -> Object_Base {
	#partial switch data in operand {
	case bool:
		return !data

	case Null:
		return true
	}

	return false
}

@(private = "file")
eval_minus_operator_expression :: proc(e: ^Evaluator, operand: Object_Base) -> Object_Base {
	value, ok := operand.(int)
	if !ok do return NULL

	return -value
}

@(private = "file")
eval_prefix_expression :: proc(e: ^Evaluator, op: string, operand: Object_Base) -> Object_Base {
	switch op {
	case "!":
		return eval_bang_operator_expression(e, operand)

	case "-":
		return eval_minus_operator_expression(e, operand)
	}

	return NULL
}

@(private = "file")
eval_integer_infix_expression :: proc(
	e: ^Evaluator,
	op: string,
	left: int,
	right: int,
) -> Object_Base {
	switch op {
	case "+":
		return left + right

	case "-":
		return left - right

	case "*":
		return left * right

	case "/":
		return left / right

	case "<":
		return left < right

	case ">":
		return left > right

	case "==":
		return left == right

	case "!=":
		return left != right
	}

	return NULL
}

@(private = "file")
eval_infix_expression :: proc(
	e: ^Evaluator,
	op: string,
	left: Object_Base,
	right: Object_Base,
) -> Object_Base {
	if ma.ast_type(left) == int && ma.ast_type(right) == int do return eval_integer_infix_expression(e, op, left.(int), right.(int))

	switch op {
	case "==":
		return left == right

	case "!=":
		return left != right
	}

	return NULL
}

@(private = "file")
is_truthy :: proc(obj: Object_Base) -> bool {
	#partial switch data in obj {
	case Null:
		return false

	case bool:
		return data
	}

	return true
}

@(private = "file")
eval_if_expression :: proc(e: ^Evaluator, node: ma.Node_If_Expression) -> Object {
	condition := to_object_base(eval(e, node.condition^))

	if is_truthy(condition) {
		return eval(e, node.consequence)
	} else if node.alternative != nil {
		return eval(e, node.alternative)
	}

	return Object_Base(NULL)
}

@(private = "file")
eval :: proc(e: ^Evaluator, node: ma.Node) -> Object {
	#partial switch data in node {

	// statements
	case ma.Node_Return_Statement:
		val := eval(e, data.ret_val^)
		return Object_Return(to_object_base(val))

	// expressions
	case ma.Node_Prefix_Expression:
		operand := eval(e, data.operand^)
		return eval_prefix_expression(e, data.op, to_object_base(operand))

	case ma.Node_Infix_Expression:
		left := eval(e, data.left^)
		right := eval(e, data.right^)
		return eval_infix_expression(e, data.op, to_object_base(left), to_object_base(right))

	case ma.Node_Block_Expression:
		return eval_block_statements(e, data)

	case ma.Node_If_Expression:
		return eval_if_expression(e, data)

	// literals
	case int:
		return Object_Base(data)

	case bool:
		return Object_Base(data)

	case string:
		return Object_Base(data)
	}

	return nil
}
