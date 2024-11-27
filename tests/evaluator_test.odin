package tests

import ma "../ast"
import me "../evaluator"
import mp "../parser"

import "core:log"
import st "core:strings"
import "core:testing"

_ :: st
_ :: ma

evaluate_is_valid_get_evaluator :: proc(
	input: string,
	print_errors := true,
) -> (
	me.Object_Base,
	^me.Evaluator,
	bool,
) {
	p := mp.parser()
	p->config()
	defer p->free()

	program := p->parse(input)
	if len(p.errors) > 0 {
		if print_errors do for err in p.errors do log.errorf("parser error: %s", err)

		return nil, nil, false
	}

	e := new_clone(me.evaluator())
	e->config()

	evaluated, ok := e->eval(program, context.temp_allocator)
	if !ok {
		if print_errors do log.errorf("evaluator error: %s", evaluated)

		e->free()
		free(e)

		return nil, nil, false
	}

	return evaluated, e, true
}

evalulation_is_valid :: proc(input: string, print_errors := true) -> (me.Object_Base, bool) {

	evaluated, e, ok := evaluate_is_valid_get_evaluator(input, print_errors)

	defer if ok {
		e->free()
		free(e)
	}

	return evaluated, ok
}

integer_object_is_valid :: proc(obj: me.Object_Base, expected: int) -> bool {
	result, ok := obj.(int)
	if !ok {
		log.errorf("object is not integer, got='%v'", me.obj_type(obj))
		return false
	}

	if result != expected {
		log.errorf("object has wrong value. got='%d', expected='%d'", result, expected)
		return false
	}

	return true
}

boolean_object_is_valid :: proc(obj: me.Object_Base, expected: bool) -> bool {
	result, ok := obj.(bool)
	if !ok {
		log.errorf("object is not boolean, got='%v'", me.obj_type(obj))
		return false
	}

	if result != expected {
		log.errorf("object has wrong value. got='%d', expected='%d'", result, expected)
		return false
	}

	return true
}

string_object_is_valid :: proc(obj: me.Object_Base, expected: string) -> bool {
	result, ok := obj.(string)
	if !ok {
		log.errorf("object is not string, got='%v'", me.obj_type(obj))
		return false
	}

	if result != expected {
		log.errorf("object has wrong value. got='%s', expected='%s'", result, expected)
		return false
	}

	return true
}

@(test)
test_eval_integer_expression :: proc(t: ^testing.T) {
	tests := [?]struct {
		input:    string,
		expected: int,
	} {
		{"5", 5},
		{"10", 10},
		{"-5", -5},
		{"-10", -10},
		{"5 + 5 + 5 + 5 - 10", 10},
		{"2 * 2 * 2 * 2 * 2", 32},
		{"-50 + 100 + -50", 0},
		{"5 * 2 + 10", 20},
		{"5 + 2 * 10", 25},
		{"20 + 2 * -10", 0},
		{"50 / 2 * 2 + 10", 60},
		{"2 * (5 + 10)", 30},
		{"3 * 3 * 3 + 10", 37},
		{"3 * (3 * 3) + 10", 37},
		{"(5 + 10 * 2 + 15 / 3) * 2 + -10", 50},
	}

	for test_case, i in tests {
		evaluated, ok := evalulation_is_valid(test_case.input)
		if !ok {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
			continue
		}

		if !integer_object_is_valid(evaluated, test_case.expected) {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
		}
	}
}

@(test)
test_eval_boolean_expression :: proc(t: ^testing.T) {
	tests := [?]struct {
		input:    string,
		expected: bool,
	} {
		{"true", true},
		{"false", false},
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
	}

	for test_case, i in tests {
		evaluated, ok := evalulation_is_valid(test_case.input)
		if !ok {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
			continue
		}

		if !boolean_object_is_valid(evaluated, test_case.expected) {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
		}
	}
}

