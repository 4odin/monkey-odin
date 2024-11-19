package tests

import mp "../parser"

import "core:log"
import "core:testing"

@(test)
test_next_token :: proc(t: ^testing.T) {
	input := `let five = 5;
let ten = 10;

let add = fn(x, y) {
    x + y;
};

let result = add(five, ten);

!-/*5;
5 < 10 > 5;

if 5 < 10 {
    return true;
} else {
    return false;
}

10 == 10;
10 != 9;
    `


	tests := []struct {
		expected_type:    mp.TokenType,
		expected_literal: string,
	} {
		{.LET, "let"},
		{.IDENT, "five"},
		{.ASSIGN, "="},
		{.INT, "5"},
		{.SEMICOLON, ";"},

		//
		{.LET, "let"},
		{.IDENT, "ten"},
		{.ASSIGN, "="},
		{.INT, "10"},
		{.SEMICOLON, ";"},

		//
		{.LET, "let"},
		{.IDENT, "add"},
		{.ASSIGN, "="},
		{.FUNCTION, "fn"},
		{.LPAREN, "("},
		{.IDENT, "x"},
		{.COMMA, ","},
		{.IDENT, "y"},
		{.RPAREN, ")"},
		{.LBRACE, "{"},
		{.IDENT, "x"},
		{.PLUS, "+"},
		{.IDENT, "y"},
		{.SEMICOLON, ";"},
		{.RBRACE, "}"},
		{.SEMICOLON, ";"},

		//
		{.LET, "let"},
		{.IDENT, "result"},
		{.ASSIGN, "="},
		{.IDENT, "add"},
		{.LPAREN, "("},
		{.IDENT, "five"},
		{.COMMA, ","},
		{.IDENT, "ten"},
		{.RPAREN, ")"},
		{.SEMICOLON, ";"},

		//
		{.BANG, "!"},
		{.MINUS, "-"},
		{.SLASH, "/"},
		{.ASTERISK, "*"},
		{.INT, "5"},
		{.SEMICOLON, ";"},

		//
		{.INT, "5"},
		{.LT, "<"},
		{.INT, "10"},
		{.GT, ">"},
		{.INT, "5"},
		{.SEMICOLON, ";"},

		//
		{.IF, "if"},
		{.INT, "5"},
		{.LT, "<"},
		{.INT, "10"},
		{.LBRACE, "{"},

		//
		{.RETURN, "return"},
		{.TRUE, "true"},
		{.SEMICOLON, ";"},

		//
		{.RBRACE, "}"},
		{.ELSE, "else"},
		{.LBRACE, "{"},

		//
		{.RETURN, "return"},
		{.FALSE, "false"},
		{.SEMICOLON, ";"},

		//
		{.RBRACE, "}"},

		//
		{.INT, "10"},
		{.EQ, "=="},
		{.INT, "10"},
		{.SEMICOLON, ";"},

		//
		{.INT, "10"},
		{.NOT_EQ, "!="},
		{.INT, "9"},
		{.SEMICOLON, ";"},

		// end of file
		{.EOF, ""},

		// end of test cases
	}

	l := mp.lexer_create()
	l->init(&input)

	for test_case, i in tests {
		tok := l->next_token()

		if tok.type != test_case.expected_type {
			log.errorf(
				"tests[%d] - token wrong. expected='%v', got='%v'",
				i,
				test_case.expected_type,
				tok.type,
			)
			testing.fail(t)
		}

		if input[tok.start:tok.end] != test_case.expected_literal {
			log.errorf(
				"tests[%d] - literal wrong. expected='%s', got='%s'",
				i,
				test_case.expected_literal,
				input[tok.start:tok.end],
			)
			testing.fail(t)
		}
	}
}
