package monkey_odin

import st "core:strings"

import "core:mem"

@(private = "file")
Dap_Item :: union {
	Obj_Compiled_Fn_Obj,
}

Symbol_Scope :: enum {
	Global,
	Local,
}

Symbol :: struct {
	name:  string,
	scope: Symbol_Scope,
	index: int,
}

Symbol_Table :: struct {
	store:     map[string]Symbol,

	// outer
	outer:     ^Symbol_Table,

	// methods
	free:      proc(table: ^Symbol_Table),
	define:    proc(table: ^Symbol_Table, name: string) -> Symbol,
	resolve:   proc(table: ^Symbol_Table, name: string) -> (Symbol, bool),

	// pool
	allocator: mem.Allocator,
}

symbol_table :: proc(allocator := context.allocator, outer: ^Symbol_Table = nil) -> Symbol_Table {
	return {
		outer = outer,

		// methods
		free = proc(table: ^Symbol_Table) {
			delete(table.store)
		},
		define = proc(table: ^Symbol_Table, name: string) -> Symbol {
			name_copied := st.clone(name, table.allocator)

			scope: Symbol_Scope = .Global if table.outer == nil else .Local

			symbol := Symbol{name_copied, scope, len(table.store)}
			table.store[name_copied] = symbol

			return symbol
		},
		resolve = proc(table: ^Symbol_Table, name: string) -> (Symbol, bool) {
			obj, ok := table.store[name]
			if !ok && table.outer != nil do return table.outer->resolve(name)

			return obj, ok
		},

		// pool
		allocator = allocator,
	}
}
