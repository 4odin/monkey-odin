package monkey_odin_repl

import "core:fmt"
import "core:mem"
import "core:os"
import st "core:strings"

import "./monkey"
import u "./utils"

_ :: mem

PROMPT :: ">"
QUIT_CMD :: ":q"
SYM_CMD :: ":sym"
GL_CMD :: ":gl"
C_CMD :: ":c"

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		temp_track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&temp_track, context.temp_allocator)
		context.temp_allocator = mem.tracking_allocator(&temp_track)

		// Last thing: report on the main allocator
		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintfln(
					"=== Allocator: %v allocations not freed: ===",
					len(track.allocation_map),
				)
				for _, entry in track.allocation_map {
					fmt.eprintfln("- %v bytes @ %v", entry.size, entry.location)
				}
			}

			if len(track.bad_free_array) > 0 {
				fmt.eprintfln("=== Allocator: %v incorrect frees: ===", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintfln("- %p @ %v", entry.memory, entry.location)
				}
			}

			mem.tracking_allocator_destroy(&track)
		}

		// before the last thing, report on temp allocator
		defer {
			if len(temp_track.allocation_map) > 0 {
				fmt.eprintfln(
					"=== Temp Allocator: %v allocations not freed: ===",
					len(temp_track.allocation_map),
				)
				for _, entry in temp_track.allocation_map {
					fmt.eprintfln("- %v bytes @ %v", entry.size, entry.location)
				}
			}

			if len(temp_track.bad_free_array) > 0 {
				fmt.eprintfln(
					"=== Temp Allocator: %v incorrect frees: ===",
					len(temp_track.bad_free_array),
				)
				for entry in temp_track.bad_free_array {
					fmt.eprintfln("- %p @ %v", entry.memory, entry.location)
				}
			}

			mem.tracking_allocator_destroy(&temp_track)
		}
	}

	parser := monkey.parser()
	evaluator := monkey.evaluator()

	when ODIN_DEBUG {
		// before context allocators, report on any other virtual memory based instances
		defer {
			if ok, arena, dyn_arr_pool := parser->mem_is_freed(); !ok {
				fmt.eprintfln(
					"parser has unfreed memory, arena total used: %v, dynamic array pool unremoved items: %d",
					arena,
					dyn_arr_pool,
				)
			}

			if ok, arena, dyn_arr_pool := evaluator->mem_is_freed(); !ok {
				fmt.eprintfln(
					"evaluator has unfreed memory, arena total used: %v, dynamic array pool unremoved items: %d",
					arena,
					dyn_arr_pool,
				)
			}
		}
	}

	fmt.println("Monkey language REPL")
	fmt.printfln("Enter '%s' to exit", QUIT_CMD)

	username := u.get_username(context.temp_allocator)

	sb := st.builder_make(context.temp_allocator)

	defer free_all(context.temp_allocator)

	parser->init()
	defer parser->mem_free()

	evaluator->init()
	defer evaluator->free()

	state := monkey.compiler_state()
	state->init()
	defer state->free()

	for {
		fmt.printf("%s%s ", username, PROMPT)

		buf: [1024]byte
		_, err := os.read(os.stdin, buf[:])
		if err != os.ERROR_NONE {
			fmt.eprintln("Error reading: ", err)
			return
		}

		input := string(buf[:])

		if input[:len(QUIT_CMD)] == QUIT_CMD do return
		else if input[:len(SYM_CMD)] == SYM_CMD {
			fmt.printfln("Symbol Table:\n%v", state.symbol_table.store)
			continue
		} else if input[:len(GL_CMD)] == GL_CMD {
			fmt.printfln("Globals:\n%v", state.globals)
			continue
		} else if input[:len(C_CMD)] == C_CMD {
			fmt.printfln("Constants:\n%v", state.constants)
			continue
		} else if buf[0] == 13 do continue

		program := parser->parse(input)
		{
			defer parser->mem_free()

			if len(parser.errors) > 0 {
				print_errors(parser.errors)
				parser->clear_errors()
				continue
			}

			st.builder_reset(&sb)
			monkey.ast_to_string(program, &sb)
			fmt.printfln("Ast to string: %v", st.to_string(sb))

			evaluated, ok := evaluator->eval(program, context.temp_allocator)
			if !ok {
				fmt.printfln("Evaluation error: %s", evaluated)
			} else if evaluated != nil {
				st.builder_reset(&sb)
				monkey.obj_inspect(evaluated, &sb)

				fmt.printfln("Evaluator result: %v", st.to_string(sb))
			}

			compiler := monkey.compiler()
			compiler->init(&state)

			err := compiler->compile(program)
			if err != "" {
				fmt.printfln("Compiler error: %s", err)
				continue
			}

			vm := monkey.vm()
			vm->init(compiler->bytecode(), &state)

			when ODIN_DEBUG {
				// before context allocators, report on any other virtual memory based instances
				defer {
					if mem_is_freed, arena, dyn_arr_pool := compiler->mem_is_freed();
					   !mem_is_freed {
						fmt.eprintfln(
							"compiler has unfreed memory, arena total used: %v, dynamic array pool unremoved items: %d",
							arena,
							dyn_arr_pool,
						)
					}

					if mem_is_freed, arena, dyn_arr_pool := vm->mem_is_freed(); !mem_is_freed {
						fmt.eprintfln(
							"vm has unfreed memory, arena total used: %v, dynamic array pool unremoved items: %d",
							arena,
							dyn_arr_pool,
						)
					}
				}
			}
			defer compiler->mem_free()
			defer vm->mem_free()

			err = vm->run()
			if err != "" {
				fmt.printfln("Vm error: %s", err)
				continue
			}

			last_popped := vm->last_popped_stack_elem()
			st.builder_reset(&sb)
			monkey.obj_inspect(last_popped, &sb)

			fmt.printfln("Vm result: %v", st.to_string(sb))
		}
	}
}

print_errors :: proc(errors: [dynamic]string) {
	for err in errors {
		fmt.eprintfln("-> %s", err)
	}
}
