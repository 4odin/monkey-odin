package monkey_parser

Token_Type :: enum {
	Illigal,
	EOF,

	// Identifier + literals
	Identifier,
	Int,

	// Operators
	Assign,
	Plus,
	Minus,
	Bang,
	Asterisk,
	Slash,
	Less_Than,
	Greater_Than,
	Equal,
	Not_Equal,

	// Delimiters
	Comma,
	Semicolon,

	// Groups
	Left_Paren,
	Right_Paren,
	Left_Brace,
	Right_Brace,

	// Keywords
	Function,
	Let,
	True,
	False,
	If,
	Else,
	Return,
}

Token :: struct {
	type:   Token_Type,
	input:  ^string,
	start:  int,
	end:    int,
	length: int,
}

token_create :: proc(type: Token_Type, input: ^string, start: int, length: int) -> Token {
	return {type, input, start, start + length, length}
}

@(private)
update_type_if_keyword :: proc(tok: ^Token) {
	switch (tok.input[tok.start:tok.end]) {
	case "fn":
		tok.type = .Function

	case "let":
		tok.type = .Let

	case "true":
		tok.type = .True

	case "false":
		tok.type = .False

	case "if":
		tok.type = .If

	case "else":
		tok.type = .Else

	case "return":
		tok.type = .Return
	}
}
