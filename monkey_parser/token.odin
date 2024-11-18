package monkey_parser

TokenType :: enum {
	ILLIGAL,
	EOF,

	// Identifier + literals
	IDENT,
	INT,

	// Operators
	ASSIGN,
	PLUS,
	MINUS,
	BANG,
	ASTERISK,
	SLASH,
	LT,
	GT,
	EQ,
	NOT_EQ,

	// Delimiters
	COMMA,
	SEMICOLON,

	// Groups
	LPAREN,
	RPAREN,
	LBRACE,
	RBRACE,

	// Keywords
	FUNCTION,
	LET,
	TRUE,
	FALSE,
	IF,
	ELSE,
	RETURN,
}

Token :: struct {
	type:   TokenType,
	input:  ^string,
	start:  int,
	end:    int,
	length: int,
}

token_create :: proc(type: TokenType, input: ^string, start: int, length: int) -> Token {
	return Token{type, input, start, start + length, length}
}

@(private = "package")
update_type_if_keyword :: proc(tok: ^Token) {
	switch (tok.input[tok.start:tok.end]) {
	case "fn":
		tok.type = TokenType.FUNCTION

	case "let":
		tok.type = TokenType.LET

	case "true":
		tok.type = TokenType.TRUE

	case "false":
		tok.type = TokenType.FALSE

	case "if":
		tok.type = TokenType.IF

	case "else":
		tok.type = TokenType.ELSE

	case "return":
		tok.type = TokenType.RETURN
	}
}