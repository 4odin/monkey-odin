package monkey_odin

import "core:fmt"
import "core:mem"
import "core:os"

import mp "./parser"
import u "./utils"

_ :: mem

PROMPT :: "> "
QUIT_CMD :: ":q"

main :: proc() {
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
		}
	}

	fmt.println("Monkey language REPL")
	fmt.printfln("Enter '%s' to exit", QUIT_CMD)

	username := u.get_username(context.temp_allocator)
	defer free_all(context.temp_allocator)

	lexer := mp.lexer()

	for {
		fmt.print(username)
		fmt.print(PROMPT)

		buf: [1024]byte
		_, err := os.read(os.stdin, buf[:])
		if err != os.ERROR_NONE {
			fmt.eprintln("Error reading: ", err)
			return
		}

		if (string(buf[:])[:len(QUIT_CMD)] == QUIT_CMD) do return

		lexer->init(buf[:])
		for tok := lexer->next_token(); tok.type != .EOF; tok = lexer->next_token() {
			fmt.printfln("%+v", tok)
		}
	}
}
