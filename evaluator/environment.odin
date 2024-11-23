package monkey_evaluator

import "core:mem"

Environment :: struct {
	store:     map[string]Object_Base,

	// memory
	allocator: mem.Allocator,

	// methods
	config:    proc(env: ^Environment, inner_allocator := context.allocator),
	get:       proc(env: ^Environment, name: string) -> (Object_Base, bool),
	set:       proc(env: ^Environment, name: string, value: Object_Base) -> Object_Base,
}

environment :: proc() -> Environment {
	return {config = environment_config, get = environment_get, set = environment_set}
}

new_environment :: proc(
	inner_allocator := context.allocator,
	allocator := context.allocator,
) -> ^Environment {
	env := new(Environment, allocator)
	env->config(inner_allocator)

	return env
}

@(private = "file")
environment_config :: proc(env: ^Environment, inner_allocator := context.allocator) {
	env.store.allocator = inner_allocator
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
