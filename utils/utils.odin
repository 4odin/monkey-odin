package monkey_utils

import "base:intrinsics"
import "core:log"
import "core:mem"
import vmem "core:mem/virtual"
import st "core:strings"

_ :: mem
_ :: vmem
_ :: log

// Struct to be used for subtyping other structs when the target type has needs internal
// memories which cannot or should not be mixed with context.temp_allocator or other memory pools
// it has internal growing arena, 
//
// a dynamic array that can hold growing element such as other dynamic arrays and maps
//
// also a string builder that maps its memory to internal pool
Mem_Manager :: struct($Union_Element: typeid) where intrinsics.type_is_union(Union_Element) {
	// memory
	_arena:                 vmem.Arena,
	_arena_reserved:        uint,
	_pool:                  mem.Allocator,
	_dyn_arr_pool:          [dynamic]Union_Element,
	_dyn_arr_pool_reserved: uint,

	// temp builders
	_sb:                    st.Builder,

	// methods
	mem_set:                proc(m: ^Mem_Manager(Union_Element)) -> mem.Allocator_Error,
	mem_init:               proc(
		m: ^Mem_Manager(Union_Element),
		pool_reserved_block_size: uint = 1 * mem.Megabyte,
		dyn_arr_reserved: uint = 10,
	) -> mem.Allocator_Error,
	mem_free:               proc(m: ^Mem_Manager(Union_Element)),
	mem_is_freed:           proc(m: ^Mem_Manager(Union_Element)) -> (bool, uint, uint),

	// before deleting the dynamic array pool, you need to use it to delete its elements individually
	mem_dyn_arr_el_free:    proc(dyn_pool: [dynamic]Union_Element),
}

mem_manager :: proc(
	$Union_Element: typeid,
	free_elements: proc(dyn_pool: [dynamic]Union_Element),
) -> Mem_Manager(Union_Element) where intrinsics.type_is_union(Union_Element) {
	return {
		// methods
		mem_set = proc(m: ^Mem_Manager(Union_Element)) -> mem.Allocator_Error {
			err := vmem.arena_init_growing(&m._arena, m._arena_reserved)
			if err == .None {
				m._pool = vmem.arena_allocator(&m._arena)
				m._sb = st.builder_make(m._pool)
				if m._dyn_arr_pool_reserved > 0 {
					m._dyn_arr_pool = make(
						[dynamic]Union_Element,
						0,
						m._dyn_arr_pool_reserved,
						m._pool,
					)
				} else {
					m._dyn_arr_pool.allocator = m._pool
				}
			}


			return err
		},
		mem_init = proc(
			m: ^Mem_Manager(Union_Element),
			pool_reserved_block_size: uint = 1 * mem.Megabyte,
			dyn_arr_reserved: uint = 10,
		) -> mem.Allocator_Error {
			m._arena_reserved = pool_reserved_block_size
			m._dyn_arr_pool_reserved = dyn_arr_reserved

			err := m->mem_set()

			return err
		},
		mem_dyn_arr_el_free = free_elements,
		mem_free = proc(m: ^Mem_Manager(Union_Element)) {
			defer {
				vmem.arena_destroy(&m._arena)
				m._arena = {}

				delete(m._dyn_arr_pool)
				m._dyn_arr_pool = {}
			}

			m.mem_dyn_arr_el_free(m._dyn_arr_pool)
		},
		mem_is_freed = proc(
			m: ^Mem_Manager(Union_Element),
		) -> (
			result: bool,
			arena_used: uint,
			dyn_arr_pool_unremoved: uint,
		) {
			result = m._pool == {} || cap(m._dyn_arr_pool) == 0
			arena_used = m._arena.total_used
			dyn_arr_pool_unremoved = cap(m._dyn_arr_pool)

			return
		},
	}
}

register_in_pool :: proc {
	register_in_pool_make,
	register_in_pool_new,
}

// Must be used to register dynamic arrays, maps and allocated slices or any distinct
// aliases for them in the pool
//
// Note: &<your subtipe>.managed must be sent
register_in_pool_make :: proc(
	m: ^Mem_Manager($U),
	$T: typeid,
	reserved := 0,
) -> ^T where intrinsics.type_is_dynamic_array(T) ||
	intrinsics.type_is_slice(T) ||
	intrinsics.type_is_map(T) {
	if reserved == 0 {
		when intrinsics.type_is_slice(T) {
			panic("you cannot register slice withot reserved value")
		} else {
			append(&m._dyn_arr_pool, make(T))
		}
	} else {
		when intrinsics.type_is_dynamic_array(T) {
			append(&m._dyn_arr_pool, make(T, 0, reserved))
		} else {
			append(&m._dyn_arr_pool, make(T, reserved))
		}
	}

	return &m._dyn_arr_pool[len(m._dyn_arr_pool) - 1].(T)
}

// Must be used to register other types with `new_clone`ing it
//
// Note: &<your subtipe>.managed must be sent
register_in_pool_new :: proc(
	m: ^Mem_Manager($U),
	el: $T,
) -> T where !intrinsics.type_is_dynamic_array(T) &&
	!intrinsics.type_is_slice(T) &&
	!intrinsics.type_is_map(T) {
	append(&m._dyn_arr_pool, el)

	return m._dyn_arr_pool[len(m._dyn_arr_pool) - 1].(T)
}
