package monkey_odin

import "core:fmt"
import "core:mem"
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

ast_is_expression_statement :: proc(ast: Node) -> bool {
	t := ast_type(ast)

	return t != Node_Program && t != Node_Let_Statement && t != Node_Return_Statement
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

	case Node_Array_Literal:
		fmt.sbprint(sb, "[")
		for stmt, i in data {
			ast_to_string(stmt, sb)
			if i < len(data) - 1 do fmt.sbprint(sb, ", ")
		}
		fmt.sbprint(sb, "]")

	case Node_Hash_Table_Literal:
		fmt.sbprint(sb, "{ ")
		i := 0
		for key, value in data {
			fmt.sbprintf(sb, "%s:", key)
			ast_to_string(value, sb)
			if i < len(data) - 1 do fmt.sbprint(sb, ", ")
			i += 1
		}
		fmt.sbprint(sb, " }")

	case Node_Index_Expression:
		fmt.sbprint(sb, "(")
		ast_to_string(data.operand, sb)
		fmt.sbprint(sb, "[")
		ast_to_string(data.index, sb)
		fmt.sbprint(sb, "]")
		fmt.sbprint(sb, ")")

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

@(private = "file")
_ast_copy_idents :: proc(
	ast: ^[dynamic]Node_Identifier,
	dst: ^[dynamic]Node_Identifier,
	allocator: mem.Allocator,
) {
	for stmt in ast {
		append(dst, Node_Identifier{value = st.clone(stmt.value, allocator)})
	}
}

@(private = "file")
_ast_copy_block :: proc(
	ast: ^Node_Block_Expression,
	dst: ^Node_Block_Expression,
	allocator: mem.Allocator,
) {
	for &stmt in ast {
		append(dst, ast_copy(&stmt, allocator))
	}
}

@(private = "file")
_ast_copy_nodes :: proc(ast: ^[dynamic]Node, dst: ^[dynamic]Node, allocator: mem.Allocator) {
	for &stmt in ast {
		append(dst, ast_copy(&stmt, allocator))
	}
}

@(private = "file")
_ast_copy_array :: proc(
	ast: ^Node_Array_Literal,
	dst: ^Node_Array_Literal,
	allocator: mem.Allocator,
) {
	for &stmt in ast {
		append(dst, ast_copy(&stmt, allocator))
	}
}

ast_copy_multiple :: proc {
	_ast_copy_idents,
	_ast_copy_block,
	_ast_copy_nodes,
	_ast_copy_array,
}

ast_copy :: proc(ast: ^Node, allocator: mem.Allocator) -> Node {
	#partial switch &data in ast {
	case int, bool:
		return data

	case string:
		return st.clone(data, allocator)

	case Node_Identifier:
		return Node_Identifier{value = st.clone(data.value, allocator)}

	case Node_Let_Statement:
		return Node_Let_Statement {
			name = st.clone(data.name, allocator),
			value = new_clone(ast_copy(data.value, allocator), allocator),
		}

	case Node_Return_Statement:
		return Node_Return_Statement {
			ret_val = new_clone(ast_copy(data.ret_val, allocator), allocator),
		}

	case Node_Prefix_Expression:
		return Node_Prefix_Expression {
			op = st.clone(data.op, allocator),
			operand = new_clone(ast_copy(data.operand, allocator), allocator),
		}

	case Node_Infix_Expression:
		return Node_Infix_Expression {
			op = st.clone(data.op, allocator),
			left = new_clone(ast_copy(data.left, allocator), allocator),
			right = new_clone(ast_copy(data.right, allocator), allocator),
		}

	case Node_If_Expression:
		consequence := make(Node_Block_Expression, 0, cap(data.consequence))
		ast_copy_multiple(&data.consequence, &consequence, allocator)

		alternative: Node_Block_Expression
		if data.alternative != nil {
			alternative = make(Node_Block_Expression, 0, cap(data.alternative))
			ast_copy_multiple(&data.alternative, &alternative, allocator)
		}

		return Node_If_Expression {
			condition = new_clone(ast_copy(data.condition, allocator), allocator),
			consequence = consequence,
			alternative = alternative,
		}

	case Node_Array_Literal:
		arr_copy := make(Node_Array_Literal, 0, cap(data))
		ast_copy_multiple(&data, &arr_copy, allocator)
		return arr_copy

	case Node_Hash_Table_Literal:
		hash_copy := make(Node_Hash_Table_Literal, len(data))
		for key, &value in data {
			hash_copy[st.clone(key, allocator)] = ast_copy(&value, allocator)
		}

		return hash_copy

	case Node_Function_Literal:
		parameters := make([dynamic]Node_Identifier, 0, cap(data.parameters), allocator)
		ast_copy_multiple(&data.parameters, &parameters, allocator)

		body := make(Node_Block_Expression, 0, cap(data.body), allocator)
		ast_copy_multiple(&data.body, &body, allocator)

		return Node_Function_Literal{parameters = parameters, body = body}

	case Node_Call_Expression:
		arguments := make([dynamic]Node, 0, cap(data.arguments), allocator)
		ast_copy_multiple(&data.arguments, &arguments, allocator)

		return Node_Call_Expression {
			function = new_clone(ast_copy(data.function, allocator), allocator),
			arguments = arguments,
		}

	case Node_Index_Expression:
		return Node_Index_Expression {
			operand = new_clone(ast_copy(data.operand, allocator), allocator),
			index = new_clone(ast_copy(data.index, allocator), allocator),
		}
	}

	unimplemented()
}
