package monkey_odin

Frame :: struct {
	instructions: []byte,
	ip:           int,
}

frame :: proc(instructions: []byte) -> Frame {
	return {instructions, -1}
}
