package monkey_odin

Symbol_Scope :: enum {
	Global,
}

Symbol :: struct {
	name:  string,
	scope: Symbol_Scope,
	index: int,
}

Symbol_Table :: struct {
	store:   map[string]Symbol,

	// methods
	free:    proc(table: ^Symbol_Table),
	define:  proc(table: ^Symbol_Table, name: string) -> Symbol,
	resolve: proc(table: ^Symbol_Table, name: string) -> (Symbol, bool),
	reset:   proc(table: ^Symbol_Table),
}

symbol_table :: proc() -> Symbol_Table {
	return {
		// methods
		free = proc(table: ^Symbol_Table) {
			delete(table.store)
		},
		define = proc(table: ^Symbol_Table, name: string) -> Symbol {
			symbol := Symbol{name, .Global, len(table.store)}
			table.store[name] = symbol
			return symbol
		},
		resolve = proc(table: ^Symbol_Table, name: string) -> (Symbol, bool) {
			return table.store[name]
		},
		reset = proc(table: ^Symbol_Table) {
			clear(&table.store)
		},
	}
}