@(test)
test_eval_string_expression :: proc(t: ^testing.T) {
	tests := [?]struct {
		input:    string,
		expected: string,
	}{{`"Hello World"`, "Hello World"}, {`"Hello" + " " + "World"`, "Hello World"}}

	for test_case, i in tests {
		evaluated, ok := evalulation_is_valid(test_case.input)
		if !ok {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
			continue
		}

		if !string_object_is_valid(evaluated, test_case.expected) {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
		}
	}
}

@(test)
test_eval_bang_operator :: proc(t: ^testing.T) {
	tests := [?]struct {
		input:    string,
		expected: bool,
	} {
		{"!true", false},
		{"!false", true},
		{"!5", false},
		{"!!true", true},
		{"!!false", false},
		{"!!5", true},
	}

	for test_case, i in tests {
		evaluated, ok := evalulation_is_valid(test_case.input)
		if !ok {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
			continue
		}

		if !boolean_object_is_valid(evaluated, test_case.expected) {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
		}
	}
}

@(test)
test_eval_if_else_expression :: proc(t: ^testing.T) {
	NULL :: me.Obj_Null{}

	tests := []struct {
		input:    string,
		expected: me.Object_Base,
	} {
		{"if true { 10 }", 10},
		{"if false { 10 }", NULL},
		{"if 1 { 10 }", 10},
		{"if 1 < 2 { 10 }", 10},
		{"if 1 > 2 { 10 }", NULL},
		{"if 1 > 2 { 10 } else { 20 }", 20},
		{"if 1 < 2 { 10 } else { 20 }", 10},
	}

	for test_case, i in tests {
		evaluated, ok := evalulation_is_valid(test_case.input)
		if !ok {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
			continue
		}

		#partial switch expected in test_case.expected {
		case int:
			if !integer_object_is_valid(evaluated, expected) {
				log.errorf("test[%d] has failed", i)
				testing.fail(t)
			}

		case me.Obj_Null:
			if me.obj_type(evaluated) != me.Obj_Null {
				log.errorf("object is not Obj_Null, got='%v'", me.obj_type(evaluated))
				log.errorf("test[%d] has failed", i)
				testing.fail(t)
			}
		}
	}
}

@(test)
test_eval_return_statement :: proc(t: ^testing.T) {
	tests := [?]struct {
		input:    string,
		expected: int,
	} {
		{"return 10;", 10},
		{"return 10; 9;", 10},
		{"return 2 * 5; 9;", 10},
		{"9; return 2 * 5; 9;", 10},
		{
			`
    if 10 > 1 {
        if 10 > 1 {
            return 10;
        }

        return 1;
    }`,
			10,
		},
	}

	for test_case, i in tests {
		evaluated, ok := evalulation_is_valid(test_case.input)
		if !ok {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
			continue
		}

		if !integer_object_is_valid(evaluated, test_case.expected) {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
		}
	}
}

@(test)
test_eval_let_statements :: proc(t: ^testing.T) {
	tests := [?]struct {
		input:    string,
		expected: int,
	} {
		{"let a = 5; a;", 5},
		{"let a = 5 * 5; a;", 25},
		{"let a = 5; let b = a; b;", 5},
		{"let a = 5; let b = a; let c = a + b + 5; c;", 15},
	}

	for test_case, i in tests {
		evaluated, ok := evalulation_is_valid(test_case.input)
		if !ok {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
			continue
		}

		if !integer_object_is_valid(evaluated, test_case.expected) {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
		}
	}
}

