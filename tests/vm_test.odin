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
			defer compiler->mem_free()

			err := compiler->compile(program)
			if err != "" {
				log.errorf("test[%d] has failed, compiler has error: %s", i, err)
				testing.fail(t)
				continue
			}

			vm := m.vm()
			vm->config(compiler->bytecode())
			defer vm->mem_free()

			err = vm->run()
			if err != "" {
				log.errorf("test[%d] has failed, vm has error: %s", i, err)
				testing.fail(t)
				continue
			}

			stack_elem := vm->stack_top()
			err = test_expected_object(test_case.expected, stack_elem)
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
	tests := []VM_Test_Case{{"1", 1}, {"2", 2}, {"1 + 2", 2}}

	defer free_all(context.temp_allocator)

	run_vm_tests(t, tests)
}
