package monkey_vm

// import st "core:strings"
import "core:fmt"

import ma "../ast"
import me "../evaluator"

_ :: fmt

Bytecode :: struct {
	instructions: Instructions,
	constants:    []me.Object_Base,
}

Compiler :: struct {
	instructions: Instructions,
	constants:    []me.Object_Base,

	// methods
	compile:      proc(c: ^Compiler, ast: ma.Node) -> (err: string),
	bytecode:     proc(c: ^Compiler) -> Bytecode,
}

compiler :: proc(allocator := context.allocator) -> Compiler {
	return {
		instructions = {},
		constants = {},
		compile = compiler_compile,
		bytecode = compiler_bytecode,
	}
}

@(private = "file")
compiler_compile :: proc(c: ^Compiler, ast: ma.Node) -> (err: string) {
	return ""
}

@(private = "file")
compiler_bytecode :: proc(c: ^Compiler) -> Bytecode {
	return {instructions = c.instructions, constants = c.constants}
}
