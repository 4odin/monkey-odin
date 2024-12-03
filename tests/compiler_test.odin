package monkey_tests

import "core:fmt"
import "core:log"
import "core:reflect"

import m "../monkey"

import "core:testing"

@(private = "file")
Test_Data :: union {
	int,
	string,
	[]m.Instructions,
}

Compiler_Test_Case :: struct {
	input:                 string,
	expected_constants:    []Test_Data,
	expected_instructions: []m.Instructions,
}

test_integer_object :: proc(expected: int, actual: m.Object_Base) -> (err: string) {
	result, ok := actual.(int)
	if !ok {
		return fmt.tprintf("object is not integer. got='%v'", m.obj_type(actual))
	}

	if result != expected {
		return fmt.tprintf("object has wrong value. wants='%d', got='%d'", expected, result)
	}

	return ""
}

test_boolean_object :: proc(expected: bool, actual: m.Object_Base) -> (err: string) {
	result, ok := actual.(bool)
	if !ok {
		return fmt.tprintf("object is not boolean. got='%v'", m.obj_type(actual))
	}

	if result != expected {
		return fmt.tprintf("object has wrong value. wants='%v', got='%v'", expected, result)
	}

	return ""
}

test_string_object :: proc(expected: string, actual: m.Object_Base) -> (err: string) {
	result, ok := actual.(string)
	if !ok {
		return fmt.tprintf("object is not string. got='%v'", m.obj_type(actual))
	}

	if result != expected {
		return fmt.tprintf("object has wrong value. wants='%s', got='%s'", expected, result)
	}

	return ""
}

test_constants :: proc(expected: []Test_Data, actual: []m.Object_Base) -> (err: string) {
	if len(expected) != len(actual) {
		return fmt.tprintf(
			"wrong number of constants. wants='%d', got='%d'",
			len(expected),
			len(actual),
		)
	}

	err = ""

	for constant, i in expected {
		t := reflect.union_variant_typeid(constant)

		switch constant_value in constant {
		case int:
			err = test_integer_object(constant_value, actual[i])

		case string:
			err = test_string_object(constant_value, actual[i])

		case []m.Instructions:
			fn, ok := actual[i].(m.Obj_Compiled_Fn_Obj)
			if !ok {
				err = fmt.tprintf("not a function: '%v'", m.obj_type(actual[i]))
			} else {
				err = test_instructions(constant_value, fn.instructions[:])
			}
		}

		if err != "" {
			err = fmt.tprintf("constant '%v' - testing '%v' object failed with: %v", i, t, err)
			break
		}
	}

	return
}

test_instructions :: proc(expected: []m.Instructions, actual: []byte) -> (err: string) {
	concatenated := concat_instructions(expected)

	if (len(actual) != len(concatenated)) {
		return fmt.tprintf("wrong instructions length. wants='%v', got='%v'", concatenated, actual)
	}

	for ins, i in concatenated {
		if actual[i] != ins {
			return fmt.tprintf(
				"wrong instruction at %d. wants='%d', got='%d'",
				i,
				concatenated,
				actual,
			)
		}
	}

	return ""
}

run_compiler_tests :: proc(t: ^testing.T, tests: []Compiler_Test_Case) {
	defer free_all(context.temp_allocator)

	for test_case, i in tests {
		{
			p := m.parser()
			p->init()
			defer p->mem_free()

			program := p->parse(test_case.input)
			if len(p.errors) > 0 {
				for err in p.errors do log.errorf("test[%d] has failed, parser error: %s", i, err)

				testing.fail(t)
				continue
			}

			compiler_state := m.compiler_state()
			compiler_state->init()
			defer compiler_state->free()

			compiler := m.compiler()
			compiler->init(&compiler_state)
			defer compiler->mem_free()

			err := compiler->compile(program)
			if err != "" {
				log.errorf("test[%d] has failed, compiler has error: %s", i, err)
				testing.fail(t)
				continue
			}

			bytecode := compiler->bytecode()

			err = test_instructions(test_case.expected_instructions[:], bytecode.instructions)
			if err != "" {
				log.errorf("test[%d] has failed, test instructions has failed with: %s", i, err)
				testing.fail(t)
				continue
			}

			err = test_constants(test_case.expected_constants, bytecode.constants)
			if err != "" {
				log.errorf("test[%d] has failed, test constants has failed with: %s", i, err)
				testing.fail(t)
				continue
			}
		}
	}
}

