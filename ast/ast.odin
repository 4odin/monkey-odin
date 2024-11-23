package monkey_ast

import "core:fmt"
import "core:reflect"
import st "core:strings"

Node :: union {
	// Basics
	int,
	bool,
	string,

	// Nodes
	Node_Program,
	Node_Let_Statement,
	Node_Return_Statement,
	Node_Block_Expression,
	Node_Identifier,
	Node_Prefix_Expression,
	Node_Infix_Expression,
	Node_If_Expression,
	Node_Array_Literal,
	Node_Hash_Table_Literal,
	Node_Function_Literal,
	Node_Call_Expression,
	Node_Index_Expression,
}

// ***************************************************************************************
// NODES
//    Nodes are only those which cannot be used as a valid general data type other as a
//    parser output and evaluation input
//    each of the fields in any of the "node"s is a Node Pointer which points to the actual
//    Node in 'a' pool
// ***************************************************************************************

Node_Program :: distinct [dynamic]Node

Node_Let_Statement :: struct {
	name:  string,
	value: ^Node,
}

Node_Return_Statement :: struct {
	ret_val: ^Node,
}

Node_Block_Expression :: distinct [dynamic]Node

Node_Identifier :: struct {
	value: string,
}

Node_Prefix_Expression :: struct {
	op:      string,
	operand: ^Node,
}

Node_Infix_Expression :: struct {
	op:    string,
	left:  ^Node,
	right: ^Node,
}

Node_If_Expression :: struct {
	condition:   ^Node,
	consequence: Node_Block_Expression,
	alternative: Node_Block_Expression,
}

Node_Array_Literal :: distinct [dynamic]Node

Node_Hash_Table_Literal :: distinct map[string]Node

Node_Function_Literal :: struct {
	parameters: [dynamic]Node_Identifier,
	body:       Node_Block_Expression,
}

Node_Call_Expression :: struct {
	function:  ^Node,
	arguments: [dynamic]Node,
}

Node_Index_Expression :: struct {
	operand: ^Node,
	index:   ^Node,
}

ast_type :: proc {
	_ast_type_val,
	_ast_type_ptr,
}

_ast_type_val :: reflect.union_variant_typeid

@(private = "file")
_ast_type_ptr :: proc(ast: ^Node) -> typeid {
	return reflect.union_variant_typeid(ast^)
}

ast_to_string :: proc {
	_ast_to_string_ptr,
	_ast_to_string_val,
}

@(private = "file")
_ast_to_string_val :: proc(ast: Node, sb: ^st.Builder) {
	ast := ast
	_ast_to_string_ptr(&ast, sb)
}

@(private = "file")
_ast_to_string_ptr :: proc(ast: ^Node, sb: ^st.Builder) {
	#partial switch data in ast {
	case bool, int, string:
		fmt.sbprint(sb, data)

	case Node_Identifier:
		fmt.sbprint(sb, data.value)

	case Node_Program:
		for stmt, i in data {
			ast_to_string(stmt, sb)
			if i < len(data) - 1 do fmt.sbprint(sb, "\n")
		}

	case Node_Let_Statement:
		fmt.sbprint(sb, "let", data.name)
		if data.value != nil {
			fmt.sbprint(sb, " = ")
			ast_to_string(data.value, sb)
		}
		fmt.sbprint(sb, ";")

	case Node_Return_Statement:
		fmt.sbprint(sb, "let")
		if data.ret_val != nil {
			fmt.sbprint(sb, " ")
			ast_to_string(data.ret_val, sb)
		}
		fmt.sbprint(sb, ";")

	case Node_Prefix_Expression:
		fmt.sbprintf(sb, "(%s", data.op)
		ast_to_string(data.operand, sb)
		fmt.sbprint(sb, ")")

	case Node_Infix_Expression:
		fmt.sbprint(sb, "(")
		ast_to_string(data.left, sb)
		fmt.sbprint(sb, data.op)
		ast_to_string(data.right, sb)
		fmt.sbprint(sb, ")")

	case Node_If_Expression:
		fmt.sbprint(sb, "if ")
		ast_to_string(data.condition, sb)
		fmt.sbprint(sb, " ")
		ast_to_string(data.consequence, sb)

		if data.alternative != nil {
			fmt.sbprint(sb, " else ")
			ast_to_string(data.alternative, sb)
		}

	case Node_Block_Expression:
		fmt.sbprint(sb, "{ ")
		for stmt, i in data {
			ast_to_string(stmt, sb)
			if i < len(data) - 1 do fmt.sbprint(sb, "; ")
		}
		fmt.sbprint(sb, " }")

	case Node_Function_Literal:
		fmt.sbprint(sb, "Fn (")
		for param, i in data.parameters {
			fmt.sbprint(sb, param.value)

			if i < len(data.parameters) - 1 do fmt.sbprint(sb, ", ")
		}
		fmt.sbprint(sb, ") ")

		ast_to_string(data.body, sb)

	case Node_Call_Expression:
		ast_to_string(data.function, sb)
		fmt.sbprint(sb, "(")
		for arg, i in data.arguments {
			ast_to_string(arg, sb)

			if i < len(data.arguments) - 1 do fmt.sbprint(sb, ", ")
		}
		fmt.sbprint(sb, ")")
	}
}
