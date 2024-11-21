package monkey_parser

import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"
import "core:strconv"

import s "core:strings"

Parser :: struct {
	l:              Lexer,
	cur_token:      Token,
	peek_token:     Token,

	// storage fields
	errors:         [dynamic]string,
	_arena:         vmem.Arena,
	pool:           mem.Allocator,
	temp_allocator: mem.Allocator,

	// methods
	config:         proc(
		p: ^Parser,
		temp_allocator := context.temp_allocator,
	) -> mem.Allocator_Error,
	parse:          proc(p: ^Parser, input: string) -> Node_Program,
	free:           proc(p: ^Parser),
}

parser :: proc() -> Parser {
	return {l = lexer(), config = parser_config, parse = parse_program, free = parser_free}
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
}

@(private = "file")
precedences := [Token_Type]Precedence {
	.Illigal      = .Lowest,
	.EOF          = .Lowest,
	.Identifier   = .Lowest,
	.Int          = .Lowest,
	.Assign       = .Lowest,
	.Plus         = .Sum,
	.Minus        = .Sum,
	.Bang         = .Lowest,
	.Asterisk     = .Product,
	.Slash        = .Product,
	.Less_Than    = .Less_Greater,
	.Greater_Than = .Less_Greater,
	.Equal        = .Equals,
	.Not_Equal    = .Equals,
	.Comma        = .Lowest,
	.Semicolon    = .Lowest,
	.Left_Paren   = .Call,
	.Right_Paren  = .Lowest,
	.Left_Brace   = .Lowest,
	.Right_Brace  = .Lowest,
	.Function     = .Lowest,
	.Let          = .Lowest,
	.True         = .Lowest,
	.False        = .Lowest,
	.If           = .Lowest,
	.Else         = .Lowest,
	.Return       = .Lowest,
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
Prefix_Parse_Fn :: #type proc(p: ^Parser) -> Maybe(Monkey_Data)

@(private = "file")
Infix_Parse_Fn :: #type proc(p: ^Parser, left: ^Monkey_Data) -> Maybe(Monkey_Data)

@(private = "file")
prefix_parse_fns := [Token_Type]Prefix_Parse_Fn {
	.Illigal      = nil,
	.EOF          = nil,
	.Identifier   = parse_identifier,
	.Int          = parse_integer_literal,
	.Assign       = nil,
	.Plus         = nil,
	.Minus        = parse_prefix_expression,
	.Bang         = parse_prefix_expression,
	.Asterisk     = nil,
	.Slash        = nil,
	.Less_Than    = nil,
	.Greater_Than = nil,
	.Equal        = nil,
	.Not_Equal    = nil,
	.Comma        = nil,
	.Semicolon    = nil,
	.Left_Paren   = parse_grouped_expression,
	.Right_Paren  = nil,
	.Left_Brace   = nil,
	.Right_Brace  = nil,
	.Function     = parse_function_literal,
	.Let          = nil,
	.True         = parse_boolean_literal,
	.False        = parse_boolean_literal,
	.If           = parse_if_expression,
	.Else         = nil,
	.Return       = nil,
}

@(private = "file")
infix_parse_fns := [Token_Type]Infix_Parse_Fn {
	.Illigal      = nil,
	.EOF          = nil,
	.Identifier   = nil,
	.Int          = nil,
	.Assign       = nil,
	.Plus         = parse_infix_expression,
	.Minus        = parse_infix_expression,
	.Bang         = nil,
	.Asterisk     = parse_infix_expression,
	.Slash        = parse_infix_expression,
	.Less_Than    = parse_infix_expression,
	.Greater_Than = parse_infix_expression,
	.Equal        = parse_infix_expression,
	.Not_Equal    = parse_infix_expression,
	.Comma        = nil,
	.Semicolon    = nil,
	.Left_Paren   = parse_call_expression,
	.Right_Paren  = nil,
	.Left_Brace   = nil,
	.Right_Brace  = nil,
	.Function     = nil,
	.Let          = nil,
	.True         = nil,
	.False        = nil,
	.If           = nil,
	.Else         = nil,
	.Return       = nil,
}

@(private = "file")
peek_error :: proc(p: ^Parser, t: Token_Type) {
	msg := s.builder_make(p.temp_allocator)

	fmt.sbprintf(&msg, "expected next token to be '%s', got '%s' instead", t, p.peek_token.type)
	append(&p.errors, s.to_string(msg))
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
	temp_allocator := context.temp_allocator,
) -> mem.Allocator_Error {
	p.temp_allocator = temp_allocator

	err := vmem.arena_init_growing(&p._arena, 10 * mem.Megabyte)
	p.pool = vmem.arena_allocator(&p._arena)

	p.errors = make([dynamic]string, 0, 20, p.temp_allocator)

	return err
}

@(private = "file")
parser_free :: proc(p: ^Parser) {
	vmem.arena_destroy(&p._arena)
}

@(private = "file")
next_token :: proc(p: ^Parser) {
	p.cur_token = p.peek_token
	p.peek_token = p.l->next_token()
}

@(private = "file")
parse_identifier :: proc(p: ^Parser) -> Maybe(Monkey_Data) {
	return Node_Identifier{transmute(string)p.cur_token.input}
}

@(private = "file")
parse_integer_literal :: proc(p: ^Parser) -> Maybe(Monkey_Data) {
	value, ok := strconv.parse_int(transmute(string)p.cur_token.input)
	if !ok {
		msg := s.builder_make(p.temp_allocator)

		fmt.sbprintf(&msg, "could not parse %s as integer", p.l.input)
		append(&p.errors, s.to_string(msg))
		return nil
	}

	return value
}

parse_boolean_literal :: proc(p: ^Parser) -> Maybe(Monkey_Data) {
	return current_token_is(p, .True)
}

@(private = "file")
parse_let_statement :: proc(p: ^Parser) -> Maybe(Monkey_Data) {
	if !expect_peek(p, .Identifier) do return nil

	name := transmute(string)p.cur_token.input

	if !expect_peek(p, .Assign) do return nil

	next_token(p)

	value, ok := parse_expression(p, .Lowest).?
	if !ok do return nil

	if peek_token_is(p, .Semicolon) do next_token(p)

	return Node_Let_Statement{name = name, value = new_clone(value, p.pool)}
}

@(private = "file")
parse_return_statement :: proc(p: ^Parser) -> Maybe(Monkey_Data) {
	next_token(p)

	ret_val, ok := parse_expression(p, .Lowest).?
	if !ok do return nil

	if peek_token_is(p, .Semicolon) do next_token(p)

	return Node_Return_Statement{ret_val = new_clone(ret_val, p.pool)}
}

@(private = "file")
parse_prefix_expression :: proc(p: ^Parser) -> Maybe(Monkey_Data) {
	op := transmute(string)p.cur_token.input

	next_token(p)

	operand, ok := parse_expression(p, .Prefix).?
	if (!ok) do return nil

	return Node_Prefix_Expression{op = op, operand = new_clone(operand, p.pool)}
}

@(private = "file")
parse_infix_expression :: proc(p: ^Parser, left: ^Monkey_Data) -> Maybe(Monkey_Data) {
	op := transmute(string)p.cur_token.input

	prec := cur_precedence(p)
	next_token(p)
	right, ok := parse_expression(p, prec).?

	if !ok do return nil

	return Node_Infix_Expression {
		op = op,
		left = new_clone(left^, p.pool),
		right = new_clone(right, p.pool),
	}
}

@(private = "file")
parse_grouped_expression :: proc(p: ^Parser) -> Maybe(Monkey_Data) {
	next_token(p)
	expr := parse_expression(p, .Lowest)

	if !expect_peek(p, .Right_Paren) do return nil
	return expr
}

@(private = "file")
parse_block_statement :: proc(p: ^Parser) -> Node_Block_Expression {
	block := make(Node_Block_Expression, p.pool)

	next_token(p)

	for !current_token_is(p, .Right_Brace) && !current_token_is(p, .EOF) {
		stmt, ok := parse_statement(p).?
		if ok do append(&block, stmt)

		next_token(p)
	}

	return block
}

@(private = "file")
parse_if_expression :: proc(p: ^Parser) -> Maybe(Monkey_Data) {
	next_token(p)

	condition, ok := parse_expression(p, .Lowest).?
	if !ok do return nil

	if !expect_peek(p, .Left_Brace) do return nil

	consequence := parse_block_statement(p)

	alternative: Node_Block_Expression = nil

	if peek_token_is(p, .Else) {
		next_token(p)

		if !expect_peek(p, .Left_Brace) do return nil

		alternative = parse_block_statement(p)
	}

	return Node_If_Expression {
		condition = new_clone(condition, p.pool),
		consequence = consequence,
		alternative = alternative,
	}
}

parse_function_parameters :: proc(p: ^Parser) -> Maybe([dynamic]Node_Identifier) {
	identifiers := make([dynamic]Node_Identifier, p.pool)

	if peek_token_is(p, .Right_Paren) {
		next_token(p)
		return identifiers
	}

	next_token(p)

	append(&identifiers, Node_Identifier{value = transmute(string)p.cur_token.input})

	for peek_token_is(p, .Comma) {
		next_token(p)
		next_token(p)
		append(&identifiers, Node_Identifier{value = transmute(string)p.cur_token.input})
	}

	if !expect_peek(p, .Right_Paren) do return nil

	return identifiers
}

@(private = "file")
parse_function_literal :: proc(p: ^Parser) -> Maybe(Monkey_Data) {
	if !expect_peek(p, .Left_Paren) do return nil

	parameters, ok := parse_function_parameters(p).?
	if !ok do return nil

	if !expect_peek(p, .Left_Brace) do return nil

	body := parse_block_statement(p)

	return Node_Function_Literal{body = body, parameters = parameters}
}

@(private = "file")
parse_call_arguments :: proc(p: ^Parser) -> Maybe([dynamic]Monkey_Data) {
	args := make([dynamic]Monkey_Data, p.pool)

	if peek_token_is(p, .Right_Paren) {
		next_token(p)
		return args
	}

	next_token(p)
	arg, ok := parse_expression(p, .Lowest).?
	if !ok do return nil

	append(&args, arg)

	for peek_token_is(p, .Comma) {
		next_token(p)
		next_token(p)

		arg1, ok1 := parse_expression(p, .Lowest).?
		if !ok1 do return nil

		append(&args, arg1)
	}

	if !expect_peek(p, .Right_Paren) do return nil

	return args
}

@(private = "file")
parse_call_expression :: proc(p: ^Parser, left: ^Monkey_Data) -> Maybe(Monkey_Data) {
	arguments, ok := parse_call_arguments(p).?
	if !ok do return nil

	return Node_Call_Expression{function = new_clone(left^, p.pool), arguments = arguments}
}

@(private = "file")
no_prefix_parse_fn_error :: proc(p: ^Parser, t: Token_Type) {
	msg := s.builder_make(p.temp_allocator)

	fmt.sbprintf(&msg, "unexpected token '%v'", t)
	append(&p.errors, s.to_string(msg))
}

@(private = "file")
parse_expression :: proc(p: ^Parser, prec: Precedence) -> Maybe(Monkey_Data) {
	prefix := prefix_parse_fns[p.cur_token.type]

	if prefix == nil {
		no_prefix_parse_fn_error(p, p.cur_token.type)
		return nil
	}

	left_expr := prefix(p)

	for !peek_token_is(p, .Semicolon) && prec < peek_precedence(p) {
		left, ok := left_expr.?
		if !ok do return nil

		infix := infix_parse_fns[p.peek_token.type]
		if infix == nil do return left_expr

		next_token(p)

		left_expr = infix(p, &left)
	}

	return left_expr
}

@(private = "file")
parse_expression_statement :: proc(p: ^Parser) -> Maybe(Monkey_Data) {
	expr := parse_expression(p, .Lowest)

	if peek_token_is(p, .Semicolon) do next_token(p)

	return expr
}

@(private = "file")
parse_statement :: proc(p: ^Parser) -> Maybe(Monkey_Data) {
	#partial switch p.cur_token.type {
	case .Let:
		return parse_let_statement(p)

	case .Return:
		return parse_return_statement(p)

	case:
		return parse_expression_statement(p)
	}

	return nil
}

@(private = "file")
parse_program :: proc(p: ^Parser, input: string) -> Node_Program {
	p.l->init(input)
	next_token(p)
	next_token(p)

	program := make(Node_Program, p.temp_allocator)

	for p.cur_token.type != .EOF {
		if stmt, ok := parse_statement(p).?; ok {
			append(&program, stmt)
		}
		next_token(p)
	}

	return program
}
