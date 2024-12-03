package monkey_odin

Frame :: struct {
	instructions: []byte,
	ip:           int,
	base_pointer: int,
}

frame :: proc(instructions: []byte, base_pointer: int) -> Frame {
	return {instructions, -1, base_pointer}
}
