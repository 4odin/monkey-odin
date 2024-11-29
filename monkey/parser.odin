package monkey_odin

import "core:fmt"
import "core:mem"
import "core:strconv"

import st "core:strings"

import "../utils"

@(private = "file")
Dap_Item :: union {
	Node_Program,
	Node_Block_Expression,
	[dynamic]Node,
	[dynamic]Node_Identifier,
	Node_Hash_Table_Literal,
}

Parser :: struct {
	l:             Lexer,
	cur_token:     Token,
	peek_token:    Token,
	errors:        [dynamic]string,

	// methods
	config:        proc(
		p: ^Parser,
		pool_reserved_block_size: uint = 1 * mem.Megabyte,
		dyn_arr_reserved: uint = 10,
	) -> mem.Allocator_Error,
	parse:         proc(p: ^Parser, input: string) -> Node_Program,
	clear_errors:  proc(p: ^Parser),

	// Managed
	using managed: utils.Mem_Manager(Dap_Item),
}

parser :: proc() -> Parser {
	return {
		l = lexer(),
		config = parser_config,
		parse = parse_program,
		clear_errors = parser_clear_errors,
		managed = utils.mem_manager(Dap_Item, proc(dyn_pool: [dynamic]Dap_Item) {
			for element in dyn_pool {
				switch kind in element {
				case Node_Program:
					delete(kind)

				case Node_Block_Expression:
					delete(kind)

				case [dynamic]Node_Identifier:
					delete(kind)

				case [dynamic]Node:
					delete(kind)

				case Node_Hash_Table_Literal:
					delete(kind)
				}
			}}),
	}
}

// ***************************************************************************************
// PRIVATE TYPES AND PROCEDURES
// ***************************************************************************************

@(private = "file")
Precedence :: enum {
	Lowest,
	Equals,
	Less_Greater,
	Sum,
	Product,
	Prefix,
	Call,
	Index,
}

@(private = "file")
precedences := #partial [Token_Type]Precedence {
	.Plus         = .Sum,
	.Minus        = .Sum,
	.Asterisk     = .Product,
	.Slash        = .Product,
	.Less_Than    = .Less_Greater,
	.Greater_Than = .Less_Greater,
	.Equal        = .Equals,
	.Not_Equal    = .Equals,
	.Left_Paren   = .Call,
	.Left_Bracket = .Index,
}

@(private = "file")
peek_precedence :: proc(p: ^Parser) -> Precedence {
	return precedences[p.peek_token.type]
}

@(private = "file")
cur_precedence :: proc(p: ^Parser) -> Precedence {
	return precedences[p.cur_token.type]
}

@(private = "file")
Prefix_Parse_Fn :: #type proc(p: ^Parser) -> Node

@(private = "file")
Infix_Parse_Fn :: #type proc(p: ^Parser, left: Node) -> Node

@(private = "file")
prefix_parse_fns := #partial [Token_Type]Prefix_Parse_Fn {
	.Identifier   = parse_identifier,
	.Int          = parse_integer_literal,
	.String       = parse_string_literal,
	.Minus        = parse_prefix_expression,
	.Bang         = parse_prefix_expression,
	.Left_Paren   = parse_grouped_expression,
	.Left_Bracket = parse_array_literal,
	.Left_Brace   = parse_hash_table_literal,
	.Function     = parse_function_literal,
	.True         = parse_boolean_literal,
	.False        = parse_boolean_literal,
	.If           = parse_if_expression,
}

@(private = "file")
infix_parse_fns := #partial [Token_Type]Infix_Parse_Fn {
	.Plus         = parse_infix_expression,
	.Minus        = parse_infix_expression,
	.Asterisk     = parse_infix_expression,
	.Slash        = parse_infix_expression,
	.Less_Than    = parse_infix_expression,
	.Greater_Than = parse_infix_expression,
	.Equal        = parse_infix_expression,
	.Not_Equal    = parse_infix_expression,
	.Left_Paren   = parse_call_expression,
	.Left_Bracket = parse_index_expression,
}

@(private = "file")
peek_error :: proc(p: ^Parser, t: Token_Type) {
	msg := st.builder_make(p._pool)

	fmt.sbprintf(&msg, "expected next token to be '%s', got '%s' instead", t, p.peek_token.type)
	append(&p.errors, st.to_string(msg))
}

@(private = "file")
current_token_is :: proc(p: ^Parser, t: Token_Type) -> bool {
	return p.cur_token.type == t
}

@(private = "file")
peek_token_is :: proc(p: ^Parser, t: Token_Type) -> bool {
	return p.peek_token.type == t
}

@(private = "file")
expect_peek :: proc(p: ^Parser, t: Token_Type) -> bool {
	if peek_token_is(p, t) {
		next_token(p)
		return true
	}

	peek_error(p, t)
	return false
}

