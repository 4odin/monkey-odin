package monkey_evaluator

import mp "../parser"


@(private = "file")
eval_node :: proc(node: mp.Node) -> Object {
	#partial switch data in node {
	case int:
		return data
	}

	return Null{}
}
