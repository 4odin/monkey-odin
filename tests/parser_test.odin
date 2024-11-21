package tests

import mp "../parser"

import "core:log"
import s "core:strings"
import "core:testing"

Literal :: union {
	string,
	int,
	bool,
}

parser_has_error :: proc(p: ^mp.Parser) -> bool {
	if len(p.errors) == 0 do return false

	log.errorf("parser has %d errors", len(p.errors))
	for msg, _ in p.errors {
		log.errorf("parser error: %q", msg)
	}

	return true
}

stmt_is_let :: proc(s: ^mp.Monkey_Data, name: string) -> bool {
	let_stmt, ok := s.(mp.Node_Let_Statement)
	if !ok {
		log.errorf("s is not a let statement. got='%v'", mp.ast_get_type(s))
		return false
	}

	if let_stmt.name != name {
		log.errorf("let_stmt.name is not '%s', got='%s'", name, let_stmt.name)
		return false
	}

	return true
}

integer_literal_is_valid :: proc(il: ^mp.Monkey_Data, expected_value: int) -> bool {
	val, ok := il.(int)
	if !ok {
		log.errorf("il is not 'int', got='%v'", mp.ast_get_type(il))
		return false
	}

	if val != expected_value {
		log.errorf("value is not '%d', got='%d'", expected_value, val)
		return false
	}

	return true
}

identifier_is_valid :: proc(expr: ^mp.Monkey_Data, expected_value: string) -> bool {
	ident, ok := expr.(mp.Node_Identifier)
	if !ok {
		log.errorf("expression is not Node_Identifier, got='%v'", mp.ast_get_type(expr))
		return false
	}

	if ident.value != expected_value {
		log.errorf("ident.value is not '%s', got='%s'", expected_value, ident.value)
		return false
	}

	return true
}

boolean_is_valid :: proc(b: ^mp.Monkey_Data, expected_value: bool) -> bool {
	b_lit, ok := b.(bool)
	if !ok {
		log.errorf("expression is not boolean, got='%v'", mp.ast_get_type(b))
		return false
	}

	if b_lit != expected_value {
		log.errorf("b_lit is not '%v', got='%v'", expected_value, b_lit)
		return false
	}

	return true
}

literal_value_is_ok :: proc(lit: ^mp.Monkey_Data, expected: Literal) -> bool {
	switch v in expected {
	case int:
		return integer_literal_is_valid(lit, v)

	case string:
		return identifier_is_valid(lit, v)

	case bool:
		return boolean_is_valid(lit, v)
	}

	// unreachable
	return false
}

@(test)
test_parsing_let_statement :: proc(t: ^testing.T) {

	input := `
let x = 5; 
let y = 10;
let foobar = 838383;
    `


	p := mp.parser()
	p->config()

	defer if p._arena.total_used != 0 {
		log.errorf("test has failed, parser has un freed memory: %v", p._arena.total_used)
	}
	defer p->free()

	defer free_all(context.temp_allocator)

	program := p->parse(input)

	if parser_has_error(&p) {
		testing.fail(t)
		return
	}

	if len(program.statements) != 3 {
		log.errorf(
			"program.statements does not contain 3 statements, got='%v'",
			len(program.statements),
		)

		testing.fail(t)
		return
	}

	tests := [?]struct {
		expected_identifier: string,
	}{{"x"}, {"y"}, {"foobar"}}

	for test_case, i in tests {
		stmt := program.statements[i]
		if !stmt_is_let(&stmt, test_case.expected_identifier) {
			testing.fail(t)
			return
		}
	}
}

@(test)
test_parsing_return_statement :: proc(t: ^testing.T) {

	input := `
return 5;
return 10;
return 993322;
    `


	p := mp.parser()
	p->config()

	defer if p._arena.total_used != 0 {
		log.errorf("test has failed, parser has un freed memory: %v", p._arena.total_used)
	}
	defer p->free()

	defer free_all(context.temp_allocator)

	program := p->parse(input)

	if parser_has_error(&p) {
		testing.fail(t)
		return
	}

	if len(program.statements) != 3 {
		log.errorf(
			"program.statements does not contain 3 statements, got='%v'",
			len(program.statements),
		)

		testing.fail(t)
		return
	}

	tests := [?]struct {
		expected_identifier: string,
	}{{"x"}, {"y"}, {"foobar"}}

	for _, i in tests {
		stmt := program.statements[i]
		_, ok := stmt.(mp.Node_Return_Statement)
		if !ok {
			log.errorf(
				"test [%d]: stmt is not a return statement. got='%v'",
				i,
				mp.ast_get_type(&stmt),
			)
			continue
		}
	}
}

