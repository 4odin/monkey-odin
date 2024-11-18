package monkey_odin

import "core:fmt"
import "core:os"

import mp "./parser"
import u "./utils"

PROMPT :: "> "
QUIT_CMD :: ":q"

main :: proc() {
	fmt.println("Monkey language REPL")
	fmt.printfln("Enter '%s' to exit", QUIT_CMD)

	username := u.get_username()
	defer delete(username)

	for {
		fmt.print(u.get_username())
		fmt.print(PROMPT)

		buf: [1024]byte
		_, err := os.read(os.stdin, buf[:])
		if err != nil {
			fmt.eprintln("Error reading: ", err)
			return
		}

		input := string(buf[:])
		if (input[:len(QUIT_CMD)] == QUIT_CMD) do return

		lexer := mp.lexer_new(&input)
		for tok := lexer->next_token(); tok.type != mp.TokenType.EOF; tok = lexer->next_token() {
			fmt.printfln("%+v", tok)
		}
		free(lexer)
	}
}
