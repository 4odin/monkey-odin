package monkey_tests

import "core:log"

import m "../monkey"

import "core:testing"

@(test)
test_symbol_table_define :: proc(t: ^testing.T) {
	expected := map[string]m.Symbol {
		"a" = {"a", .Global, 0},
		"b" = {"b", .Global, 1},
	}

	defer delete(expected)

	global := m.symbol_table()
	defer global->free()

	a := global->define("a")
	if a != expected["a"] {
		log.errorf("expected a='%v', got='%v'", expected["a"], a)
	}

	b := global->define("b")
	if b != expected["b"] {
		log.errorf("expected b='%v', got='%v'", expected["b"], b)
	}
}

@(test)
test_symbol_table_resolve_global :: proc(t: ^testing.T) {
	global := m.symbol_table()
	defer global->free()

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
