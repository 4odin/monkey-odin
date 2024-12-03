package monkey_tests

import "core:log"

import m "../monkey"

import "core:testing"

@(test)
test_symbol_table_define :: proc(t: ^testing.T) {
	expected := map[string]m.Symbol {
		"a" = {"a", .Global, 0},
		"b" = {"b", .Global, 1},
		"c" = {"c", .Local, 0},
		"d" = {"d", .Local, 1},
		"e" = {"e", .Local, 0},
		"f" = {"f", .Local, 1},
	}

	defer delete(expected)
	defer free_all(context.temp_allocator)

	global := m.symbol_table(context.temp_allocator)
	defer global->free()

	a := global->define("a")
	if a != expected["a"] {
		log.errorf("expected a='%v', got='%v'", expected["a"], a)
	}

	b := global->define("b")
	if b != expected["b"] {
		log.errorf("expected b='%v', got='%v'", expected["b"], b)
	}

	first_local := m.symbol_table(context.temp_allocator, &global)
	defer first_local->free()

	c := first_local->define("c")
	if c != expected["c"] {
		log.errorf("expected c='%v', got='%v'", expected["c"], c)
	}

	d := first_local->define("d")
	if d != expected["d"] {
		log.errorf("expected d='%v', got='%v'", expected["d"], d)
	}

	second_local := m.symbol_table(context.temp_allocator, &global)
	defer second_local->free()

	e := second_local->define("e")
	if e != expected["e"] {
		log.errorf("expected e='%v', got='%v'", expected["e"], e)
	}

	f := second_local->define("f")
	if f != expected["f"] {
		log.errorf("expected f='%v', got='%v'", expected["f"], f)
	}
}

@(test)
test_symbol_table_resolve_global :: proc(t: ^testing.T) {
	global := m.symbol_table(context.temp_allocator)
	defer global->free()
	defer free_all(context.temp_allocator)

	global->define("a")
	global->define("b")

	expected := [?]m.Symbol{{"a", .Global, 0}, {"b", .Global, 1}}

	for sym in expected {
		result, ok := global->resolve(sym.name)
		if !ok {
			log.errorf("name %s not resolvable", sym.name)
			continue
		}

		if result != sym {
			log.errorf("expected %s to resolve '%+v', got='%+v'", sym.name, sym, result)
		}
	}
}

@(test)
test_symbol_table_resolve_local :: proc(t: ^testing.T) {
	global := m.symbol_table(context.temp_allocator)
	defer global->free()
	defer free_all(context.temp_allocator)

	global->define("a")
	global->define("b")

	local := m.symbol_table(context.temp_allocator, &global)
	defer local->free()
	local->define("c")
	local->define("d")

	expected := [?]m.Symbol {
		{"a", .Global, 0},
		{"b", .Global, 1},
		{"c", .Local, 0},
		{"d", .Local, 1},
	}

	for sym in expected {
		result, ok := local->resolve(sym.name)
		if !ok {
			log.errorf("name %s not resolvable", sym.name)
			continue
		}

		if result != sym {
			log.errorf("expected %s to resolve '%+v', got='%+v'", sym.name, sym, result)
		}
	}
}

@(test)
test_symbol_table_resolve_nested_local :: proc(t: ^testing.T) {
	global := m.symbol_table(context.temp_allocator)
	defer global->free()
	defer free_all(context.temp_allocator)

	global->define("a")
	global->define("b")

	local := m.symbol_table(context.temp_allocator, &global)
	defer local->free()
	local->define("c")
	local->define("d")

	second_local := m.symbol_table(context.temp_allocator, &local)
	defer second_local->free()
	second_local->define("e")
	second_local->define("f")

	tests := []struct {
		table:    ^m.Symbol_Table,
		expected: []m.Symbol,
	} {
		{&local, {{"a", .Global, 0}, {"b", .Global, 1}, {"c", .Local, 0}, {"d", .Local, 1}}},
		{
			&second_local,
			{{"a", .Global, 0}, {"b", .Global, 1}, {"e", .Local, 0}, {"f", .Local, 1}},
		},
	}


	for test_case in tests {
		for sym in test_case.expected {
			result, ok := test_case.table->resolve(sym.name)
			if !ok {
				log.errorf("name %s not resolvable", sym.name)
				continue
			}

			if result != sym {
				log.errorf("expected %s to resolve '%+v', got='%+v'", sym.name, sym, result)
			}
		}
	}
}