@(test)
test_compile_integer_arithmetic :: proc(t: ^testing.T) {
	tests := [?]Compiler_Test_Case {
		{
			"1; 2",
			{1, 2},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Pop),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"-1",
			{1},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Neg),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"1 + 2",
			{1, 2},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Add),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"1 - 2",
			{1, 2},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Sub),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"1 * 2",
			{1, 2},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Mul),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"1 / 2",
			{1, 2},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Div),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
	}

	defer free_all(context.temp_allocator)

	run_compiler_tests(t, tests[:])
}

@(test)
test_compile_boolean_expressions :: proc(t: ^testing.T) {
	tests := [?]Compiler_Test_Case {
		{
			"true",
			{},
			{
				m.make_instructions(context.temp_allocator, .True),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"false",
			{},
			{
				m.make_instructions(context.temp_allocator, .False),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"!true",
			{},
			{
				m.make_instructions(context.temp_allocator, .True),
				m.make_instructions(context.temp_allocator, .Not),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"1 > 2",
			{1, 2},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Gt),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"1 < 2",
			{2, 1},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Gt),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"1 == 2",
			{1, 2},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Eq),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"1 != 2",
			{1, 2},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Neq),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"true == false",
			{},
			{
				m.make_instructions(context.temp_allocator, .True),
				m.make_instructions(context.temp_allocator, .False),
				m.make_instructions(context.temp_allocator, .Eq),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"true != false",
			{},
			{
				m.make_instructions(context.temp_allocator, .True),
				m.make_instructions(context.temp_allocator, .False),
				m.make_instructions(context.temp_allocator, .Neq),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
	}

	defer free_all(context.temp_allocator)

	run_compiler_tests(t, tests[:])
}

@(test)
test_compile_if_expression :: proc(t: ^testing.T) {
	tests := [?]Compiler_Test_Case {
		{
			"if true { 10 }; 3333;",
			{10, 3333},
			{
				// 0000
				m.make_instructions(context.temp_allocator, .True),
				// 0001
				m.make_instructions(context.temp_allocator, .Jmp_If_Not, 10),
				// 0004
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				// 0007
				m.make_instructions(context.temp_allocator, .Jmp, 11),
				// 0010
				m.make_instructions(context.temp_allocator, .Nil),
				// 0011
				m.make_instructions(context.temp_allocator, .Pop),
				// 0012
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				// 0015
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"if true { 10 } else { 20 }; 3333;",
			{10, 20, 3333},
			{
				// 0000
				m.make_instructions(context.temp_allocator, .True),
				// 0001
				m.make_instructions(context.temp_allocator, .Jmp_If_Not, 10),
				// 0004
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				// 0007
				m.make_instructions(context.temp_allocator, .Jmp, 13),
				// 0010
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				// 0013
				m.make_instructions(context.temp_allocator, .Pop),
				// 0014
				m.make_instructions(context.temp_allocator, .Cnst, 2),
				// 0017
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
	}

	defer free_all(context.temp_allocator)

	run_compiler_tests(t, tests[:])
}

@(test)
test_compile_global_let_statements :: proc(t: ^testing.T) {
	tests := [?]Compiler_Test_Case {
		{
			"let one = 1; let two = 2;",
			{1, 2},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Set_G, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Set_G, 1),
			},
		},
		{
			"let one = 1; one;",
			{1},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Set_G, 0),
				m.make_instructions(context.temp_allocator, .Get_G, 0),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"let one = 1; let two = one; two;",
			{1},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Set_G, 0),
				m.make_instructions(context.temp_allocator, .Get_G, 0),
				m.make_instructions(context.temp_allocator, .Set_G, 1),
				m.make_instructions(context.temp_allocator, .Get_G, 1),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
	}

	defer free_all(context.temp_allocator)

	run_compiler_tests(t, tests[:])
}

@(test)
test_compile_string_expressions :: proc(t: ^testing.T) {
	tests := [?]Compiler_Test_Case {
		{
			`"monkey"`,
			{"monkey"},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			`"mon" + "key"`,
			{"mon", "key"},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Add),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
	}

	defer free_all(context.temp_allocator)

	run_compiler_tests(t, tests[:])
}

@(test)
test_compile_array_literals :: proc(t: ^testing.T) {
	tests := [?]Compiler_Test_Case {
		{
			"[]",
			{},
			{
				m.make_instructions(context.temp_allocator, .Arr, 0),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"[1, 2, 3]",
			{1, 2, 3},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Cnst, 2),
				m.make_instructions(context.temp_allocator, .Arr, 3),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"[1 + 2, 3 - 4, 5 * 6]",
			{1, 2, 3, 4, 5, 6},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Add),
				m.make_instructions(context.temp_allocator, .Cnst, 2),
				m.make_instructions(context.temp_allocator, .Cnst, 3),
				m.make_instructions(context.temp_allocator, .Sub),
				m.make_instructions(context.temp_allocator, .Cnst, 4),
				m.make_instructions(context.temp_allocator, .Cnst, 5),
				m.make_instructions(context.temp_allocator, .Mul),
				m.make_instructions(context.temp_allocator, .Arr, 3),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
	}

	defer free_all(context.temp_allocator)

	run_compiler_tests(t, tests[:])
}

@(test)
test_compile_hash_table_literals :: proc(t: ^testing.T) {
	tests := [?]Compiler_Test_Case {
		{
			"{}",
			{},
			{
				m.make_instructions(context.temp_allocator, .Ht, 0),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			`{"name": "Navid", "index": 1}`,
			{"name", "Navid", "index", 1},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Cnst, 2),
				m.make_instructions(context.temp_allocator, .Cnst, 3),
				m.make_instructions(context.temp_allocator, .Ht, 4),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			`{"navid": 1 + 2, "bob": 3 * 4}`,
			{"navid", 1, 2, "bob", 3, 4},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Cnst, 2),
				m.make_instructions(context.temp_allocator, .Add),
				m.make_instructions(context.temp_allocator, .Cnst, 3),
				m.make_instructions(context.temp_allocator, .Cnst, 4),
				m.make_instructions(context.temp_allocator, .Cnst, 5),
				m.make_instructions(context.temp_allocator, .Mul),
				m.make_instructions(context.temp_allocator, .Ht, 4),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
	}

	defer free_all(context.temp_allocator)

	run_compiler_tests(t, tests[:])
}

@(test)
test_compile_index_expressions :: proc(t: ^testing.T) {
	tests := [?]Compiler_Test_Case {
		{
			"[1, 2, 3][1 + 1]",
			{1, 2, 3, 1, 1},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Cnst, 2),
				m.make_instructions(context.temp_allocator, .Arr, 3),
				m.make_instructions(context.temp_allocator, .Cnst, 3),
				m.make_instructions(context.temp_allocator, .Cnst, 4),
				m.make_instructions(context.temp_allocator, .Add),
				m.make_instructions(context.temp_allocator, .Idx),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			`{"name": "Navid"}["name"]`,
			{"name", "Navid", "name"},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Ht, 2),
				m.make_instructions(context.temp_allocator, .Cnst, 2),
				m.make_instructions(context.temp_allocator, .Idx),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
	}

	defer free_all(context.temp_allocator)

	run_compiler_tests(t, tests[:])
}

@(test)
test_compile_functions :: proc(t: ^testing.T) {
	tests := [?]Compiler_Test_Case {
		{
			"fn () { return 5 + 10 }",
			{
				5,
				10,
				[]m.Instructions {
					m.make_instructions(context.temp_allocator, .Cnst, 0),
					m.make_instructions(context.temp_allocator, .Cnst, 1),
					m.make_instructions(context.temp_allocator, .Add),
					m.make_instructions(context.temp_allocator, .Ret_V),
				},
			},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 2),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"fn () { 5 + 10 }",
			{
				5,
				10,
				[]m.Instructions {
					m.make_instructions(context.temp_allocator, .Cnst, 0),
					m.make_instructions(context.temp_allocator, .Cnst, 1),
					m.make_instructions(context.temp_allocator, .Add),
					m.make_instructions(context.temp_allocator, .Ret_V),
				},
			},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 2),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"fn () { 1; 2 }",
			{
				1,
				2,
				[]m.Instructions {
					m.make_instructions(context.temp_allocator, .Cnst, 0),
					m.make_instructions(context.temp_allocator, .Pop),
					m.make_instructions(context.temp_allocator, .Cnst, 1),
					m.make_instructions(context.temp_allocator, .Ret_V),
				},
			},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 2),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"fn () { }",
			{[]m.Instructions{m.make_instructions(context.temp_allocator, .Ret)}},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
	}

	defer free_all(context.temp_allocator)

	run_compiler_tests(t, tests[:])
}

