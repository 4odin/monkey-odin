package monkey_tests

import "core:fmt"
import "core:log"
import "core:reflect"

import m "../monkey"

import "core:testing"

@(private = "file")
VM_Test_Union :: union {
	int,
	bool,
	string,
	[]int,
	map[string]int,
}

VM_Test_Case :: struct {
	input:    string,
	expected: VM_Test_Union,
}

test_expected_object :: proc(expected: VM_Test_Union, actual: m.Object_Base) -> (err: string) {
	err = ""
	t := reflect.union_variant_typeid(expected)
	switch expected_value in expected {
	case int:
		err = test_integer_object(expected_value, actual)

	case bool:
		err = test_boolean_object(expected_value, actual)

	case string:
		err = test_string_object(expected_value, actual)

	case []int:
		arr, ok := actual.(^m.Obj_Array)
		if !ok {
			err = fmt.tprintf("object is not array, got='%v'", m.obj_type(actual))
			break
		}

		if len(arr) != len(expected_value) {
			err = fmt.tprintf(
				"wrong num of elements. want='%d', got='%d'",
				len(expected_value),
				len(arr),
			)
			break
		}

		for expected_el, i in expected_value {
			if err = test_integer_object(expected_el, arr[i]); err != "" do break
		}

	case map[string]int:
		ht, ok := actual.(^m.Obj_Hash_Table)
		if !ok {
			err = fmt.tprintf("object is not hash table, got='%v'", m.obj_type(actual))
			break
		}

		if len(ht) != len(expected_value) {
			err = fmt.tprintf(
				"wrong num of pairs. want='%d', got='%d'",
				len(expected_value),
				len(ht),
			)
			break
		}

		for key, value in expected_value {
			actual_value, key_exists := ht[key]
			if !key_exists {
				err = fmt.tprintf("key '%s' does not exists in the hash table", key)
				break
			}

			if err = test_integer_object(value, actual_value); err != "" do break
		}

	case nil:
		if m.obj_type(actual) != m.Obj_Null {
			err = fmt.tprintf("object is not Obj_Null, got='%v'", m.obj_type(actual))
		}
	}

	if err != "" {
		err = fmt.tprintf("test_expected_object on '%v' failed with: %s", t, err)
	}

	return
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
test_vm_boolean_expressions :: proc(t: ^testing.T) {
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
test_vm_if_expressions :: proc(t: ^testing.T) {
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

@(test)
test_vm_string_expressions :: proc(t: ^testing.T) {
	tests := []VM_Test_Case {
		{`"monkey`, "monkey"},
		{`"mon" + "key"`, "monkey"},
		{`"mon" + "key" + "banana"`, "monkeybanana"},
	}

	defer free_all(context.temp_allocator)

	run_vm_tests(t, tests)
}

@(test)
test_vm_array_literals :: proc(t: ^testing.T) {
	tests := []VM_Test_Case {
		{"[]", []int{}},
		{"[1, 2, 3]", []int{1, 2, 3}},
		{"[1 + 2, 3 * 4, 5 + 6]", []int{3, 12, 11}},
	}

	defer free_all(context.temp_allocator)

	run_vm_tests(t, tests)
}

@(test)
test_vm_hash_table_literals :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	tests := []VM_Test_Case {
		{"{}", map[string]int{}},
		{`{"navid": 1, "bob": 2}`, map[string]int{"navid" = 1, "bob" = 2}},
		{`{"navid": 2 * 2, "bob":  4 + 4}`, map[string]int{"navid" = 4, "bob" = 8}},
	}

	defer free_all(context.temp_allocator)

	run_vm_tests(t, tests)
}

@(test)
test_vm_index_expressios :: proc(t: ^testing.T) {
	tests := []VM_Test_Case {
		{"[1, 2, 3][1]", 2},
		{"[1, 2, 3][0 + 2]", 3},
		{"[[1, 1, 1]][0][0]", 1},
		{"[][0]", nil},
		{"[1, 2, 3][99]", nil},
		{"[1][-1]", nil},
		{`{"name": "Navid"}["name"]`, "Navid"},
		{`{"name": "Navid"}["age"]`, nil},
		{`{}["name"]`, nil},
	}

	defer free_all(context.temp_allocator)

	run_vm_tests(t, tests)
}
