package monkey_parser

Lexer :: struct {
	input:      ^string,
	pos:        int,
	read_pos:   int,
	ch:         u8,

	// methods
	init:       proc(l: ^Lexer, input: ^string),
	next_token: proc(l: ^Lexer) -> Token,
}

@(private = "file")
is_letter :: proc(ch: u8) -> bool {
	return 'a' <= ch && ch <= 'z' || 'A' <= ch && ch <= 'Z' || ch == '_'
}

@(private = "file")
is_digit :: proc(ch: u8) -> bool {
	return '0' <= ch && ch <= '9'
}

@(private = "file")
create_single_letter_tok :: proc(l: ^Lexer, type: TokenType) -> Token {
	return token_create(type, l.input, l.pos, 1)
}

@(private = "file")
read_char :: proc(l: ^Lexer) {
	if l.read_pos >= len(l.input) {
		l.ch = 0
	} else {
		l.ch = l.input[l.read_pos]
	}

	l.pos = l.read_pos
	l.read_pos += 1
}

@(private = "file")
peek_char :: proc(l: ^Lexer) -> u8 {
	return l.read_pos >= len(l.input) ? 0 : l.input[l.read_pos]
}

@(private = "file")
skip_whitespace :: proc(l: ^Lexer) {
	for l.ch == ' ' || l.ch == '\t' || l.ch == '\n' || l.ch == '\r' do read_char(l)
}

@(private = "file")
create_identifier :: proc(l: ^Lexer) -> Token {
	start := l.pos

	for is_letter(l.ch) do read_char(l)

	return token_create(.IDENT, l.input, start, l.pos - start)
}

@(private = "file")
create_number :: proc(l: ^Lexer) -> Token {
	start := l.pos

	for is_digit(l.ch) do read_char(l)

	return token_create(.INT, l.input, start, l.pos - start)
}

@(private = "file")
init :: proc(l: ^Lexer, input: ^string) {
	l.ch = 0
	l.input = input
	l.pos = 0
	l.read_pos = 0

	read_char(l)
}

@(private = "file")
next_token :: proc(l: ^Lexer) -> Token {
	tok: Token

	skip_whitespace(l)

	switch l.ch {
	case '=':
		if peek_char(l) == '=' {
			start := l.pos
			read_char(l)
			tok = token_create(.EQ, l.input, start, 2)
		} else do tok = create_single_letter_tok(l, .ASSIGN)

	case '+':
		tok = create_single_letter_tok(l, .PLUS)

	case '-':
		tok = create_single_letter_tok(l, .MINUS)

	case '!':
		if peek_char(l) == '=' {
			start := l.pos
			read_char(l)
			tok = token_create(.NOT_EQ, l.input, start, 2)
		} else do tok = create_single_letter_tok(l, .BANG)

	case '/':
		tok = create_single_letter_tok(l, .SLASH)

	case '*':
		tok = create_single_letter_tok(l, .ASTERISK)

	case '<':
		tok = create_single_letter_tok(l, .LT)

	case '>':
		tok = create_single_letter_tok(l, .GT)

	case ';':
		tok = create_single_letter_tok(l, .SEMICOLON)

	case ',':
		tok = create_single_letter_tok(l, .COMMA)

	case '(':
		tok = create_single_letter_tok(l, .LPAREN)

	case ')':
		tok = create_single_letter_tok(l, .RPAREN)

	case '{':
		tok = create_single_letter_tok(l, .LBRACE)

	case '}':
		tok = create_single_letter_tok(l, .RBRACE)

	case 0:
		tok.length = 0
		tok.type = .EOF

	case:
		if is_letter(l.ch) {
			tok = create_identifier(l)
			update_type_if_keyword(&tok)

			return tok
		} else if is_digit(l.ch) do return create_number(l)

		tok = create_single_letter_tok(l, .ILLIGAL)
	}

	read_char(l)

	return tok
}

lexer_create :: proc() -> Lexer {
	return {next_token = next_token, init = init}
}
