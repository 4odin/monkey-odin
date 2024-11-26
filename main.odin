package monkey_odin

import "core:fmt"
import "core:mem"
import "core:os"
import st "core:strings"

import ma "./ast"
import me "./evaluator"
import mp "./parser"
import u "./utils"

_ :: mem

PROMPT :: ">"
QUIT_CMD :: ":q"

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

	parser := mp.parser()
	evaluator := me.evaluator()
	when ODIN_DEBUG {
		// before context allocators, report on parser and other virtual memory based instances
		defer {
			if ok, arena, dyn_arr_pool := parser->is_freed(); !ok {
				fmt.eprintfln(
					"parser has unfreed memory, arena total used: %v, dynamic array pool unremoved items: %d",
					arena,
					dyn_arr_pool,
				)
			}

			if evaluator->pool_total_used() != 0 {
				fmt.eprintfln("evaluator has unfreed memory: %v", evaluator->pool_total_used())
			}
		}
	}

	fmt.println("Monkey language REPL")
	fmt.printfln("Enter '%s' to exit", QUIT_CMD)

	username := u.get_username(context.temp_allocator)

	sb := st.builder_make(context.temp_allocator)

	defer free_all(context.temp_allocator)

	parser->config()
	defer parser->free()

	evaluator->config()
	defer evaluator->free()

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

		program := parser->parse(input)
		{
			defer parser->free()

			if len(parser.errors) > 0 {
				print_errors(parser.errors)
				parser->clear_errors()
				continue
			}

			st.builder_reset(&sb)
			ma.ast_to_string(program, &sb)
			fmt.printfln("Ast: %v", st.to_string(sb))

			evaluated, ok := evaluator->eval(program, context.temp_allocator)
			if !ok {
				fmt.printfln("Evaluation error: %s", evaluated)
				continue
			}

			if evaluated != nil {
				st.builder_reset(&sb)
				me.obj_inspect(evaluated, &sb)

				fmt.printfln("Result: %v", st.to_string(sb))
			}
		}
	}
}

print_errors :: proc(errors: [dynamic]string) {
	for err in errors {
		fmt.eprintfln("-> %s", err)
	}
}
