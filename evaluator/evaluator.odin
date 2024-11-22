package monkey_evaluator

import ma "../ast"

@(private = "file")
NULL :: Null{}

Evaluator :: struct {
	// methods
	eval: proc(e: ^Evaluator, node: ma.Node) -> Object,
}

evaluator :: proc() -> Evaluator {
	return {eval = eval}
}

@(private = "file")
eval_statements :: proc(e: ^Evaluator, program: ma.Node_Program) -> Object {
	result: Object

	for stmt in program {
		result = eval(e, stmt)
	}

	return result
}

@(private = "file")
eval_bang_operator_expression :: proc(e: ^Evaluator, operand: Object) -> Object {
	#partial switch data in operand {
	case bool:
		return !data

	case Null:
		return true
	}

	return false
}

@(private = "file")
eval_minus_operator_expression :: proc(e: ^Evaluator, operand: Object) -> Object {
	value, ok := operand.(int)
	if !ok do return NULL

	return -value
}

@(private = "file")
eval_prefix_expression :: proc(e: ^Evaluator, op: string, operand: Object) -> Object {
	switch op {
	case "!":
		return eval_bang_operator_expression(e, operand)

	case "-":
		return eval_minus_operator_expression(e, operand)
	}

	return NULL
}

@(private = "file")
eval :: proc(e: ^Evaluator, node: ma.Node) -> Object {
	#partial switch data in node {
	case ma.Node_Program:
		return eval_statements(e, data)

	// expressions
	case ma.Node_Prefix_Expression:
		operand := eval(e, data.operand^)
		return eval_prefix_expression(e, data.op, operand)

	// literals
	case int:
		return data

	case bool:
		return data

	case string:
		return data
	}

	return nil
}
