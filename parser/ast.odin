package monkey_parser

import "core:fmt"
import s "core:strings"

Monkey_Data :: union {
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
//    All the fields in any "node"s is a Monkey_Data Pointer which points to the actual
//    Monkey_data in a pool
// ***************************************************************************************

Node_Program :: struct {
	statements: [dynamic]Monkey_Data,
}

Node_Let_Statement :: struct {
	name:  string,
	value: ^Monkey_Data,
}

Node_Return_Statement :: struct {
	ret_val: ^Monkey_Data,
}

Node_Block_Expression :: distinct [dynamic]Monkey_Data

Node_Identifier :: struct {
	value: string,
}

Node_Prefix_Expression :: struct {
	op:      string,
	operand: ^Monkey_Data,
}

Node_Infix_Expression :: struct {
	op:    string,
	left:  ^Monkey_Data,
	right: ^Monkey_Data,
}

Node_If_Expression :: struct {
	condition:   ^Monkey_Data,
	consequence: Node_Block_Expression,
	alternative: Node_Block_Expression,
}

Node_Array_Literal :: distinct [dynamic]Monkey_Data

Node_Hash_Table_Literal :: distinct map[string]Monkey_Data

Node_Function_Literal :: struct {
	parameters: [dynamic]Node_Identifier,
	body:       Node_Block_Expression,
}

Node_Call_Expression :: struct {
	function:  Node_Function_Literal,
	arguments: [dynamic]Monkey_Data,
}

Node_Index_Expression :: struct {
	operand: ^Monkey_Data,
	index:   ^Monkey_Data,
}

ast_get_type :: proc(ast: ^Monkey_Data) -> typeid {
	switch _ in ast {
	case int:
		return int

	case bool:
		return bool

	case string:
		return string

	case Node_Program:
		return Node_Program

	case Node_Let_Statement:
		return Node_Let_Statement

	case Node_Return_Statement:
		return Node_Return_Statement

	case Node_Block_Expression:
		return Node_Block_Expression

	case Node_Identifier:
		return Node_Identifier

	case Node_Prefix_Expression:
		return Node_Prefix_Expression

	case Node_Infix_Expression:
		return Node_Infix_Expression

	case Node_If_Expression:
		return Node_If_Expression

	case Node_Array_Literal:
		return Node_Array_Literal

	case Node_Hash_Table_Literal:
		return Node_Hash_Table_Literal

	case Node_Function_Literal:
		return Node_Function_Literal

	case Node_Call_Expression:
		return Node_Call_Expression

	case Node_Index_Expression:
		return Node_Index_Expression
	}

	return nil
}

ast_to_string :: proc(ast: ^Monkey_Data, sb: ^s.Builder) {
	#partial switch data in ast {
	case bool, int, string:
		fmt.sbprint(sb, data)

	case Node_Identifier:
		fmt.sbprint(sb, data.value)

	case Node_Program:
		for &stmt, i in data.statements {
			ast_to_string(&stmt, sb)
			if i < len(data.statements) - 1 do fmt.sbprint(sb, "\n")
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
	}
}
