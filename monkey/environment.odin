package monkey_odin

Environment :: struct {
	store: map[string]Object_Base,
	outer: ^Environment,

	// methods
	get:   proc(env: ^Environment, name: string) -> (Object_Base, bool),
	set:   proc(env: ^Environment, name: string, value: Object_Base) -> Object_Base,
	free:  proc(env: ^Environment),
}

environment :: proc(outer: ^Environment = nil) -> Environment {
	return {get = environment_get, set = environment_set, free = environment_free, outer = outer}
}

new_enclosed_environment :: proc(
	outer: ^Environment,
	reserved: uint,
	allocator := context.allocator,
) -> ^Environment {
	env := environment(outer)
	env.store = make(map[string]Object_Base, reserved, allocator)
	return new_clone(env, allocator)
}

@(private = "file")
environment_free :: proc(env: ^Environment) {
	delete(env.store)
}

@(private = "file")
environment_get :: proc(env: ^Environment, name: string) -> (Object_Base, bool) {
	obj, ok := env.store[name]
	if !ok && env.outer != nil {obj, ok = env.outer->get(name)}

	return obj, ok
}

@(private = "file")
environment_set :: proc(env: ^Environment, name: string, value: Object_Base) -> Object_Base {
	env.store[name] = value
	return value
}
