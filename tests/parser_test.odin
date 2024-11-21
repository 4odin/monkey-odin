package tests

import mp "../parser"

import "core:log"
import s "core:strings"
import "core:testing"

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

@(test)
test_parsing_let_statement :: proc(t: ^testing.T) {

	input := `
let x = 5; 
let y = 10;
let foobar = 838383;
    `


	p := mp.parser()
	p->config()
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

	ident, ok := program.statements[0].(mp.Node_Identifier)
	if !ok {
		log.errorf(
			"program.statements[0] is not Node_Identifier, got='%v'",
			mp.ast_get_type(&program.statements[0]),
		)
		testing.fail(t)
		return
	}

	if ident.value != "foobar" {
		log.errorf("ident.value not 'foobar', got='%s'", ident.value)
		testing.fail(t)
		return
	}
}

@(test)
test_parsing_integer_literal :: proc(t: ^testing.T) {
	input := "5;"

	p := mp.parser()
	p->config()
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

	if !integer_literal_is_valid(&program.statements[0], 5) {
		testing.fail(t)
	}
}

prefix_test_case_is_ok :: proc(
	test_number: int,
	input: string,
	operator: string,
	operand_value: int,
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

	if !integer_literal_is_valid(infix.operand, operand_value) {
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
		operand_value: int,
	}{{"!5;", "!", 5}, {"-15;", "-", 15}}

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
	left_value: int,
	operator: string,
	right_value: int,
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

	if !integer_literal_is_valid(infix.left, left_value) {
		log.errorf("test [%d]'s left value has failed", test_number)
		return false
	}

	if !integer_literal_is_valid(infix.right, right_value) {
		log.errorf("test [%d]'s right value has failed", test_number)
		return false
	}

	return true
}

@(test)
test_parsing_infix_expressions :: proc(t: ^testing.T) {
	tests := []struct {
		input:       string,
		left_value:  int,
		operator:    string,
		right_value: int,
	} {
		{"5 + 5;", 5, "+", 5},
		{"5 - 5;", 5, "-", 5},
		{"5 * 5;", 5, "*", 5},
		{"5 / 5;", 5, "/", 5},
		{"5 > 5;", 5, ">", 5},
		{"5 < 5;", 5, "<", 5},
		{"5 == 5;", 5, "==", 5},
		{"5 != 5;", 5, "!=", 5},
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
	}

	defer free_all(context.temp_allocator)

	for test_case, i in tests {
		if !ast_string_is_valid(test_case.input, test_case.expected) {
			log.errorf("Test [%d] has failed", i)
			testing.fail(t)
		}
	}
}
