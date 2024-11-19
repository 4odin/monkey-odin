package monkey_parser

import "core:fmt"
import "core:mem"

import s "core:strings"

Precedence :: enum {
	Lowest,
	Equals,
	Less_Greater,
	Sum,
	Product,
	Prefix,
	Call,
}

Parser :: struct {
	l:          Lexer,
	cur_token:  Token,
	peek_token: Token,

	// storage fields
	allocator:  mem.Allocator,
	errors:     [dynamic]string,

	// methods
	init:       proc(p: ^Parser, input: ^string, allocator := context.allocator),
}

Prefix_Parse_Fn :: #type proc(p: ^Parser) -> Maybe(Monkey_Data)
Infix_Parse_Fn :: #type proc(p: ^Parser, expr: Monkey_Data) -> Maybe(Monkey_Data)

@(private = "file")
prefix_parse_fns := [Token_Type]Prefix_Parse_Fn {
	.Illigal      = nil,
	.EOF          = nil,
	.Identifier   = parse_identifier,
	.Int          = nil,
	.Assign       = nil,
	.Plus         = nil,
	.Minus        = nil,
	.Bang         = nil,
	.Asterisk     = nil,
	.Slash        = nil,
	.Less_Than    = nil,
	.Greater_Than = nil,
	.Equal        = nil,
	.Not_Equal    = nil,
	.Comma        = nil,
	.Semicolon    = nil,
	.Left_Paren   = nil,
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
INFIX_PARSE_FUNCTIONS :: [Token_Type]Infix_Parse_Fn{}

@(private = "file")
peek_error :: proc(p: ^Parser, t: Token_Type) {
	msg := s.builder_make(p.allocator)

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
init :: proc(p: ^Parser, input: ^string, allocator := context.allocator) {
	p.l->init(input)
	p.allocator = allocator
	p.errors = make([dynamic]string, allocator)

	next_token(p)
	next_token(p)
}

@(private = "file")
next_token :: proc(p: ^Parser) {
	p.cur_token = p.peek_token
	p.peek_token = p.l->next_token()
}

@(private = "file")
parse_identifier :: proc(p: ^Parser) -> Maybe(Monkey_Data) {
	return Node_Identifier{p.cur_token.input[p.cur_token.start:p.cur_token.end]}
}

@(private = "file")
parse_let_statement :: proc(p: ^Parser) -> Maybe(Monkey_Data) {
	stmt := Node_Let_Statement{}

	if !expect_peek(p, .Identifier) do return nil

	stmt.name, _ = s.substring(p.l.input^, p.cur_token.start, p.cur_token.end)

	if !expect_peek(p, .Assign) do return nil

	// todo:: will be completed
	for !current_token_is(p, .Semicolon) do next_token(p)

	return stmt
}

@(private = "file")
parse_return_statement :: proc(p: ^Parser) -> Maybe(Monkey_Data) {
	stmt := Node_Return_Statement{}

	next_token(p)

	// todo:: will be completed
	for !current_token_is(p, .Semicolon) do next_token(p)

	return stmt
}

@(private = "file")
parse_expression :: proc(p: ^Parser, prec: Precedence) -> Maybe(Monkey_Data) {
	prefix := prefix_parse_fns[p.cur_token.type]

	if prefix == nil do return nil

	left_expr := prefix(p)

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

parser_create :: proc() -> Parser {
	return {l = lexer_create(), init = init}
}

parse_program :: proc(p: ^Parser) -> Node_Program {
	program := Node_Program{}
	program.statements = make([dynamic]Monkey_Data, p.allocator)

	for p.cur_token.type != .EOF {
		if stmt, ok := parse_statement(p).?; ok {
			append(&program.statements, stmt)
		}
		next_token(p)
	}

	return program
}