@(private = "file")
parser_config :: proc(
	p: ^Parser,
	pool_reserved_block_size: uint = 1 * mem.Megabyte,
	dyn_arr_reserved: uint = 10,
) -> mem.Allocator_Error {
	err := p->mem_config(pool_reserved_block_size, dyn_arr_reserved)

	if err == .None do p.errors.allocator = p._pool

	return err
}

@(private = "file")
parser_clear_errors :: proc(p: ^Parser) {
	clear(&p.errors)
}

@(private = "file")
next_token :: proc(p: ^Parser) {
	p.cur_token = p.peek_token
	p.peek_token = p.l->next_token()
}

@(private = "file")
parse_identifier :: proc(p: ^Parser) -> Node {
	return Node_Identifier{string(p.cur_token.text_slice)}
}

@(private = "file")
parse_string_literal :: proc(p: ^Parser) -> Node {
	return string(p.cur_token.text_slice)
}

@(private = "file")
parse_integer_literal :: proc(p: ^Parser) -> Node {
	value, ok := strconv.parse_int(string(p.cur_token.text_slice))
	if !ok {
		msg := st.builder_make(p._pool)

		fmt.sbprintf(&msg, "could not parse %s as integer", p.l.input)
		append(&p.errors, st.to_string(msg))
		return nil
	}

	return value
}

@(private = "file")
parse_boolean_literal :: proc(p: ^Parser) -> Node {
	return current_token_is(p, .True)
}

@(private = "file")
parse_array_literal :: proc(p: ^Parser) -> Node {
	result, ok := parse_expression_list(p, .Right_Bracket)
	if !ok do return nil

	return Node_Array_Literal(result)
}

@(private = "file")
parse_hash_table_literal :: proc(p: ^Parser) -> Node {
	result := utils.register_in_pool(&p.managed, Node_Hash_Table_Literal)

	for !peek_token_is(p, .Right_Brace) {
		next_token(p)

		key_expr := parse_expression(p, .Lowest)

		key, ok := key_expr.(string)
		if !ok {
			msg := st.builder_make(p._pool)

			fmt.sbprintf(&msg, "expected key to be 'string', got '%s' instead", ast_type(key))
			append(&p.errors, st.to_string(msg))

			return nil
		}

		if !expect_peek(p, .Colon) do return nil

		next_token(p)

		value := parse_expression(p, .Lowest)

		result[key] = value

		if !peek_token_is(p, .Right_Brace) && !expect_peek(p, .Comma) do return nil
	}

	if !expect_peek(p, .Right_Brace) do return nil

	return result^
}

@(private = "file")
parse_let_statement :: proc(p: ^Parser) -> Node {
	if !expect_peek(p, .Identifier) do return nil

	name := string(p.cur_token.text_slice)

	if !expect_peek(p, .Assign) do return nil

	next_token(p)

	value := parse_expression(p, .Lowest)
	if value == nil do return nil

	if peek_token_is(p, .Semicolon) do next_token(p)

	return Node_Let_Statement{name = name, value = new_clone(value, p._pool)}
}

@(private = "file")
parse_return_statement :: proc(p: ^Parser) -> Node {
	next_token(p)

	ret_val := parse_expression(p, .Lowest)
	if ret_val == nil do return nil

	if peek_token_is(p, .Semicolon) do next_token(p)

	return Node_Return_Statement{ret_val = new_clone(ret_val, p._pool)}
}

@(private = "file")
parse_prefix_expression :: proc(p: ^Parser) -> Node {
	op := string(p.cur_token.text_slice)

	next_token(p)

	operand := parse_expression(p, .Prefix)
	if operand == nil do return nil

	return Node_Prefix_Expression{op = op, operand = new_clone(operand, p._pool)}
}

@(private = "file")
parse_infix_expression :: proc(p: ^Parser, left: Node) -> Node {
	op := string(p.cur_token.text_slice)

	prec := cur_precedence(p)
	next_token(p)
	right := parse_expression(p, prec)
	if right == nil do return nil

	return Node_Infix_Expression {
		op = op,
		left = new_clone(left, p._pool),
		right = new_clone(right, p._pool),
	}
}

@(private = "file")
parse_grouped_expression :: proc(p: ^Parser) -> Node {
	next_token(p)
	expr := parse_expression(p, .Lowest)

	if !expect_peek(p, .Right_Paren) do return nil
	return expr
}

@(private = "file")
parse_block_statement :: proc(p: ^Parser) -> Node_Block_Expression {
	block := utils.register_in_pool(&p.managed, Node_Block_Expression)

	next_token(p)

	for !current_token_is(p, .Right_Brace) && !current_token_is(p, .EOF) {
		stmt := parse_statement(p)
		if stmt != nil do append(block, stmt)

		next_token(p)
	}

	return block^
}

