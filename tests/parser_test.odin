package monkey_tests

import m "../monkey"

import "core:log"
import st "core:strings"
import "core:testing"

Literal :: union {
	string,
	int,
	bool,
}

parser_has_error :: proc(p: m.Parser) -> bool {
	if len(p.errors) == 0 do return false

	log.errorf("parser has %d errors", len(p.errors))
	for msg, _ in p.errors {
		log.errorf("parser error: %q", msg)
	}

	return true
}

stmt_is_let :: proc(s: m.Node, name: string, expected_value: Literal) -> bool {
	let_stmt, ok := s.(m.Node_Let_Statement)
	if !ok {
		log.errorf("s is not a let statement. got='%v'", m.ast_type(s))
		return false
	}

	if let_stmt.name != name {
		log.errorf("let_stmt.name is not '%s', got='%s'", name, let_stmt.name)
		return false
	}

	return literal_value_is_valid(let_stmt.value, expected_value)
}

integer_literal_is_valid :: proc(il: ^m.Node, expected_value: int) -> bool {
	val, ok := il.(int)
	if !ok {
		log.errorf("il is not 'int', got='%v'", m.ast_type(il))
		return false
	}

	if val != expected_value {
		log.errorf("value is not '%d', got='%d'", expected_value, val)
		return false
	}

	return true
}

identifier_is_valid :: proc(expr: ^m.Node, expected_value: string) -> bool {
	ident, ok := expr.(m.Node_Identifier)
	if !ok {
		log.errorf("expression is not Node_Identifier, got='%v'", m.ast_type(expr))
		return false
	}

	if ident.value != expected_value {
		log.errorf("ident.value is not '%s', got='%s'", expected_value, ident.value)
		return false
	}

	return true
}

boolean_is_valid :: proc(b: ^m.Node, expected_value: bool) -> bool {
	b_lit, ok := b.(bool)
	if !ok {
		log.errorf("expression is not boolean, got='%v'", m.ast_type(b))
		return false
	}

	if b_lit != expected_value {
		log.errorf("b_lit is not '%v', got='%v'", expected_value, b_lit)
		return false
	}

	return true
}

literal_value_is_valid :: proc(lit: ^m.Node, expected: Literal) -> bool {
	switch v in expected {
	case int:
		return integer_literal_is_valid(lit, v)

	case string:
		return identifier_is_valid(lit, v)

	case bool:
		return boolean_is_valid(lit, v)
	}

	unreachable()
}

