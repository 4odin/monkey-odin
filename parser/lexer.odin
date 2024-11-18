package monkey_parser

Lexer :: struct {
	input:      ^string,
	pos:        int,
	read_pos:   int,
	ch:         u8,

	// functions
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

	return token_create(TokenType.IDENT, l.input, start, l.pos - start)
}

@(private = "file")
create_number :: proc(l: ^Lexer) -> Token {
	start := l.pos

	for is_digit(l.ch) do read_char(l)

	return token_create(TokenType.INT, l.input, start, l.pos - start)
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
			tok = token_create(TokenType.EQ, l.input, start, 2)
		} else do tok = create_single_letter_tok(l, TokenType.ASSIGN)

	case '+':
		tok = create_single_letter_tok(l, TokenType.PLUS)

	case '-':
		tok = create_single_letter_tok(l, TokenType.MINUS)

	case '!':
		if peek_char(l) == '=' {
			start := l.pos
			read_char(l)
			tok = token_create(TokenType.NOT_EQ, l.input, start, 2)
		} else do tok = create_single_letter_tok(l, TokenType.BANG)

	case '/':
		tok = create_single_letter_tok(l, TokenType.SLASH)

	case '*':
		tok = create_single_letter_tok(l, TokenType.ASTERISK)

	case '<':
		tok = create_single_letter_tok(l, TokenType.LT)

	case '>':
		tok = create_single_letter_tok(l, TokenType.GT)

	case ';':
		tok = create_single_letter_tok(l, TokenType.SEMICOLON)

	case ',':
		tok = create_single_letter_tok(l, TokenType.COMMA)

	case '(':
		tok = create_single_letter_tok(l, TokenType.LPAREN)

	case ')':
		tok = create_single_letter_tok(l, TokenType.RPAREN)

	case '{':
		tok = create_single_letter_tok(l, TokenType.LBRACE)

	case '}':
		tok = create_single_letter_tok(l, TokenType.RBRACE)

	case 0:
		tok.length = 0
		tok.type = TokenType.EOF

	case:
		if is_letter(l.ch) {
			tok = create_identifier(l)
			update_type_if_keyword(&tok)

			return tok
		} else if is_digit(l.ch) do return create_number(l)

		tok = create_single_letter_tok(l, TokenType.ILLIGAL)
	}

	read_char(l)

	return tok
}


lexer_new :: proc(input: ^string) -> ^Lexer {
	l := new(Lexer)
	l.input = input

	l.next_token = next_token

	read_char(l)

	return l
}
