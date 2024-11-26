package monkey_parser

Token_Type :: enum {
	Illigal,
	EOF,

	// Identifier + literals
	Identifier,
	Int,
	String,

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
	Colon,

	// Groups
	Left_Paren,
	Right_Paren,
	Left_Brace,
	Right_Brace,
	Left_Bracket,
	Right_Bracket,

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
	type:       Token_Type,
	text_slice: []u8,
}

token :: proc(type: Token_Type, input: []u8, start: int, length: int) -> Token {
	return {type, input[start:start + length]}
}

@(private)
update_type_if_keyword :: proc(tok: ^Token) {
	switch (string(tok.text_slice)) {
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