@(test)
test_parsing_identifier_expression :: proc(t: ^testing.T) {
	input := "foobar;"

	p := mp.parser()
	p->config()

	defer if p._arena.total_used != 0 {
		log.errorf("test has failed, parser has un freed memory: %v", p._arena.total_used)
	}
	defer p->free()

	defer free_all(context.temp_allocator)

	program := p->parse(input)

	if parser_has_error(&p) {
		testing.fail(t)
		return
	}

	if len(program.statements) != 1 {
		log.errorf(
			"program.statements does not contain 1 statements, got='%v'",
			len(program.statements),
		)

		testing.fail(t)
		return
	}

	if !identifier_is_valid(&program.statements[0], "foobar") {
		testing.fail(t)
		return
	}
}

@(test)
test_parsing_integer_literal :: proc(t: ^testing.T) {
	input := "5;"

	p := mp.parser()
	p->config()

	defer if p._arena.total_used != 0 {
		log.errorf("test has failed, parser has un freed memory: %v", p._arena.total_used)
	}
	defer p->free()

	defer free_all(context.temp_allocator)

	program := p->parse(input)

	if parser_has_error(&p) {
		testing.fail(t)
		return
	}

	if len(program.statements) != 1 {
		log.errorf(
			"program.statements does not contain 1 statements, got='%v'",
			len(program.statements),
		)

		testing.fail(t)
		return
	}

	if !literal_value_is_ok(&program.statements[0], 5) {
		testing.fail(t)
	}
}

@(test)
test_parsing_boolean_literal :: proc(t: ^testing.T) {
	input := "true;"

	p := mp.parser()
	p->config()

	defer if p._arena.total_used != 0 {
		log.errorf("test has failed, parser has un freed memory: %v", p._arena.total_used)
	}
	defer p->free()

	defer free_all(context.temp_allocator)

	program := p->parse(input)

	if parser_has_error(&p) {
		testing.fail(t)
		return
	}

	if len(program.statements) != 1 {
		log.errorf(
			"program.statements does not contain 1 statements, got='%v'",
			len(program.statements),
		)

		testing.fail(t)
		return
	}

	if !literal_value_is_ok(&program.statements[0], true) {
		testing.fail(t)
	}
}

prefix_test_case_is_ok :: proc(
	test_number: int,
	input: string,
	operator: string,
	operand_value: Literal,
) -> bool {
	p := mp.parser()
	p->config()

	defer if p._arena.total_used != 0 {
		log.errorf(
			"test [%d] has failed, parser has un freed memory: %v",
			test_number,
			p._arena.total_used,
		)
	}
	defer p->free()

	program := p->parse(input)

	if parser_has_error(&p) {
		return false
	}

	if len(program.statements) != 1 {
		log.errorf(
			"test [%d]: program.statements does not contain 1 statements, got='%v'",
			test_number,
			len(program.statements),
		)

		return false
	}

	infix, ok := program.statements[0].(mp.Node_Prefix_Expression)
	if !ok {
		log.errorf(
			"test [%d]: program.statements[0] is not 'Node_Prefix_Expression', got='%v'",
			test_number,
			mp.ast_get_type(&program.statements[0]),
		)
		return false
	}

	if infix.op != operator {
		log.errorf(
			"test [%d]: wrong infix operator expected='%s', got='%s'",
			test_number,
			operator,
			infix.op,
		)
		return false
	}

	if !literal_value_is_ok(infix.operand, operand_value) {
		log.errorf("test [%d]'s operand value has failed", test_number)
		return false
	}

	return true
}

@(test)
test_parsing_prefix_expressions :: proc(t: ^testing.T) {
	prefix_tests := [?]struct {
		input:         string,
		operator:      string,
		operand_value: Literal,
	}{{"!5;", "!", 5}, {"-15;", "-", 15}, {"!true;", "!", true}, {"!false;", "!", false}}

	defer free_all(context.temp_allocator)

	for test_case, i in prefix_tests {
		if !prefix_test_case_is_ok(
			i,
			test_case.input,
			test_case.operator,
			test_case.operand_value,
		) {
			log.errorf("Test [%d] has failed", i)
			testing.fail(t)
		}
	}
}

