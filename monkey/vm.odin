package monkey_odin

import "core:fmt"
import "core:mem"
import st "core:strings"

import "../utils"

STACK_SIZE :: 2048

GLOBALS_SIZE :: 65536

@(private = "file")
Dap_Item :: union {
	[]Object_Base,
	Obj_Array,
	Obj_Hash_Table,
}

VM :: struct {
	instructions:           []byte,
	constants:              []Object_Base,

	// storage
	globals:                ^[]Object_Base,

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

				case Obj_Array:
					delete(kind)

				case Obj_Hash_Table:
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

	if err == .None {
		v.stack = utils.register_in_pool(&v.managed, []Object_Base, STACK_SIZE)
		v.globals = utils.register_in_pool(&v.managed, []Object_Base, GLOBALS_SIZE)
	}

	return err
}

@(private = "file")
vm_run :: proc(v: ^VM, bytecode: Bytecode) -> (err: string) {
	v.instructions = bytecode.instructions
	v.constants = bytecode.constants

	for ip := 0; ip < len(v.instructions); ip += 1 {
		op := Opcode(v.instructions[ip])

		switch op {
		case .Cnst:
			const_idx := read_u16(v.instructions[ip + 1:])
			ip += 2

			if err = vm_push(v, v.constants[const_idx]); err != "" do return

		case .Arr:
			num_elements := int(read_u16(v.instructions[ip + 1:]))
			ip += 2

			array := vm_build_array(v, v.sp - num_elements, v.sp)
			v.sp = v.sp - num_elements

			if err = vm_push(v, array); err != "" do return

		case .Ht:
			num_elements := int(read_u16(v.instructions[ip + 1:]))
			ip += 2

			ht: Object_Base
			if ht, err = vm_build_hash_table(v, v.sp - num_elements, v.sp); err != "" do return

			v.sp = v.sp - num_elements

			if err = vm_push(v, ht); err != "" do return

		case .Add, .Sub, .Mul, .Div:
			if err = vm_exec_bin_op(v, op); err != "" do return

		case .Eq, .Neq, .Gt:
			if err = vm_exec_comp(v, op); err != "" do return

		case .Not:
			if err = vm_exec_not_op(v); err != "" do return

		case .Neg:
			if err = vm_exec_neg_op(v); err != "" do return

		case .Jmp:
			pos := int(read_u16(v.instructions[ip + 1:]))
			ip = pos - 1

		case .Jmp_If_Not:
			pos := int(read_u16(v.instructions[ip + 1:]))
			ip += 2

			condition := vm_pop(v)
			if !obj_is_truthy(condition) {
				ip = pos - 1
			}

		case .Set_G:
			global_index := read_u16(v.instructions[ip + 1:])
			ip += 2

			v.globals[global_index] = vm_pop(v)

		case .Get_G:
			global_index := read_u16(v.instructions[ip + 1:])
			ip += 2

			if err = vm_push(v, v.globals[global_index]); err != "" do return

		case .Nil:
			if err = vm_push(v, Obj_Null{}); err != "" do return

		case .True:
			if err = vm_push(v, true); err != "" do return

		case .False:
			if err = vm_push(v, false); err != "" do return

		case .Pop:
			vm_pop(v)
		}
	}

	return ""
}

@(private = "file")
vm_build_hash_table :: proc(v: ^VM, start_index, end_index: int) -> (Object_Base, string) {
	ht := utils.register_in_pool(&v.managed, Obj_Hash_Table, (end_index - start_index) / 2)

	for i := start_index; i < end_index; i += 2 {
		key := v.stack[i]
		value := v.stack[i + 1]

		key_str, key_is_valid := key.(string)
		if !key_is_valid {
			return nil, "some error"
		}

		ht[st.clone(key_str, v._pool)] = value
	}

	return ht, ""
}

@(private = "file")
vm_build_array :: proc(v: ^VM, start_index, end_index: int) -> Object_Base {
	elements := utils.register_in_pool(&v.managed, Obj_Array, end_index - start_index)

	for i := start_index; i < end_index; i += 1 {
		append(elements, v.stack[i])
	}

	return elements
}

@(private = "file")
vm_exec_neg_op :: proc(v: ^VM) -> (err: string) {
	o := vm_pop(v)

	operand, ok := o.(int)
	if !ok {
		st.builder_reset(&v._sb)
		fmt.sbprintf(&v._sb, "unsupported type for negation: '%v'", ast_type(o))
		return st.to_string(v._sb)
	}

	return vm_push(v, -operand)
}

@(private = "file")
vm_exec_not_op :: proc(v: ^VM) -> (err: string) {
	o := vm_pop(v)

	#partial switch operand in o {
	case bool:
		return vm_push(v, !operand)

	case Obj_Null:
		return vm_push(v, true)

	case:
		return vm_push(v, false)
	}

	unreachable()
}

@(private = "file")
vm_exec_int_comp :: proc(v: ^VM, op: Opcode, left, right: int) -> (err: string) {
	result: bool

	#partial switch op {
	case .Eq:
		result = right == left

	case .Neq:
		result = right != left

	case .Gt:
		result = left > right

	case:
		st.builder_reset(&v._sb)
		fmt.sbprintf(&v._sb, "unsupported operator: '%d'", op)
		return st.to_string(v._sb)
	}

	return vm_push(v, result)
}

@(private = "file")
vm_exec_comp :: proc(v: ^VM, op: Opcode) -> (err: string) {
	right := vm_pop(v)
	left := vm_pop(v)

	right_val, right_is_int := right.(int)
	left_val, left_is_int := left.(int)

	if right_is_int && left_is_int {
		return vm_exec_int_comp(v, op, left_val, right_val)
	}

	#partial switch op {
	case .Eq:
		return vm_push(v, right == left)

	case .Neq:
		return vm_push(v, right != left)
	}

	st.builder_reset(&v._sb)
	fmt.sbprintf(
		&v._sb,
		"unsupported operator: %d ('%v', '%v')",
		op,
		ast_type(left),
		ast_type(right),
	)
	return st.to_string(v._sb)
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

	return vm_push(v, result)
}

@(private = "file")
vm_exec_bin_str_op :: proc(v: ^VM, op: Opcode, left, right: string) -> (err: string) {
	result: string

	#partial switch op {
	case .Add:
		st.builder_reset(&v._sb)
		fmt.sbprintf(&v._sb, "%s%s", left, right)
		result = st.clone(st.to_string(v._sb), v._pool)

	case:
		st.builder_reset(&v._sb)
		fmt.sbprintf(&v._sb, "unsupported string operator: '%d'", op)
		return st.to_string(v._sb)
	}

	return vm_push(v, result)
}

@(private = "file")
vm_exec_bin_op :: proc(v: ^VM, op: Opcode) -> (err: string) {
	right := vm_pop(v)
	left := vm_pop(v)

	right_val, right_is_int := right.(int)
	left_val, left_is_int := left.(int)

	if right_is_int && left_is_int {
		return vm_exec_bin_int_op(v, op, left_val, right_val)
	} else if obj_type(right) == string && obj_type(left) == string {
		return vm_exec_bin_str_op(v, op, left.(string), right.(string))
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
