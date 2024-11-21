package monkey_odin

import "core:fmt"
import "core:mem"
import "core:os"
import s "core:strings"

import mp "./parser"
import u "./utils"

_ :: mem

PROMPT :: "> "
QUIT_CMD :: ":q"

main :: proc() {
	parser := mp.parser()
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintfln("=== %v allocations not freed: ===", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintfln("- %v bytes @ %v", entry.size, entry.location)
				}
			}

			if len(track.bad_free_array) > 0 {
				fmt.eprintfln("=== %v incorrect frees: ===", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintfln("- %p @ %v", entry.memory, entry.location)
				}
			}

			mem.tracking_allocator_destroy(&track)

			if parser._arena.total_used != 0 {
				fmt.eprintfln("parser has unfreed memory: %v", parser._arena.total_used)
			}
		}
	}

	fmt.println("Monkey language REPL")
	fmt.printfln("Enter '%s' to exit", QUIT_CMD)

	username := u.get_username(context.temp_allocator)
	defer free_all(context.temp_allocator)

	parser->config()
	defer parser->free()

	for {
		fmt.print(username)
		fmt.print(PROMPT)

		buf: [1024]byte
		_, err := os.read(os.stdin, buf[:])
		if err != os.ERROR_NONE {
			fmt.eprintln("Error reading: ", err)
			return
		}

		input := string(buf[:])

		if input[:len(QUIT_CMD)] == QUIT_CMD do return

		prog := parser->parse(input)
		if len(parser.errors) > 0 {
			fmt.println("error")
			continue
		}

		program := mp.Monkey_Data(prog)

		sb := s.builder_make(context.temp_allocator)
		mp.ast_to_string(&program, &sb)

		fmt.println(s.to_string(sb))
	}
}