infix_test_case_is_ok :: proc(
	test_number: int,
	input: string,
	left_value: Literal,
	operator: string,
	right_value: Literal,
) -> bool {
	p := mp.parser()
	p->config()

	defer if p._arena.total_used != 0 {
		log.errorf(
			"test [%d] has failed, parser has un freed memory: %v",
			test_number,
			p._arena.total_used,
		)
	}
	defer p->free()

	program := p->parse(input)

	if parser_has_error(&p) {
		return false
	}

	if len(program.statements) != 1 {
		log.errorf(
			"test [%d]: program.statements does not contain 1 statements, got='%v'",
			test_number,
			len(program.statements),
		)

		return false
	}

	infix, ok := program.statements[0].(mp.Node_Infix_Expression)
	if !ok {
		log.errorf(
			"test [%d]: program.statements[0] is not 'Node_Infix_Expression', got='%v'",
			test_number,
			mp.ast_get_type(&program.statements[0]),
		)
		return false
	}

	if infix.op != operator {
		log.errorf(
			"test [%d]: wrong infix operator expected='%s', got='%s'",
			test_number,
			operator,
			infix.op,
		)
		return false
	}

	if !literal_value_is_ok(infix.left, left_value) {
		log.errorf("test [%d]'s left value has failed", test_number)
		return false
	}

	if !literal_value_is_ok(infix.right, right_value) {
		log.errorf("test [%d]'s right value has failed", test_number)
		return false
	}

	return true
}

@(test)
test_parsing_infix_expressions :: proc(t: ^testing.T) {
	tests := []struct {
		input:       string,
		left_value:  Literal,
		operator:    string,
		right_value: Literal,
	} {
		{"5 + 5;", 5, "+", 5},
		{"5 - 5;", 5, "-", 5},
		{"5 * 5;", 5, "*", 5},
		{"5 / 5;", 5, "/", 5},
		{"5 > 5;", 5, ">", 5},
		{"5 < 5;", 5, "<", 5},
		{"5 == 5;", 5, "==", 5},
		{"5 != 5;", 5, "!=", 5},
		{"true == true", true, "==", true},
		{"true != false", true, "!=", false},
		{"false == false", false, "==", false},
	}

	defer free_all(context.temp_allocator)

	for test_case, i in tests {
		if !infix_test_case_is_ok(
			i,
			test_case.input,
			test_case.left_value,
			test_case.operator,
			test_case.right_value,
		) {
			log.errorf("Test [%d] has failed", i)
			testing.fail(t)
		}
	}
}

ast_string_is_valid :: proc(input: string, expected: string) -> bool {
	p := mp.parser()
	p->config()

	defer if p._arena.total_used != 0 {
		log.errorf("parser has un freed memory: %v", p._arena.total_used)
	}
	defer p->free()

	program := p->parse(input)

	if parser_has_error(&p) {
		return false
	}

	sb := s.builder_make(context.temp_allocator)
	prog := mp.Monkey_Data(program)
	mp.ast_to_string(&prog, &sb)

	if s.to_string(sb) != expected {
		log.errorf(
			"ast_to_string ris not valid, expected='%s', got='%s'",
			expected,
			s.to_string(sb),
		)
		return false
	}

	return true
}

@(test)
test_parsing_operator_precedence :: proc(t: ^testing.T) {
	tests := []struct {
		input:    string,
		expected: string,
	} {
		{"-a * b", "((-a)*b)"},
		{"!-a", "(!(-a))"},
		{"a + b + c", "((a+b)+c)"},
		{"a * b * c", "((a*b)*c)"},
		{"a * b / c", "((a*b)/c)"},
		{"a + b / c", "(a+(b/c))"},
		{"a + b * c + d / e - f", "(((a+(b*c))+(d/e))-f)"},
		{"3 + 4; -5 * 5", "(3+4)\n((-5)*5)"},
		{"5 > 4 == 3 < 4", "((5>4)==(3<4))"},
		{"5 < 4 != 3 > 4", "((5<4)!=(3>4))"},
		{"3 + 4 * 5 == 3 * 1 + 4 * 5", "((3+(4*5))==((3*1)+(4*5)))"},
		{"true", "true"},
		{"false", "false"},
		{"3 > 5 == false", "((3>5)==false)"},
		{"3 < 5 == true", "((3<5)==true)"},
		{"1 + (2 + 3) + 4", "((1+(2+3))+4)"},
		{"(5 + 5) * 2", "((5+5)*2)"},
		{"2 / (5 + 5)", "(2/(5+5))"},
		{"-(5 + 5)", "(-(5+5))"},
		{"!(true == true)", "(!(true==true))"},
	}

	defer free_all(context.temp_allocator)

	for test_case, i in tests {
		if !ast_string_is_valid(test_case.input, test_case.expected) {
			log.errorf("Test [%d] has failed", i)
			testing.fail(t)
		}
	}
}
