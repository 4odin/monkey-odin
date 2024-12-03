package monkey_odin

import "core:fmt"
import "core:log"
import "core:mem"
import st "core:strings"

import "../utils"

_ :: log

STACK_SIZE :: 2048

GLOBALS_SIZE :: 65536

MAX_FRAMES :: 1024

@(private = "file")
Dap_Item :: union {
	[]Object_Base,
	[]Frame,
}

VM :: struct {
	constants:              []Object_Base,

	// storage
	compiler_state:         ^Compiler_State,

	// frame
	frames:                 ^[]Frame,
	frames_index:           int,

	// stack
	stack:                  ^[]Object_Base,
	sp:                     int, // always points to the next value. Top of the stack is stack[sp-1]

	// methods
	init:                   proc(
		v: ^VM,
		bytecode: Bytecode,
		compiler_state: ^Compiler_State,
		pool_reserved_block_size: uint = 1 * mem.Megabyte,
		dyn_arr_reserved: uint = 10,
	) -> mem.Allocator_Error,
	run:                    proc(v: ^VM) -> (err: string),
	stack_top:              proc(v: ^VM) -> Object_Base,
	last_popped_stack_elem: proc(v: ^VM) -> Object_Base,

	// Managed
	using managed:          utils.Mem_Manager(Dap_Item),
}

