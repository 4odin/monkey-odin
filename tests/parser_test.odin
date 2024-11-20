package tests

import mp "../parser"

import "core:log"
import "core:testing"

parser_has_error :: proc(p: ^mp.Parser) -> bool {
	if len(p.errors) == 0 do return false

	log.errorf("parser has %d errors", len(p.errors))
	for msg, _ in p.errors {
		log.errorf("parser error: %q", msg)
	}

	return true
}

stmt_is_let :: proc(s: mp.Monkey_Data, name: string) -> bool {
	let_stmt, ok := s.v.(mp.Node_Let_Statement)
	if !ok || s.type != mp.Node_Let_Statement {
		log.errorf("s is not a let statement. got='%v'", s.type)
		return false
	}

	if let_stmt.name != name {
		log.errorf("let_stmt.name is not '%s', got='%s'", name, let_stmt.name)
		return false
	}

	return true
}

@(test)
test_let_statement :: proc(t: ^testing.T) {

	input := `
let x = 5;
let y = 10;
let foobar = 838383;
    `


	p := mp.parser()
	p->init(input, context.temp_allocator)
	defer free_all(context.temp_allocator)

	program := p->parse()

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
		if !stmt_is_let(stmt, test_case.expected_identifier) {
			testing.fail(t)
			return
		}
	}
}

@(test)
test_return_statement :: proc(t: ^testing.T) {

	input := `
return 5;
return 10;
return 993322;
    `


	p := mp.parser()
	p->init(input, context.temp_allocator)
	defer free_all(context.temp_allocator)

	program := p->parse()

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
		_, ok := stmt.v.(mp.Node_Return_Statement)
		if !ok || stmt.type != mp.Node_Return_Statement {
			log.errorf("test [%d]: stmt is not a return statement. got='%v'", i, stmt.type)
			continue
		}
	}
}

@(test)
test_identifier_expression :: proc(t: ^testing.T) {
	input := "foobar;"

	p := mp.parser()
	p->init(input, context.temp_allocator)
	defer free_all(context.temp_allocator)

	program := p->parse()

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

	ident, ok := program.statements[0].v.(mp.Node_Identifier)
	if !ok || program.statements[0].type != mp.Node_Identifier {
		log.errorf(
			"program.statements[0] is not Node_Identifier, got='%v'",
			program.statements[0].type,
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
test_integer_literal :: proc(t: ^testing.T) {
	input := "5;"

	p := mp.parser()
	p->init(input, context.temp_allocator)
	defer free_all(context.temp_allocator)

	program := p->parse()

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

	value, ok := program.statements[0].v.(int)
	if !ok || program.statements[0].type != int {
		log.errorf("program.statements[0] is not 'int', got='%v'", program.statements[0].type)
		testing.fail(t)
		return
	}

	if value != 5 {
		log.errorf("value.value not '5', got='%d'", value)
		testing.fail(t)
		return
	}
}