@(private = "file")
parse_if_expression :: proc(p: ^Parser) -> Node {
	next_token(p)

	condition := parse_expression(p, .Lowest)
	if condition == nil do return nil

	if !expect_peek(p, .Left_Brace) do return nil

	consequence := parse_block_statement(p)

	alternative: Node_Block_Expression = nil

	if peek_token_is(p, .Else) {
		next_token(p)

		if !expect_peek(p, .Left_Brace) do return nil

		alternative = parse_block_statement(p)
	}

	return Node_If_Expression {
		condition = new_clone(condition, p._pool),
		consequence = consequence,
		alternative = alternative,
	}
}

@(private = "file")
parse_function_parameters :: proc(p: ^Parser) -> [dynamic]Node_Identifier {
	identifiers := utils.register_in_pool(&p.managed, [dynamic]Node_Identifier)

	if peek_token_is(p, .Right_Paren) {
		next_token(p)
		return identifiers^
	}

	next_token(p)

	append(identifiers, Node_Identifier{value = string(p.cur_token.text_slice)})

	for peek_token_is(p, .Comma) {
		next_token(p)
		next_token(p)
		append(identifiers, Node_Identifier{value = string(p.cur_token.text_slice)})
	}

	if !expect_peek(p, .Right_Paren) do return nil

	return identifiers^
}

@(private = "file")
parse_function_literal :: proc(p: ^Parser) -> Node {
	if !expect_peek(p, .Left_Paren) do return nil

	parameters := parse_function_parameters(p)

	if !expect_peek(p, .Left_Brace) do return nil

	body := parse_block_statement(p)

	return Node_Function_Literal{body = body, parameters = parameters}
}

@(private = "file")
parse_expression_list :: proc(p: ^Parser, end: Token_Type) -> ([dynamic]Node, bool) {
	args := utils.register_in_pool(&p.managed, [dynamic]Node)

	if peek_token_is(p, end) {
		next_token(p)
		return args^, true
	}

	next_token(p)
	arg := parse_expression(p, .Lowest)

	append(args, arg)

	for peek_token_is(p, .Comma) {
		next_token(p)
		next_token(p)

		arg1 := parse_expression(p, .Lowest)
		if arg1 == nil do return nil, false

		append(args, arg1)
	}

	if !expect_peek(p, end) do return nil, false

	return args^, true
}

@(private = "file")
parse_call_expression :: proc(p: ^Parser, function: Node) -> Node {
	arguments, ok := parse_expression_list(p, .Right_Paren)
	if !ok do return nil

	return Node_Call_Expression{function = new_clone(function, p._pool), arguments = arguments}
}

@(private = "file")
parse_index_expression :: proc(p: ^Parser, operand: Node) -> Node {
	next_token(p)
	index := parse_expression(p, .Lowest)

	if !expect_peek(p, .Right_Bracket) do return nil

	return Node_Index_Expression {
		operand = new_clone(operand, p._pool),
		index = new_clone(index, p._pool),
	}
}

@(private = "file")
no_prefix_parse_fn_error :: proc(p: ^Parser, t: Token_Type) {
	msg := st.builder_make(p._pool)

	fmt.sbprintf(&msg, "unexpected token '%v'", t)
	append(&p.errors, st.to_string(msg))
}

@(private = "file")
parse_expression :: proc(p: ^Parser, prec: Precedence) -> Node {
	prefix := prefix_parse_fns[p.cur_token.type]

	if prefix == nil {
		no_prefix_parse_fn_error(p, p.cur_token.type)
		return nil
	}

	left_expr := prefix(p)

	for !peek_token_is(p, .Semicolon) && prec < peek_precedence(p) {
		infix := infix_parse_fns[p.peek_token.type]
		if infix == nil do return left_expr

		next_token(p)

		left_expr = infix(p, left_expr)
	}

	return left_expr
}

@(private = "file")
parse_expression_statement :: proc(p: ^Parser) -> Node {
	expr := parse_expression(p, .Lowest)

	if peek_token_is(p, .Semicolon) do next_token(p)

	return expr
}

@(private = "file")
parse_statement :: proc(p: ^Parser) -> Node {
	#partial switch p.cur_token.type {
	case .Let:
		return parse_let_statement(p)

	case .Return:
		return parse_return_statement(p)
	}

	return parse_expression_statement(p)
}

@(private = "file")
parse_program :: proc(p: ^Parser, input: string) -> Node_Program {
	p.l->init(input)
	next_token(p)
	next_token(p)

	program := utils.register_in_pool(&p.managed, Node_Program)

	for p.cur_token.type != .EOF {
		if stmt := parse_statement(p); stmt != nil {
			append(program, stmt)
		}
		next_token(p)
	}

	return program^
}
