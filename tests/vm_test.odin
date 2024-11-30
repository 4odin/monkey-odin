package monkey_tests

import "core:fmt"
import "core:log"
import "core:reflect"

import m "../monkey"

import "core:testing"

VM_Test_Case :: struct {
	input:    string,
	expected: any,
}

test_expected_object :: proc(expected: any, actual: m.Object_Base) -> (err: string) {
	_, t := reflect.any_data(expected)
	switch t {
	case int:
		expected_value, _ := reflect.as_int(expected)
		err = test_integer_object(expected_value, actual)
		if err != "" {
			return fmt.tprintf("test_integer_object failed with: %s", err)
		}

	case bool:
		expected_value, _ := reflect.as_bool(expected)
		err = test_boolean_object(expected_value, actual)
		if err != "" {
			return fmt.tprintf("test_boolean_object failed with: %s", err)
		}

	case nil:
		if m.obj_type(actual) != m.Obj_Null {
			return fmt.tprintf("object is not Obj_Null, got='%v'", m.obj_type(actual))
		}
	}

	return ""
}

run_vm_tests :: proc(t: ^testing.T, tests: []VM_Test_Case) {
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

			vm := m.vm()
			vm->config()
			defer vm->mem_free()

			err = vm->run(compiler->bytecode())
			if err != "" {
				log.errorf("test[%d] has failed, vm has error: %s", i, err)
				testing.fail(t)
				continue
			}

			last_popped_stack_elem := vm->last_popped_stack_elem()
			err = test_expected_object(test_case.expected, last_popped_stack_elem)
			if err != "" {
				log.errorf(
					"test[%d] has failed, test expected stack top has failed with: %s",
					i,
					err,
				)
				testing.fail(t)
			}
		}
	}
}

@(test)
test_vm_integer_arithmetic :: proc(t: ^testing.T) {
	tests := []VM_Test_Case {
		{"1", 1},
		{"2", 2},
		{"-5", -5},
		{"1 + 2", 3},
		{"3 - 1", 2},
		{"2 * 2", 4},
		{"4 / 2", 2},
		{"5 + 5 + 5 + 5 - 10", 10},
		{"2 * 2 * 2 * 2 * 2", 32},
		{"5 * 2 + 10", 20},
		{"5 + 2 * 10", 25},
		{"5 * (2 + 10)", 60},
		{"-50 + 100 + -50", 0},
	}

	defer free_all(context.temp_allocator)

	run_vm_tests(t, tests)
}

@(test)
test_vm_boolean_expression :: proc(t: ^testing.T) {
	tests := []VM_Test_Case {
		{"true", true},
		{"false", false},
		{"!true", false},
		{"!false", true},
		{"1 < 2", true},
		{"1 > 2", false},
		{"1 < 1", false},
		{"1 > 1", false},
		{"1 == 1", true},
		{"1 != 1", false},
		{"1 == 2", false},
		{"1 != 2", true},
		{"true == true", true},
		{"false == false", true},
		{"true == false", false},
		{"true != false", true},
		{"false != true", true},
		{"(1 < 2) == true", true},
		{"(1 < 2) == false", false},
		{"(1 > 2) == true", false},
		{"(1 > 2) == false", true},
		{"!5", false},
		{"!!true", true},
		{"!!5", true},
		{"!(if false { 5; })", true},
	}

	defer free_all(context.temp_allocator)

	run_vm_tests(t, tests)
}

@(test)
test_vm_if_expression :: proc(t: ^testing.T) {
	tests := []VM_Test_Case {
		{"if true { 10 }", 10},
		{"if false { 10 }", nil},
		{"if 1 > 2 { 10 }", nil},
		{"if true { 10 } else { 20 }", 10},
		{"if false { 10 } else { 20 }", 20},
		{"if 1 { 10 }", 10},
		{"if 1 < 2 { 10 }", 10},
		{"if 1 < 2 { 10 } else { 20 }", 10},
		{"if 1 > 2 { 10 } else { 20 }", 20},
		{"if (if false { 10 }) { 10 } else { 20 }", 20},
	}

	defer free_all(context.temp_allocator)

	run_vm_tests(t, tests)
}

@(test)
test_vm_global_let_statement :: proc(t: ^testing.T) {
	tests := []VM_Test_Case {
		{"let one = 1; one", 1},
		{"let one = 1; let two = 2; one + two", 3},
		{"let one = 1; let two = one + one; one + two", 3},
	}

	defer free_all(context.temp_allocator)

	run_vm_tests(t, tests)
}