@(test)
test_eval_function_object :: proc(t: ^testing.T) {
	input := "fn(x) { x + 2 };"

	evaluated, e, ok := evaluate_is_valid_get_evaluator(input)
	defer if ok {
		e->free()
		free(e)
	}

	if !ok {
		testing.fail(t)
		return
	}

	fn, is_fn := evaluated.(^me.Obj_Function)
	if !is_fn {
		log.errorf("object is not function. got='%v'", me.obj_type(evaluated))
		testing.fail(t)
		return
	}

	if len(fn.parameters) != 1 {
		log.errorf(
			"function has wrong number of parameters, got='%d', '%v'",
			len(fn.parameters),
			fn.parameters,
		)
		testing.fail(t)
		return
	}

	if fn.parameters[0].value != "x" {
		log.errorf("function's parameter is not 'x', got='%s'", fn.parameters[0])
		testing.fail(t)
		return
	}

	expected_body := "{ (x+2) }"

	sb := st.builder_make(context.temp_allocator)
	defer free_all(context.temp_allocator)

	ma.ast_to_string(fn.body, &sb)

	if st.to_string(sb) != expected_body {
		log.errorf(
			"ast_to_string ris not valid, expected='%s', got='%s'",
			expected_body,
			st.to_string(sb),
		)
		testing.fail(t)
	}
}

@(test)
test_eval_function_application :: proc(t: ^testing.T) {
	tests := [?]struct {
		input:    string,
		expected: int,
	} {
		{"let identity = fn(x) { x; }; identity(5);", 5},
		{"let identity = fn(x) { return x; }; identity(5);", 5},
		{"let double = fn(x) { x * 2; }; double(5);", 10},
		{"let add = fn(x, y) { x * y; }; add(5, 5);", 25},
		{"let add = fn(x, y) { x + y; }; add(5 + 5, add(5, 5));", 20},
		{"fn (x) { x; }(5)", 5},
		{`
let new_adder = fn(x) {
	fn(y) {x + y};
};

let add_two = new_adder(2);
add_two(2)`, 4},
	}

	for test_case, i in tests {
		evaluated, ok := evalulation_is_valid(test_case.input)
		if !ok {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
			continue
		}

		if !integer_object_is_valid(evaluated, test_case.expected) {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
		}
	}
}

@(test)
test_eval_builtin_functions :: proc(t: ^testing.T) {
	tests := [?]struct {
		input:    string,
		expected: union {
			int,
			string,
		},
	}{{`len("")`, 0}, {`len("four")`, 4}, {`len("hello world")`, 11}}

	for test_case, i in tests {
		evaluated, ok := evalulation_is_valid(test_case.input)
		if !ok {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
			continue
		}

		switch expected in test_case.expected {
		case int:
			if !integer_object_is_valid(evaluated, expected) {
				log.errorf("test[%d] has failed", i)
				testing.fail(t)
			}

		case string:
			if !string_object_is_valid(evaluated, expected) {
				log.errorf("test[%d] has failed", i)
				testing.fail(t)
			}
		}

	}
}

@(test)
test_eval_array_literals :: proc(t: ^testing.T) {
	input := "[1, 2 * 2, 3 + 3]"

	evaluated, e, ok := evaluate_is_valid_get_evaluator(input)
	defer if ok {
		e->free()
		free(e)
	}

	if !ok {
		testing.fail(t)
		return
	}

	arr, is_arr := evaluated.(^me.Obj_Array)
	if !is_arr {
		log.errorf("expected array object but got '%v'", me.obj_type(evaluated))
		testing.fail(t)
		return
	}

	if len(arr) != 3 {
		log.errorf("expected array length to be 3 but got='%d'", len(arr))
		testing.fail(t)
		return
	}

	if !integer_object_is_valid(arr[0], 1) {
		log.errorf("arr[0] does not match")
		testing.fail(t)
	}

	if !integer_object_is_valid(arr[1], 4) {
		log.errorf("arr[1] does not match")
		testing.fail(t)
	}

	if !integer_object_is_valid(arr[2], 6) {
		log.errorf("arr[2] does not match")
		testing.fail(t)
	}
}

