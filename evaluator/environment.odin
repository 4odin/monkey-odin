package monkey_evaluator

Environment :: struct {
	store: map[string]Object_Base,

	// methods
	get:   proc(env: ^Environment, name: string) -> (Object_Base, bool),
	set:   proc(env: ^Environment, name: string, value: Object_Base) -> Object_Base,
	free:  proc(env: ^Environment),
}

environment :: proc() -> Environment {
	return {get = environment_get, set = environment_set, free = environment_free}
}

new_environment :: proc(allocator := context.allocator) -> ^Environment {
	env := new(Environment, allocator)

	return env
}

@(private = "file")
environment_free :: proc(env: ^Environment) {
	delete(env.store)
}

@(private = "file")
environment_get :: proc(env: ^Environment, name: string) -> (Object_Base, bool) {
	return env.store[name]
}

@(private = "file")
environment_set :: proc(env: ^Environment, name: string, value: Object_Base) -> Object_Base {
	env.store[name] = value
	return value
}
