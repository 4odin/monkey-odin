package tests

import "core:fmt"
import "core:log"
import "core:reflect"

import me "../evaluator"
import mp "../parser"
import mv "../vm"

import "core:testing"

Compiler_Test_Case :: struct {
	input:                 string,
	expected_constants:    []any,
	expected_instructions: []mv.Instructions,
}

test_integer_object :: proc(expected: int, actual: me.Object_Base) -> (err: string) {
	result, ok := actual.(int)
	if !ok {
		return fmt.tprintf("object is not integer. got='%v'", me.obj_type(actual))
	}

	if result != expected {
		return fmt.tprintf("object has wrong value. wants='%d', got='%d'", expected, result)
	}

	return ""
}

test_constants :: proc(expected: []any, actual: []me.Object_Base) -> (err: string) {
	if len(expected) != len(actual) {
		return fmt.tprintf(
			"wrong number of constants. wants='%d', got='%d'",
			len(expected),
			len(actual),
		)
	}

	for constant, i in expected {
		_, t := reflect.any_data(constant)
		switch t {
		case int:
			constant_value, _ := reflect.as_int(constant)
			err = test_integer_object(constant_value, actual[i])
			if err != "" {
				return fmt.tprintf("constant '%d' - test_integer_object failed with: %s", i, err)
			}
		}
	}

	return ""
}

test_instructions :: proc(expected: []mv.Instructions, actual: mv.Instructions) -> (err: string) {
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
			p := mp.parser()
			p->config()
			defer p->free()

			program := p->parse(test_case.input)
			if len(p.errors) > 0 {
				for err in p.errors do log.errorf("test[%d] has failed, parser error: %s", i, err)

				testing.fail(t)
				continue
			}

			compiler := mv.compiler()
			err := compiler->compile(program)
			if err != "" {
				log.errorf("test[%d] has failed, compiler has error: %s", i, err)
				testing.fail(t)
				continue
			}

			bytecode := compiler->bytecode()

			err = test_instructions(test_case.expected_instructions[:], bytecode.instructions[:])
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
			"1 + 2",
			{1, 2},
			{
				mv.instruction_make(context.temp_allocator, .Constant, 0),
				mv.instruction_make(context.temp_allocator, .Constant, 0),
			},
		},
	}

	defer free_all(context.temp_allocator)

	run_compiler_tests(t, tests[:])
}
