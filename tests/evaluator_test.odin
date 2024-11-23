package tests

import me "../evaluator"
import mp "../parser"

import "core:log"
// import st "core:strings"
import "core:testing"

evalulation_is_valid :: proc(input: string) -> (me.Object, bool) {
	e := me.evaluator()
	p := mp.parser()
	p->config()

	defer free_all(context.temp_allocator)
	defer p->free()

	program := p->parse(input)
	if len(p.errors) > 0 {
		for err in p.errors do log.errorf("parser error: %s", err)

		return nil, false
	}

	return e->eval(program), true
}

integer_object_is_valid :: proc(obj: me.Object, expected: int) -> bool {
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

boolean_object_is_valid :: proc(obj: me.Object, expected: bool) -> bool {
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