@(test)
test_parsing_let_statement :: proc(t: ^testing.T) {

	input := `
let x = 5; 
let y = true;
let foobar = y;
    `


	tests := [?]struct {
		expected_identifier: string,
		expected_value:      Literal,
	}{{"x", 5}, {"y", true}, {"foobar", "y"}}


	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	defer free_all(context.temp_allocator)

	program := p->parse(input)

	if parser_has_error(p) {
		testing.fail(t)
		return
	}

	if len(program) != 3 {
		log.errorf("program does not contain 3 statements, got='%v'", len(program))

		testing.fail(t)
		return
	}

	for test_case, i in tests {
		if !stmt_is_let(program[i], test_case.expected_identifier, test_case.expected_value) {
			testing.fail(t)
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


	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	defer free_all(context.temp_allocator)

	program := p->parse(input)

	if parser_has_error(p) {
		testing.fail(t)
		return
	}

	if len(program) != 3 {
		log.errorf("program does not contain 3 statements, got='%v'", len(program))

		testing.fail(t)
		return
	}

	tests := [?]struct {
		expected_identifier: string,
	}{{"x"}, {"y"}, {"foobar"}}

	for _, i in tests {
		stmt := program[i]
		_, ok := stmt.(m.Node_Return_Statement)
		if !ok {
			log.errorf("test [%d]: stmt is not a return statement. got='%v'", i, m.ast_type(stmt))
			continue
		}
	}
}

@(test)
test_parsing_identifier_expression :: proc(t: ^testing.T) {
	input := "foobar;"

	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	defer free_all(context.temp_allocator)

	program := p->parse(input)

	if parser_has_error(p) {
		testing.fail(t)
		return
	}

	if len(program) != 1 {
		log.errorf("program does not contain 1 statement, got='%v'", len(program))

		testing.fail(t)
		return
	}

	if !identifier_is_valid(&program[0], "foobar") {
		testing.fail(t)
		return
	}
}

@(test)
test_parsing_integer_literal :: proc(t: ^testing.T) {
	input := "5;"

	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	defer free_all(context.temp_allocator)

	program := p->parse(input)

	if parser_has_error(p) {
		testing.fail(t)
		return
	}

	if len(program) != 1 {
		log.errorf("program does not contain 1 statement, got='%v'", len(program))

		testing.fail(t)
		return
	}

	if !literal_value_is_valid(&program[0], 5) {
		testing.fail(t)
	}
}

@(test)
test_parsing_boolean_literal :: proc(t: ^testing.T) {
	input := "true;"

	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	defer free_all(context.temp_allocator)

	program := p->parse(input)

	if parser_has_error(p) {
		testing.fail(t)
		return
	}

	if len(program) != 1 {
		log.errorf("program does not contain 1 statement, got='%v'", len(program))

		testing.fail(t)
		return
	}

	if !literal_value_is_valid(&program[0], true) {
		testing.fail(t)
	}
}

@(test)
test_parsing_string_literal :: proc(t: ^testing.T) {
	input := `"hello world";`

	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	defer free_all(context.temp_allocator)

	program := p->parse(input)

	if parser_has_error(p) {
		testing.fail(t)
		return
	}

	if len(program) != 1 {
		log.errorf("program does not contain 1 statement, got='%v'", len(program))

		testing.fail(t)
		return
	}

	literal, str_ok := program[0].(string)

	if !str_ok {
		log.errorf("expression is not string, got='%v'", m.ast_type(program[0]))
		testing.fail(t)
		return
	}

	if literal != "hello world" {
		log.errorf("string is not 'hello world', got='%s'", literal)
		testing.fail(t)
	}
}

prefix_test_case_is_ok :: proc(
	test_number: int,
	input: string,
	operator: string,
	operand_value: Literal,
) -> bool {
	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test [%d] has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			test_number,
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	program := p->parse(input)

	if parser_has_error(p) {
		return false
	}

	if len(program) != 1 {
		log.errorf(
			"test [%d]: program does not contain 1 statement, got='%v'",
			test_number,
			len(program),
		)

		return false
	}

	infix, ok := program[0].(m.Node_Prefix_Expression)
	if !ok {
		log.errorf(
			"test [%d]: program[0] is not 'Node_Prefix_Expression', got='%v'",
			test_number,
			m.ast_type(program[0]),
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

	if !literal_value_is_valid(infix.operand, operand_value) {
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

infix_expression_is_valid :: proc(
	expression: ^m.Node,
	left_value: Literal,
	operator: string,
	right_value: Literal,
) -> bool {
	infix, ok := expression.(m.Node_Infix_Expression)
	if !ok {
		log.errorf("expression is not 'Node_Infix_Expression', got='%v'", m.ast_type(expression))
		return false
	}

	if infix.op != operator {
		log.errorf("wrong infix operator expected='%s', got='%s'", operator, infix.op)
		return false
	}

	if !literal_value_is_valid(infix.left, left_value) {
		log.errorf("test's left value has failed")
		return false
	}

	if !literal_value_is_valid(infix.right, right_value) {
		log.errorf("test's right value has failed")
		return false
	}

	return true
}

infix_test_case_is_valid :: proc(
	input: string,
	left_value: Literal,
	operator: string,
	right_value: Literal,
) -> bool {
	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	program := p->parse(input)

	if parser_has_error(p) {
		return false
	}

	if len(program) != 1 {
		log.errorf("program does not contain 1 statement, got='%v'", len(program))

		return false
	}

	return infix_expression_is_valid(&program[0], left_value, operator, right_value)
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
		if !infix_test_case_is_valid(
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
	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	program := p->parse(input)

	if parser_has_error(p) {
		return false
	}

	sb := st.builder_make(context.temp_allocator)
	m.ast_to_string(program, &sb)

	if st.to_string(sb) != expected {
		log.errorf(
			"ast_to_string result is not valid, expected='%s', got='%s'",
			expected,
			st.to_string(sb),
		)
		return false
	}

	return true
}

@(test)
test_parsing_if_expression :: proc(t: ^testing.T) {
	input := "if x < y { x }"

	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	program := p->parse(input)

	if parser_has_error(p) {
		testing.fail(t)
		return
	}

	if len(program) != 1 {
		log.errorf("program does not contain 1 statement, got='%v'", len(program))

		testing.fail(t)
		return
	}

	stmt, ok := program[0].(m.Node_If_Expression)
	if !ok {
		log.errorf("program[0] is not Node_If_Expression, got='%v'", m.ast_type(program[0]))
		testing.fail(t)
		return
	}

	if !infix_expression_is_valid(stmt.condition, "x", "<", "y") {
		testing.fail(t)
		return
	}

	if len(stmt.consequence) != 1 {
		log.errorf("consequence is not 1 statement, got='%d'", len(stmt.consequence))
		testing.fail(t)
		return
	}

	if !identifier_is_valid(&stmt.consequence[0], "x") {
		testing.fail(t)
		return
	}

	if stmt.alternative != nil {
		log.errorf("alternative is not nil, got='%d'", len(stmt.alternative))
		testing.fail(t)
		return
	}
}

@(test)
test_parsing_if_else_expression :: proc(t: ^testing.T) {
	input := "if x < y { x } else { y }"

	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	program := p->parse(input)

	if parser_has_error(p) {
		testing.fail(t)
		return
	}

	if len(program) != 1 {
		log.errorf("program does not contain 1 statement, got='%v'", len(program))

		testing.fail(t)
		return
	}

	stmt, ok := program[0].(m.Node_If_Expression)
	if !ok {
		log.errorf("program[0] is not Node_If_Expression, got='%v'", m.ast_type(program[0]))
		testing.fail(t)
		return
	}

	if !infix_expression_is_valid(stmt.condition, "x", "<", "y") {
		testing.fail(t)
		return
	}

	if len(stmt.consequence) != 1 {
		log.errorf("consequence is not 1 statement, got='%d'", len(stmt.consequence))
		testing.fail(t)
		return
	}

	if !identifier_is_valid(&stmt.consequence[0], "x") {
		testing.fail(t)
		return
	}

	if stmt.alternative == nil {
		log.errorf("alternative is nil")
		testing.fail(t)
		return
	}

	if len(stmt.alternative) != 1 {
		log.errorf("alternative is not 1 statement, got='%d'", len(stmt.alternative))
		testing.fail(t)
		return
	}

	if !identifier_is_valid(&stmt.alternative[0], "y") {
		testing.fail(t)
		return
	}
}

@(test)
test_parsing_function_literal :: proc(t: ^testing.T) {
	input := "fn(x, y) { x + y; }"

	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	program := p->parse(input)

	if parser_has_error(p) {
		testing.fail(t)
		return
	}

	if len(program) != 1 {
		log.errorf("program does not contain 1 statement, got='%v'", len(program))

		testing.fail(t)
		return
	}

	stmt, ok := program[0].(m.Node_Function_Literal)
	if !ok {
		log.errorf("program[0] is not Node_Function_Literal, got='%v'", m.ast_type(program[0]))
		testing.fail(t)
		return
	}

	if len(stmt.parameters) != 2 {
		log.errorf(
			"function literal wrong number of parameters. expected='2', got='%d'",
			len(stmt.parameters),
		)
		testing.fail(t)
		return
	}

	if stmt.parameters[0].value != "x" {
		log.errorf("expected first parameter to be 'x', got='%s'", stmt.parameters[0].value)
		testing.fail(t)
		return
	}

	if stmt.parameters[1].value != "y" {
		log.errorf("expected first parameter to be 'x', got='%s'", stmt.parameters[1].value)
		testing.fail(t)
		return
	}

	if len(stmt.body) != 1 {
		log.errorf("function body does not contain 1 statement, got='%v'", len(stmt.body))

		testing.fail(t)
		return
	}

	if !infix_expression_is_valid(&stmt.body[0], "x", "+", "y") {
		testing.fail(t)
		return
	}
}

@(test)
test_parsing_call_expression :: proc(t: ^testing.T) {
	input := "add(1, 2 * 3, 4 + 5);"

	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	program := p->parse(input)

	if parser_has_error(p) {
		testing.fail(t)
		return
	}

	if len(program) != 1 {
		log.errorf("program does not contain 1 statement, got='%v'", len(program))

		testing.fail(t)
		return
	}

	stmt, ok := program[0].(m.Node_Call_Expression)
	if !ok {
		log.errorf("program[0] is not Node_Call_Expression, got='%v'", m.ast_type(program[0]))
		testing.fail(t)
		return
	}

	if !identifier_is_valid(stmt.function, "add") {
		testing.fail(t)
		return
	}

	if len(stmt.arguments) != 3 {
		log.errorf("call expression does not contain 3 arguments, got='%v'", len(stmt.arguments))

		testing.fail(t)
		return
	}

	if !literal_value_is_valid(&stmt.arguments[0], 1) {
		testing.fail(t)
		return
	}

	if !infix_expression_is_valid(&stmt.arguments[1], 2, "*", 3) {
		testing.fail(t)
		return
	}

	if !infix_expression_is_valid(&stmt.arguments[2], 4, "+", 5) {
		testing.fail(t)
		return
	}
}

@(test)
test_parsing_array_literal :: proc(t: ^testing.T) {
	input := "[1, 2 * 2, 3 + 3]"

	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	program := p->parse(input)

	if parser_has_error(p) {
		testing.fail(t)
		return
	}

	if len(program) != 1 {
		log.errorf("program does not contain 1 statement, got='%v'", len(program))

		testing.fail(t)
		return
	}

	stmt, ok := program[0].(m.Node_Array_Literal)
	if !ok {
		log.errorf("program[0] is not Node_Array_Literal, got='%v'", m.ast_type(program[0]))
		testing.fail(t)
		return
	}

	if len(stmt) != 3 {
		log.errorf("length of the array is not 3, got='%d'", len(stmt))
		testing.fail(t)
		return
	}

	if !literal_value_is_valid(&stmt[0], 1) {
		testing.fail(t)
		return
	}

	if !infix_expression_is_valid(&stmt[1], 2, "*", 2) {
		testing.fail(t)
		return
	}

	if !infix_expression_is_valid(&stmt[2], 3, "+", 3) {
		testing.fail(t)
		return
	}
}

@(test)
test_parsing_hash_table_literal :: proc(t: ^testing.T) {
	input := `{"one": 1, "two": 2, "three": 3}`

	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	program := p->parse(input)

	if parser_has_error(p) {
		testing.fail(t)
		return
	}

	if len(program) != 1 {
		log.errorf("program does not contain 1 statement, got='%v'", len(program))

		testing.fail(t)
		return
	}

	stmt, ok := program[0].(m.Node_Hash_Table_Literal)
	if !ok {
		log.errorf("program[0] is not Node_Hash_Table_Literal, got='%v'", m.ast_type(program[0]))
		testing.fail(t)
		return
	}

	if len(stmt) != 3 {
		log.errorf("length of the hash table is not 3, got='%d'", len(stmt))
		testing.fail(t)
		return
	}

	expected := map[string]int {
		"one"   = 1,
		"two"   = 2,
		"three" = 3,
	}
	defer delete(expected)

	for key, expected_value in expected {
		value, key_exists := stmt[key]
		if !key_exists {
			log.errorf("key '%s' does not exist in the hash table", key)
			testing.fail(t)
			continue
		}

		if !literal_value_is_valid(&value, expected_value) {
			testing.fail(t)
		}
	}
}

@(test)
test_parsing_hash_table_literal_with_expressions :: proc(t: ^testing.T) {
	input := `{"one": 0 + 1, "two": 10 - 8, "three": 15 / 5}`

	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	program := p->parse(input)

	if parser_has_error(p) {
		testing.fail(t)
		return
	}

	if len(program) != 1 {
		log.errorf("program does not contain 1 statement, got='%v'", len(program))

		testing.fail(t)
		return
	}

	stmt, ok := program[0].(m.Node_Hash_Table_Literal)
	if !ok {
		log.errorf("program[0] is not Node_Hash_Table_Literal, got='%v'", m.ast_type(program[0]))
		testing.fail(t)
		return
	}

	if len(stmt) != 3 {
		log.errorf("length of the hash table is not 3, got='%d'", len(stmt))
		testing.fail(t)
		return
	}

	expected := map[string]proc(node: ^m.Node) -> bool {
		"one" = proc(node: ^m.Node) -> bool {
			return infix_expression_is_valid(node, 0, "+", 1)
		},
		"two" = proc(node: ^m.Node) -> bool {
			return infix_expression_is_valid(node, 10, "-", 8)
		},
		"three" = proc(node: ^m.Node) -> bool {
			return infix_expression_is_valid(node, 15, "/", 5)
		},
	}
	defer delete(expected)

	for key, test_fn in expected {
		value, key_exists := stmt[key]
		if !key_exists {
			log.errorf("key '%s' does not exist in the hash table", key)
			testing.fail(t)
			continue
		}

		if !test_fn(&value) {
			log.errorf("test failed for the key '%s'", key)
			testing.fail(t)
		}
	}
}

@(test)
test_parsing_empty_hash_table_literal :: proc(t: ^testing.T) {
	input := "{}"

	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	program := p->parse(input)

	if parser_has_error(p) {
		testing.fail(t)
		return
	}

	if len(program) != 1 {
		log.errorf("program does not contain 1 statement, got='%v'", len(program))

		testing.fail(t)
		return
	}

	stmt, ok := program[0].(m.Node_Hash_Table_Literal)
	if !ok {
		log.errorf("program[0] is not Node_Hash_Table_Literal, got='%v'", m.ast_type(program[0]))
		testing.fail(t)
		return
	}

	if len(stmt) != 0 {
		log.errorf("length of the hash table is not 0, got='%d'", len(stmt))
		testing.fail(t)
		return
	}
}

@(test)
test_parsing_index_expression :: proc(t: ^testing.T) {
	input := "my_array[1 + 1]"

	p := m.parser()
	p->init()

	defer if ok, arena, dyn_arr_pool := p->mem_is_freed(); !ok {
		log.errorf(
			"test has failed, arena total used: %v, dynamic array pool unremoved items: %d",
			arena,
			dyn_arr_pool,
		)
	}
	defer p->mem_free()

	program := p->parse(input)

	if parser_has_error(p) {
		testing.fail(t)
		return
	}

	if len(program) != 1 {
		log.errorf("program does not contain 1 statement, got='%v'", len(program))

		testing.fail(t)
		return
	}

	stmt, ok := program[0].(m.Node_Index_Expression)
	if !ok {
		log.errorf("program[0] is not Node_Index_Expression, got='%v'", m.ast_type(program[0]))
		testing.fail(t)
		return
	}

	if !literal_value_is_valid(stmt.operand, "my_array") {
		testing.fail(t)
		return
	}

	if !infix_expression_is_valid(stmt.index, 1, "+", 1) {
		testing.fail(t)
		return
	}
}

@(test)
test_parsing_result_by_ast_to_string :: proc(t: ^testing.T) {
	tests := [?]struct {
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
		{"if x > y { x }", "if (x>y) { x }"},
		{"if x > y { x } else { y }", "if (x>y) { x } else { y }"},
		{"fn() {};", "Fn () {  }"},
		{"fn(x) {};", "Fn (x) {  }"},
		{"fn(x, y) {};", "Fn (x, y) {  }"},
		{"fn(x, y) { x + y };", "Fn (x, y) { (x+y) }"},
		{"a + add(b * c) + d", "((a+add((b*c)))+d)"},
		{"add(a, b, 1, 2 * 4, 4 + 5, add(6, 7 * 8))", "add(a, b, 1, (2*4), (4+5), add(6, (7*8)))"},
		{"add(a + b + c * d / f + g)", "add((((a+b)+((c*d)/f))+g))"},
		{"a * [1, 2, 3, 4][b * c] * d", "((a*([1, 2, 3, 4][(b*c)]))*d)"},
		{"add(a * b[2], b[1], 2 * [1, 2][1])", "add((a*(b[2])), (b[1]), (2*([1, 2][1])))"},
	}

	defer free_all(context.temp_allocator)

	for test_case, i in tests {
		if !ast_string_is_valid(test_case.input, test_case.expected) {
			log.errorf("Test [%d] has failed", i)
			testing.fail(t)
		}
	}
}