@(test)
test_compile_function_calls :: proc(t: ^testing.T) {
	tests := [?]Compiler_Test_Case {
		{
			"fn () { 24 }();",
			{
				24,
				[]m.Instructions {
					m.make_instructions(context.temp_allocator, .Cnst, 0), // the literal "24"
					m.make_instructions(context.temp_allocator, .Ret_V),
				},
			},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 1), // the compiled function
				m.make_instructions(context.temp_allocator, .Call, 0),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"let no_arg = fn () { 24 }; no_arg();",
			{
				24,
				[]m.Instructions {
					m.make_instructions(context.temp_allocator, .Cnst, 0), // the literal "24"
					m.make_instructions(context.temp_allocator, .Ret_V),
				},
			},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 1), // the compiled function
				m.make_instructions(context.temp_allocator, .Set_G, 0),
				m.make_instructions(context.temp_allocator, .Get_G, 0),
				m.make_instructions(context.temp_allocator, .Call, 0),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"let one_arg = fn (a) { a }; one_arg(24);",
			{
				[]m.Instructions {
					m.make_instructions(context.temp_allocator, .Get_L, 0),
					m.make_instructions(context.temp_allocator, .Ret_V),
				},
				24,
			},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Set_G, 0),
				m.make_instructions(context.temp_allocator, .Get_G, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Call, 1),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"let many_args = fn (a, b, c) { a; b; c }; many_args(24, 25, 26);",
			{
				[]m.Instructions {
					m.make_instructions(context.temp_allocator, .Get_L, 0),
					m.make_instructions(context.temp_allocator, .Pop),
					m.make_instructions(context.temp_allocator, .Get_L, 1),
					m.make_instructions(context.temp_allocator, .Pop),
					m.make_instructions(context.temp_allocator, .Get_L, 2),
					m.make_instructions(context.temp_allocator, .Ret_V),
				},
				24,
				25,
				26,
			},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Set_G, 0),
				m.make_instructions(context.temp_allocator, .Get_G, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Cnst, 2),
				m.make_instructions(context.temp_allocator, .Cnst, 3),
				m.make_instructions(context.temp_allocator, .Call, 3),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
	}

	defer free_all(context.temp_allocator)

	run_compiler_tests(t, tests[:])
}

