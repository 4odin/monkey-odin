package monkey_odin

import "core:fmt"
import "core:mem"
import st "core:strings"

import "../utils"

STACK_SIZE :: 2048

@(private = "file")
Dap_Item :: union {
	[]Object_Base,
}

VM :: struct {
	instructions:           []byte,
	constants:              []Object_Base,

	// stack
	stack:                  ^[]Object_Base,
	sp:                     int, // always points to the next value. Top of the stack is stack[sp-1]

	// methods
	config:                 proc(
		v: ^VM,
		pool_reserved_block_size: uint = 1 * mem.Megabyte,
		dyn_arr_reserved: uint = 10,
	) -> mem.Allocator_Error,
	run:                    proc(v: ^VM, bytecode: Bytecode) -> (err: string),
	stack_top:              proc(v: ^VM) -> Object_Base,
	last_popped_stack_elem: proc(v: ^VM) -> Object_Base,

	// Managed
	using managed:          utils.Mem_Manager(Dap_Item),
}

vm :: proc(allocator := context.allocator) -> VM {
	return {
		config = vm_config,
		run = vm_run,
		stack_top = vm_stack_top,
		last_popped_stack_elem = vm_last_popped_stack_elem,
		managed = utils.mem_manager(Dap_Item, proc(dyn_pool: [dynamic]Dap_Item) {
			for element in dyn_pool {
				switch kind in element {
				case []Object_Base:
					delete(kind)
				}
			}
		}),
	}
}

// ***************************************************************************************
// PRIVATE TYPES AND PROCEDURES
// ***************************************************************************************

@(private = "file")
vm_config :: proc(
	v: ^VM,
	pool_reserved_block_size: uint = 1 * mem.Megabyte,
	dyn_arr_reserved: uint = 10,
) -> mem.Allocator_Error {
	err := v->mem_config(pool_reserved_block_size, dyn_arr_reserved)

	if err == .None do v.stack = utils.register_in_pool(&v.managed, []Object_Base, STACK_SIZE)

	return err
}

@(private = "file")
vm_run :: proc(v: ^VM, bytecode: Bytecode) -> (err: string) {
	v.instructions = bytecode.instructions
	v.constants = bytecode.constants

	for ip := 0; ip < len(v.instructions); ip += 1 {
		op := Opcode(v.instructions[ip])

		switch op {
		case .Constant:
			const_idx, _ := read_u16(v.instructions[ip + 1:])
			ip += 2

			err = vm_push(v, v.constants[const_idx])
			if err != "" do return

		case .Add, .Sub, .Mul, .Div:
			err = vm_exec_bin_op(v, op)
			if err != "" do return

		case .Pop:
			vm_pop(v)
		}
	}

	return ""
}

@(private = "file")
vm_exec_bin_int_op :: proc(v: ^VM, op: Opcode, left, right: int) -> (err: string) {
	result: int

	#partial switch op {
	case .Add:
		result = left + right

	case .Sub:
		result = left - right

	case .Mul:
		result = left * right

	case .Div:
		result = left / right

	case:
		st.builder_reset(&v._sb)
		fmt.sbprintf(&v._sb, "unsupported integer operator: '%d'", op)
		return st.to_string(v._sb)
	}

	vm_push(v, result)

	return ""
}

@(private = "file")
vm_exec_bin_op :: proc(v: ^VM, op: Opcode) -> (err: string) {
	right := vm_pop(v)
	left := vm_pop(v)

	right_val, right_is_int := right.(int)
	left_val, left_is_int := left.(int)

	if right_is_int && left_is_int {
		return vm_exec_bin_int_op(v, op, left_val, right_val)
	}

	st.builder_reset(&v._sb)
	fmt.sbprintf(
		&v._sb,
		"unsupported types for binary operation: '%v', '%v'",
		ast_type(left),
		ast_type(right),
	)
	return st.to_string(v._sb)
}

@(private = "file")
vm_stack_top :: proc(v: ^VM) -> Object_Base {
	if v.sp == 0 {
		return nil
	}

	return v.stack[v.sp - 1]
}

@(private = "file")
vm_push :: proc(v: ^VM, o: Object_Base) -> (err: string) {
	if v.sp >= STACK_SIZE {
		st.builder_reset(&v._sb)

		fmt.sbprint(&v._sb, "stack overflow")

		return st.to_string(v._sb)
	}

	v.stack[v.sp] = o
	v.sp += 1

	return ""
}

@(private = "file")
vm_pop :: proc(v: ^VM) -> Object_Base {
	o := v.stack[v.sp - 1]
	v.sp -= 1

	return o
}

@(private = "file")
vm_last_popped_stack_elem :: proc(v: ^VM) -> Object_Base {
	return v.stack[v.sp]
}