vm :: proc(allocator := context.allocator) -> VM {
	return {
		init = vm_init,
		run = vm_run,
		stack_top = vm_stack_top,
		last_popped_stack_elem = vm_last_popped_stack_elem,
		managed = utils.mem_manager(Dap_Item, proc(dyn_pool: [dynamic]Dap_Item) {
			for element in dyn_pool {
				switch kind in element {
				case []Object_Base:
					delete(kind)

				case []Frame:
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
vm_init :: proc(
	v: ^VM,
	bytecode: Bytecode,
	compiler_state: ^Compiler_State,
	pool_reserved_block_size: uint = 1 * mem.Megabyte,
	dyn_arr_reserved: uint = 10,
) -> mem.Allocator_Error {
	err := v->mem_init(pool_reserved_block_size, dyn_arr_reserved)

	v.compiler_state = compiler_state

	if err == .None {
		v.stack = utils.register_in_pool(&v.managed, []Object_Base, STACK_SIZE)
		v.frames = utils.register_in_pool(&v.managed, []Frame, MAX_FRAMES)

		v.frames_index = 0
		vm_push_frame(v, frame(bytecode.instructions, 0))
	}

	v.constants = bytecode.constants

	return err
}

@(private = "file")
vm_run :: proc(v: ^VM) -> (err: string) {
	ip: int
	ins: []byte
	op: Opcode

	for vm_current_frame(v).ip < len(vm_current_frame(v).instructions) - 1 {
		vm_current_frame(v).ip += 1

		ip = vm_current_frame(v).ip
		ins = vm_current_frame(v).instructions
		op = Opcode(ins[ip])

		#partial switch op {
		case .Cnst:
			const_idx := read_u16(ins[ip + 1:])
			vm_current_frame(v).ip += 2

			if err = vm_push(v, v.constants[const_idx]); err != "" do return

		case .Arr:
			num_elements := int(read_u16(ins[ip + 1:]))
			vm_current_frame(v).ip += 2

			array := vm_build_array(v, v.sp - num_elements, v.sp)
			v.sp = v.sp - num_elements

			if err = vm_push(v, array); err != "" do return

		case .Ht:
			num_elements := int(read_u16(ins[ip + 1:]))
			vm_current_frame(v).ip += 2

			ht: Object_Base
			if ht, err = vm_build_hash_table(v, v.sp - num_elements, v.sp); err != "" do return

			v.sp = v.sp - num_elements

			if err = vm_push(v, ht); err != "" do return

		case .Add, .Sub, .Mul, .Div:
			if err = vm_exec_bin_op(v, op); err != "" do return

		case .Idx:
			index := vm_pop(v)
			operand := vm_pop(v)

			if err = vm_exec_idx_expr(v, operand, index); err != "" do return

		case .Call:
			num_args := read_u8(ins[ip + 1:])
			vm_current_frame(v).ip += 1

			if err = vm_call_function(v, int(num_args)); err != "" do return

		case .Ret_V:
			ret_val := vm_pop(v)

			frame := vm_pop_frame(v)
			v.sp = frame.base_pointer - 1

			if err = vm_push(v, ret_val); err != "" do return

		case .Ret:
			frame := vm_pop_frame(v)
			v.sp = frame.base_pointer - 1

			if err = vm_push(v, Obj_Null{}); err != "" do return

		case .Eq, .Neq, .Gt:
			if err = vm_exec_comp(v, op); err != "" do return

		case .Not:
			if err = vm_exec_not_op(v); err != "" do return

		case .Neg:
			if err = vm_exec_neg_op(v); err != "" do return

		case .Jmp:
			pos := int(read_u16(ins[ip + 1:]))
			vm_current_frame(v).ip = pos - 1

		case .Jmp_If_Not:
			pos := int(read_u16(ins[ip + 1:]))
			vm_current_frame(v).ip += 2

			condition := vm_pop(v)
			if !obj_is_truthy(condition) {
				vm_current_frame(v).ip = pos - 1
			}

		case .Set_G:
			global_index := read_u16(ins[ip + 1:])
			vm_current_frame(v).ip += 2

			v.compiler_state.globals[global_index] = vm_pop(v)

		case .Get_G:
			global_index := read_u16(ins[ip + 1:])
			vm_current_frame(v).ip += 2

			if err = vm_push(v, v.compiler_state.globals[global_index]); err != "" do return

		case .Set_L:
			local_index := read_u8(ins[ip + 1:])
			vm_current_frame(v).ip += 1

			frame := vm_current_frame(v)

			v.stack[frame.base_pointer + int(local_index)] = vm_pop(v)

		case .Get_L:
			local_index := read_u8(ins[ip + 1:])
			vm_current_frame(v).ip += 1

			frame := vm_current_frame(v)

			if err = vm_push(v, v.stack[frame.base_pointer + int(local_index)]); err != "" do return

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
vm_call_function :: proc(v: ^VM, num_args: int) -> (err: string) {
	fn, ok := v.stack[v.sp - 1 - int(num_args)].(Obj_Compiled_Fn_Obj)
	if !ok {
		st.builder_reset(&v._sb)
		fmt.sbprintf(&v._sb, "non-function call: '%v'", ast_type(v.stack[v.sp - 1]))
		return st.to_string(v._sb)
	}

	if num_args != fn.num_parameters {
		st.builder_reset(&v._sb)
		fmt.sbprintf(
			&v._sb,
			"wring number of arguments: want='%d', got='%d'",
			fn.num_parameters,
			num_args,
		)
		return st.to_string(v._sb)
	}

	frame := frame(fn.instructions[:], v.sp - num_args)

	vm_push_frame(v, frame)
	v.sp = frame.base_pointer + fn.num_locals

	return ""
}

@(private = "file")
vm_current_frame :: proc(v: ^VM) -> ^Frame {
	return &v.frames[v.frames_index - 1]
}

@(private = "file")
vm_push_frame :: proc(v: ^VM, f: Frame) {
	v.frames[v.frames_index] = f
	v.frames_index += 1
}

@(private = "file")
vm_pop_frame :: proc(v: ^VM) -> ^Frame {
	v.frames_index -= 1
	return &v.frames[v.frames_index]
}

@(private = "file")
vm_exec_ht_idx :: proc(v: ^VM, ht: ^Obj_Hash_Table, key: string) -> (err: string) {
	value, key_exists := ht[key]

	if !key_exists do return vm_push(v, Obj_Null{})

	return vm_push(v, value)
}

@(private = "file")
vm_exec_arr_idx :: proc(v: ^VM, arr: ^Obj_Array, index: int) -> (err: string) {
	max := len(arr) - 1

	if index < 0 || index > max do return vm_push(v, Obj_Null{})

	return vm_push(v, arr[index])
}

@(private = "file")
vm_exec_idx_expr :: proc(v: ^VM, operand, index: Object_Base) -> (err: string) {
	if obj_type(operand) == ^Obj_Array && obj_type(index) == int {
		return vm_exec_arr_idx(v, operand.(^Obj_Array), index.(int))
	} else if obj_type(operand) == ^Obj_Hash_Table && obj_type(index) == string {
		return vm_exec_ht_idx(v, operand.(^Obj_Hash_Table), index.(string))
	}

	st.builder_reset(&v._sb)
	fmt.sbprintf(&v._sb, "unsupported index operation: '%v'", ast_type(operand))
	return st.to_string(v._sb)
}

@(private = "file")
vm_build_hash_table :: proc(v: ^VM, start_index, end_index: int) -> (Object_Base, string) {
	ht := utils.register_in_pool(
		&v.compiler_state.managed,
		Obj_Hash_Table,
		(end_index - start_index) / 2,
	)

	for i := start_index; i < end_index; i += 2 {
		key := v.stack[i]
		value := v.stack[i + 1]

		key_str, key_is_valid := key.(string)
		if !key_is_valid {
			st.builder_reset(&v._sb)
			fmt.sbprintf(&v._sb, "unsupported key type in hash table: '%v'", ast_type(key))
			return nil, st.to_string(v._sb)
		}

		ht[st.clone(key_str, v._pool)] = value
	}

	return ht, ""
}

@(private = "file")
vm_build_array :: proc(v: ^VM, start_index, end_index: int) -> Object_Base {
	elements := utils.register_in_pool(
		&v.compiler_state.managed,
		Obj_Array,
		end_index - start_index,
	)

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

	if obj_type(right) == int && obj_type(left) == int {
		return vm_exec_bin_int_op(v, op, left.(int), right.(int))
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