@(test)
test_compile_let_statements_scopes :: proc(t: ^testing.T) {
	tests := [?]Compiler_Test_Case {
		{
			"let num = 55; fn() { num };",
			{
				55,
				[]m.Instructions {
					m.make_instructions(context.temp_allocator, .Get_G, 0),
					m.make_instructions(context.temp_allocator, .Ret_V),
				},
			},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 0),
				m.make_instructions(context.temp_allocator, .Set_G, 0),
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"fn() { let num = 55; num }",
			{
				55,
				[]m.Instructions {
					m.make_instructions(context.temp_allocator, .Cnst, 0),
					m.make_instructions(context.temp_allocator, .Set_L, 0),
					m.make_instructions(context.temp_allocator, .Get_L, 0),
					m.make_instructions(context.temp_allocator, .Ret_V),
				},
			},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 1),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"fn() { let a = 55; let b = 77; a + b }",
			{
				55,
				77,
				[]m.Instructions {
					m.make_instructions(context.temp_allocator, .Cnst, 0),
					m.make_instructions(context.temp_allocator, .Set_L, 0),
					m.make_instructions(context.temp_allocator, .Cnst, 1),
					m.make_instructions(context.temp_allocator, .Set_L, 1),
					m.make_instructions(context.temp_allocator, .Get_L, 0),
					m.make_instructions(context.temp_allocator, .Get_L, 1),
					m.make_instructions(context.temp_allocator, .Add),
					m.make_instructions(context.temp_allocator, .Ret_V),
				},
			},
			{
				m.make_instructions(context.temp_allocator, .Cnst, 2),
				m.make_instructions(context.temp_allocator, .Pop),
			},
		},
	}

	defer free_all(context.temp_allocator)

	run_compiler_tests(t, tests[:])
}

