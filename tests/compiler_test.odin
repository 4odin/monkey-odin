package monkey_tests

import "core:fmt"
import "core:log"
import "core:reflect"

import m "../monkey"

import "core:testing"

Compiler_Test_Case :: struct {
	input:                 string,
	expected_constants:    []any,
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

test_constants :: proc(expected: []any, actual: []m.Object_Base) -> (err: string) {
	if len(expected) != len(actual) {
		return fmt.tprintf(
			"wrong number of constants. wants='%d', got='%d'",
			len(expected),
			len(actual),
		)
	}

	for constant, i in expected {
		_, t := reflect.any_data(constant)
		err = ""
		switch t {
		case int:
			constant_value, _ := reflect.as_int(constant)
			err = test_integer_object(constant_value, actual[i])

		case string:
			constant_value, _ := reflect.as_string(constant)
			err = test_string_object(constant_value, actual[i])
		}

		if err != "" {
			return fmt.tprintf("constant '%d' - testing '%s' object failed with: %v", t, i, err)
		}
	}

	return ""
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
			p->config()
			defer p->mem_free()

			program := p->parse(test_case.input)
			if len(p.errors) > 0 {
				for err in p.errors do log.errorf("test[%d] has failed, parser error: %s", i, err)

				testing.fail(t)
				continue
			}

			compiler := m.compiler()
			compiler->config()
			defer compiler->free()

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
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Pop),
				m.instructions(context.temp_allocator, .Cnst, 1),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"-1",
			{1},
			{
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Neg),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"1 + 2",
			{1, 2},
			{
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Cnst, 1),
				m.instructions(context.temp_allocator, .Add),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"1 - 2",
			{1, 2},
			{
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Cnst, 1),
				m.instructions(context.temp_allocator, .Sub),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"1 * 2",
			{1, 2},
			{
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Cnst, 1),
				m.instructions(context.temp_allocator, .Mul),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"1 / 2",
			{1, 2},
			{
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Cnst, 1),
				m.instructions(context.temp_allocator, .Div),
				m.instructions(context.temp_allocator, .Pop),
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
				m.instructions(context.temp_allocator, .True),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"false",
			{},
			{
				m.instructions(context.temp_allocator, .False),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"!true",
			{},
			{
				m.instructions(context.temp_allocator, .True),
				m.instructions(context.temp_allocator, .Not),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"1 > 2",
			{1, 2},
			{
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Cnst, 1),
				m.instructions(context.temp_allocator, .Gt),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"1 < 2",
			{2, 1},
			{
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Cnst, 1),
				m.instructions(context.temp_allocator, .Gt),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"1 == 2",
			{1, 2},
			{
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Cnst, 1),
				m.instructions(context.temp_allocator, .Eq),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"1 != 2",
			{1, 2},
			{
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Cnst, 1),
				m.instructions(context.temp_allocator, .Neq),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"true == false",
			{},
			{
				m.instructions(context.temp_allocator, .True),
				m.instructions(context.temp_allocator, .False),
				m.instructions(context.temp_allocator, .Eq),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"true != false",
			{},
			{
				m.instructions(context.temp_allocator, .True),
				m.instructions(context.temp_allocator, .False),
				m.instructions(context.temp_allocator, .Neq),
				m.instructions(context.temp_allocator, .Pop),
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
				m.instructions(context.temp_allocator, .True),
				// 0001
				m.instructions(context.temp_allocator, .Jmp_If_Not, 10),
				// 0004
				m.instructions(context.temp_allocator, .Cnst, 0),
				// 0007
				m.instructions(context.temp_allocator, .Jmp, 11),
				// 0010
				m.instructions(context.temp_allocator, .Nil),
				// 0011
				m.instructions(context.temp_allocator, .Pop),
				// 0012
				m.instructions(context.temp_allocator, .Cnst, 1),
				// 0015
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"if true { 10 } else { 20 }; 3333;",
			{10, 20, 3333},
			{
				// 0000
				m.instructions(context.temp_allocator, .True),
				// 0001
				m.instructions(context.temp_allocator, .Jmp_If_Not, 10),
				// 0004
				m.instructions(context.temp_allocator, .Cnst, 0),
				// 0007
				m.instructions(context.temp_allocator, .Jmp, 13),
				// 0010
				m.instructions(context.temp_allocator, .Cnst, 1),
				// 0013
				m.instructions(context.temp_allocator, .Pop),
				// 0014
				m.instructions(context.temp_allocator, .Cnst, 2),
				// 0017
				m.instructions(context.temp_allocator, .Pop),
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
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Set_G, 0),
				m.instructions(context.temp_allocator, .Cnst, 1),
				m.instructions(context.temp_allocator, .Set_G, 1),
			},
		},
		{
			"let one = 1; one;",
			{1},
			{
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Set_G, 0),
				m.instructions(context.temp_allocator, .Get_G, 0),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"let one = 1; let two = one; two;",
			{1},
			{
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Set_G, 0),
				m.instructions(context.temp_allocator, .Get_G, 0),
				m.instructions(context.temp_allocator, .Set_G, 1),
				m.instructions(context.temp_allocator, .Get_G, 1),
				m.instructions(context.temp_allocator, .Pop),
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
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			`"mon" + "key"`,
			{"mon", "key"},
			{
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Cnst, 1),
				m.instructions(context.temp_allocator, .Add),
				m.instructions(context.temp_allocator, .Pop),
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
				m.instructions(context.temp_allocator, .Arr, 0),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"[1, 2, 3]",
			{1, 2, 3},
			{
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Cnst, 1),
				m.instructions(context.temp_allocator, .Cnst, 2),
				m.instructions(context.temp_allocator, .Arr, 3),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
		{
			"[1 + 2, 3 - 4, 5 * 6]",
			{1, 2, 3, 4, 5, 6},
			{
				m.instructions(context.temp_allocator, .Cnst, 0),
				m.instructions(context.temp_allocator, .Cnst, 1),
				m.instructions(context.temp_allocator, .Add),
				m.instructions(context.temp_allocator, .Cnst, 2),
				m.instructions(context.temp_allocator, .Cnst, 3),
				m.instructions(context.temp_allocator, .Sub),
				m.instructions(context.temp_allocator, .Cnst, 4),
				m.instructions(context.temp_allocator, .Cnst, 5),
				m.instructions(context.temp_allocator, .Mul),
				m.instructions(context.temp_allocator, .Arr, 3),
				m.instructions(context.temp_allocator, .Pop),
			},
		},
	}

	defer free_all(context.temp_allocator)

	run_compiler_tests(t, tests[:])
}
