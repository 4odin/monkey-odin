package monkey_odin

import "core:mem"

import "../utils"

@(private = "file")
Dap_Item :: union {
	Instructions,
	Obj_Array,
	Obj_Hash_Table,
	^Symbol_Table,
}

Compiler_State :: struct {
	symbol_table:  Symbol_Table,
	constants:     [dynamic]Object_Base,
	globals:       []Object_Base,

	// methods
	init:          proc(state: ^Compiler_State) -> mem.Allocator_Error,
	free:          proc(state: ^Compiler_State),

	// Managed
	using managed: utils.Mem_Manager(Dap_Item),
}

compiler_state :: proc() -> Compiler_State {
	return {
		globals = make([]Object_Base, GLOBALS_SIZE),
		managed = utils.mem_manager(Dap_Item, proc(dyn_pool: [dynamic]Dap_Item) {
			for item in dyn_pool {
				switch kind in item {
				case Instructions:
					delete(kind)

				case Obj_Array:
					delete(kind)

				case Obj_Hash_Table:
					delete(kind)

				case ^Symbol_Table:
					kind->free()
					free(kind)
				}
			}
		}),

		//methods
		init = proc(state: ^Compiler_State) -> mem.Allocator_Error {
			err := state->mem_init()
			if err == .None {
				state.symbol_table = symbol_table(state._pool)
			}

			return err
		},
		free = proc(state: ^Compiler_State) {
			delete(state.constants)
			delete(state.globals)

			state.symbol_table->free()

			state->mem_free()
		},
	}
}