@(test)
test_compile_compilation_scopes :: proc(t: ^testing.T) {
	compiler_state := m.compiler_state()
	compiler_state->init()
	defer compiler_state->free()

	compiler := m.compiler()
	compiler->init(&compiler_state)
	defer compiler->mem_free()

	if compiler.scope_index != 0 {
		log.errorf("scope_index is wrong. wants='%d', got='%d'", 0, compiler.scope_index)
		return
	}

	compiler->emit(.Mul)

	compiler->enter_scope()
	if compiler.scope_index != 1 {
		log.errorf("scope_index is wrong. wants='%d', got='%d'", 1, compiler.scope_index)
		return
	}

	compiler->emit(.Sub)

	if len(compiler.scopes[compiler.scope_index].instructions) != 1 {
		log.errorf(
			"instructions length is wrong. got='%d'",
			len(compiler.scopes[compiler.scope_index].instructions),
		)
		return
	}

	last := compiler.scopes[compiler.scope_index].last_instruction
	if last.op_code != .Sub {
		log.errorf(
			"last instruction's op code is wrong. wants='%v', got='%v'",
			m.Opcode.Sub,
			last.op_code,
		)
		return
	}

	if compiler.symbol_table.outer != &compiler.compiler_state.symbol_table {
		log.errorf("compiler did not enclose symbol table")
	}

	compiler->leave_scope()
	if compiler.scope_index != 0 {
		log.errorf("scope_index is wrong. wants='%d', got='%d'", 0, compiler.scope_index)
		return
	}

	if compiler.symbol_table != &compiler.compiler_state.symbol_table {
		log.errorf("compiler did not restore global symbol table")
	}

	if compiler.symbol_table.outer != nil {
		log.errorf("compiler modified global symbol table incorrectly")
	}

	compiler->emit(.Add)

	if len(compiler.scopes[compiler.scope_index].instructions) != 2 {
		log.errorf(
			"instructions length is wrong. got='%d'",
			len(compiler.scopes[compiler.scope_index].instructions),
		)
		return
	}

	last = compiler.scopes[compiler.scope_index].last_instruction
	if last.op_code != .Add {
		log.errorf(
			"last instruction's op code is wrong. wants='%v', got='%v'",
			m.Opcode.Add,
			last.op_code,
		)
		return
	}

	previous := compiler.scopes[compiler.scope_index].previous_instruction
	if previous.op_code != .Mul {
		log.errorf(
			"previous instructions's op code is wrong. wants='%v', got='%v'",
			m.Opcode.Mul,
			previous.op_code,
		)
	}
}
