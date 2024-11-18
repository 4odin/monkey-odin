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
		{mp.TokenType.LET, "let"},
		{mp.TokenType.IDENT, "five"},
		{mp.TokenType.ASSIGN, "="},
		{mp.TokenType.INT, "5"},
		{mp.TokenType.SEMICOLON, ";"},

		//
		{mp.TokenType.LET, "let"},
		{mp.TokenType.IDENT, "ten"},
		{mp.TokenType.ASSIGN, "="},
		{mp.TokenType.INT, "10"},
		{mp.TokenType.SEMICOLON, ";"},

		//
		{mp.TokenType.LET, "let"},
		{mp.TokenType.IDENT, "add"},
		{mp.TokenType.ASSIGN, "="},
		{mp.TokenType.FUNCTION, "fn"},
		{mp.TokenType.LPAREN, "("},
		{mp.TokenType.IDENT, "x"},
		{mp.TokenType.COMMA, ","},
		{mp.TokenType.IDENT, "y"},
		{mp.TokenType.RPAREN, ")"},
		{mp.TokenType.LBRACE, "{"},
		{mp.TokenType.IDENT, "x"},
		{mp.TokenType.PLUS, "+"},
		{mp.TokenType.IDENT, "y"},
		{mp.TokenType.SEMICOLON, ";"},
		{mp.TokenType.RBRACE, "}"},
		{mp.TokenType.SEMICOLON, ";"},

		//
		{mp.TokenType.LET, "let"},
		{mp.TokenType.IDENT, "result"},
		{mp.TokenType.ASSIGN, "="},
		{mp.TokenType.IDENT, "add"},
		{mp.TokenType.LPAREN, "("},
		{mp.TokenType.IDENT, "five"},
		{mp.TokenType.COMMA, ","},
		{mp.TokenType.IDENT, "ten"},
		{mp.TokenType.RPAREN, ")"},
		{mp.TokenType.SEMICOLON, ";"},

		//
		{mp.TokenType.BANG, "!"},
		{mp.TokenType.MINUS, "-"},
		{mp.TokenType.SLASH, "/"},
		{mp.TokenType.ASTERISK, "*"},
		{mp.TokenType.INT, "5"},
		{mp.TokenType.SEMICOLON, ";"},

		//
		{mp.TokenType.INT, "5"},
		{mp.TokenType.LT, "<"},
		{mp.TokenType.INT, "10"},
		{mp.TokenType.GT, ">"},
		{mp.TokenType.INT, "5"},
		{mp.TokenType.SEMICOLON, ";"},

		//
		{mp.TokenType.IF, "if"},
		{mp.TokenType.INT, "5"},
		{mp.TokenType.LT, "<"},
		{mp.TokenType.INT, "10"},
		{mp.TokenType.LBRACE, "{"},

		//
		{mp.TokenType.RETURN, "return"},
		{mp.TokenType.TRUE, "true"},
		{mp.TokenType.SEMICOLON, ";"},

		//
		{mp.TokenType.RBRACE, "}"},
		{mp.TokenType.ELSE, "else"},
		{mp.TokenType.LBRACE, "{"},

		//
		{mp.TokenType.RETURN, "return"},
		{mp.TokenType.FALSE, "false"},
		{mp.TokenType.SEMICOLON, ";"},

		//
		{mp.TokenType.RBRACE, "}"},

		//
		{mp.TokenType.INT, "10"},
		{mp.TokenType.EQ, "=="},
		{mp.TokenType.INT, "10"},
		{mp.TokenType.SEMICOLON, ";"},

		//
		{mp.TokenType.INT, "10"},
		{mp.TokenType.NOT_EQ, "!="},
		{mp.TokenType.INT, "9"},
		{mp.TokenType.SEMICOLON, ";"},

		// end of file
		{mp.TokenType.EOF, ""},

		// end of test cases
	}

	l := mp.lexer_new(&input)
	defer free(l)

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