@(test)
test_eval_hash_literals :: proc(t: ^testing.T) {
	input := `
    {
        "one": 10 - 9,
        "two": 1 + 1,
        "three": 6 / 2,
    }`


	evaluated, e, ok := evaluate_is_valid_get_evaluator(input)
	defer if ok {
		e->free()
		free(e)
	}

	if !ok {
		testing.fail(t)
		return
	}

	ht, is_hash_table := evaluated.(^me.Obj_Hash_Table)
	if !is_hash_table {
		log.errorf("expected hash table object but got '%v'", me.obj_type(evaluated))
		testing.fail(t)
		return
	}

	expected := map[string]int {
		"one"   = 1,
		"two"   = 2,
		"three" = 3,
	}
	defer delete(expected)

	if len(ht) != len(expected) {
		log.errorf(
			"Hash table has wrong number of pairs, expected='%d', got='%d'",
			len(expected),
			len(ht),
		)
		testing.fail(t)
		return
	}

	for expected_key, expected_value in expected {
		value, key_exists := ht[expected_key]
		if !key_exists {
			log.errorf("key '%v' expected but does not exist", expected_key)
			testing.fail(t)
			continue
		}

		if !integer_object_is_valid(value, expected_value) {
			testing.fail(t)
		}
	}
}

@(test)
test_eval_array_index_expression :: proc(t: ^testing.T) {
	tests := [?]struct {
		input:    string,
		expected: int,
	} {
		{"[1, 2, 3][0]", 1},
		{"[1, 2, 3][1]", 2},
		{"[1, 2, 3][2]", 3},
		{"let i = 0; [1][i]", 1},
		{"[1, 2, 3][1 + 1];", 3},
		{"let my_arr = [1, 2, 3]; my_arr[2]", 3},
		{"let my_arr = [1, 2, 3]; my_arr[0] + my_arr[1] + my_arr[2];", 6},
		{"let my_arr = [1, 2, 3]; let i = my_arr[0]; my_arr[i]", 2},
	}

	for test_case, i in tests {
		evaluated, ok := evalulation_is_valid(test_case.input)
		if !ok {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
			continue
		}

		if !integer_object_is_valid(evaluated, test_case.expected) {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
		}
	}
}

@(test)
test_eval_hash_table_index_expression :: proc(t: ^testing.T) {
	tests := [?]struct {
		input:    string,
		expected: int,
	}{{`{"foo": 5}["foo"]`, 5}, {`let key = "foo"; {"foo": 5}[key]`, 5}}

	for test_case, i in tests {
		evaluated, ok := evalulation_is_valid(test_case.input)
		if !ok {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
			continue
		}

		if !integer_object_is_valid(evaluated, test_case.expected) {
			log.errorf("test[%d] has failed", i)
			testing.fail(t)
		}
	}
}

@(test)
test_eval_errors :: proc(t: ^testing.T) {
	inputs := [?]string {
		"5 + true;",
		"5 + true; 5;",
		"-true",
		"true+false;",
		`"Hello" - "World"`,
		"5; true + false; 5",
		"if 10 > 1 {true + false;}",
		`if 10 > 1 {
                if 10 > 1 {
                    return true + false;
                }

                return 1;
            }`,
		"foobar", // does not exist
		"let a = 12; let a = true;", // already exists
		"let f = fn(x) {}; f()", // wrong number of arguments
		"let f = fn(x,y) {}; f(1)", // wrong number of arguments
		"let f 2", // parser error also must be caught
		"len(1)", // wrong arg type for builtin function
		`len("one", "two")`, // wrong number of arguments for builtin function
		"[1, 2, 3][3]", // index out of boundary
		"[1, 2, 3][-1]", // index out of boundary
		`{"foo": 5}["bar"]`, // key does not exists
		`{}["bar"]`, // key does not exists
		`{}[1]`, // key is not hashable
	}


	for input, i in inputs {
		_, ok := evalulation_is_valid(input, false)
		if ok {
			log.errorf("test[%d] has failed, should not be ok", i)
			testing.fail(t)
			continue
		}
	}
}
