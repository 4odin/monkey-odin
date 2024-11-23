package tests

import me "../evaluator"
import mp "../parser"

import "core:log"
import "core:testing"

evalulation_is_valid :: proc(input: string, print_errors := true) -> (me.Object_Base, bool) {
	p := mp.parser()
	p->config()
	defer p->free()

	e := me.evaluator()
	e->config()
	defer e->free()

	defer free_all(context.temp_allocator)

	program := p->parse(input)
	if len(p.errors) > 0 {
		for err in p.errors do log.errorf("parser error: %s", err)

		return nil, false
	}

	evaluated, ok := e->eval(program)
	if !ok {
		if print_errors do log.errorf("evaluator error: %s", evaluated)
		return "", false
	}

	return evaluated, true
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
	NULL :: me.Null{}

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

		case me.Null:
			if me.obj_type(evaluated) != me.Null {
				log.errorf("object is not Null, got='%v'", me.obj_type(evaluated))
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
test_eval_errors :: proc(t: ^testing.T) {
	inputs := [?]string {
		"5 + true;",
		"5 + true; 5;",
		"-true",
		"true+false;",
		"5; true + false; 5",
		"if 10 > 1 {true + false;}",
		`if 10 > 1 {
                if 10 > 1 {
                    return true + false;
                }

                return 1;
            }`,
		"foobar", // does not exist
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
