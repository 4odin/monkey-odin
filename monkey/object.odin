package monkey_odin

import "core:fmt"
import "core:reflect"
import st "core:strings"

Obj_Null :: struct {}
Obj_Function :: struct {
	parameters: [dynamic]Node_Identifier,
	body:       Node_Block_Expression,
	env:        ^Environment,
}

Obj_Hash_Table :: map[string]Object_Base

Obj_Builtin_Fn :: #type proc(e: ^Evaluator, args: [dynamic]Object_Base) -> (Object_Base, bool)

Obj_Array :: distinct [dynamic]Object_Base

Object_Base :: union {
	int,
	bool,
	string,

	// Objects
	Obj_Null,
	^Obj_Function,
	Obj_Builtin_Fn,
	^Obj_Array,
	^Obj_Hash_Table,
}

Object_Return :: distinct Object_Base

Object :: union {
	Object_Base,
	Object_Return,
}

to_object_base :: proc {
	_to_object_base_val,
	_to_object_base_ptr,
}

@(private = "file")
_to_object_base_val :: proc(obj: Object) -> Object_Base {
	obj := obj
	return _to_object_base_ptr(&obj)
}

@(private = "file")
_to_object_base_ptr :: proc(obj: ^Object) -> Object_Base {
	switch data in obj {
	case Object_Base:
		return data

	case Object_Return:
		return Object_Base(data)
	}

	unreachable()
}

obj_is_truthy :: proc(obj: Object_Base) -> bool {
	#partial switch o in obj {
	case bool:
		return o

	case Obj_Null:
		return false

	case:
		return true
	}

	unreachable()
}

obj_is_return :: proc {
	obj_is_return_ptr,
	obj_is_return_val,
}

@(private = "file")
obj_is_return_ptr :: proc(obj: ^Object) -> bool {
	return reflect.union_variant_typeid(obj^) == Object_Return
}

@(private = "file")
obj_is_return_val :: proc(obj: Object) -> bool {
	return reflect.union_variant_typeid(obj) == Object_Return
}

obj_type :: proc {
	_obj_type_val,
	_obj_type_ptr,
}

@(private = "file")
_obj_type_val :: proc(obj: Object) -> typeid {
	return reflect.union_variant_typeid(to_object_base(obj))
}

@(private = "file")
_obj_type_ptr :: proc(obj: ^Object) -> typeid {
	return reflect.union_variant_typeid(to_object_base(obj^))
}

obj_inspect :: proc {
	_obj_inspect_ptr,
	_obj_inspect_val,
}

@(private = "file")
_obj_inspect_val :: proc(obj: Object, sb: ^st.Builder) {
	obj := obj
	_obj_inspect_ptr(&obj, sb)
}

@(private = "file")
_obj_inspect_ptr :: proc(obj: ^Object, sb: ^st.Builder) {
	obj := obj
	obj_base := to_object_base(obj)
	#partial switch data in obj_base {
	case bool, int, string:
		fmt.sbprint(sb, data)

	case Obj_Null:
		fmt.sbprint(sb, "(null)")

	case ^Obj_Function:
		fmt.sbprint(sb, "(function)")

	case Obj_Builtin_Fn:
		fmt.sbprint(sb, "(builtin function)")

	case ^Obj_Array:
		fmt.sbprint(sb, "[")
		for item, i in data {
			obj_inspect(item, sb)
			if i < len(data) - 1 do fmt.sbprint(sb, ", ")
		}
		fmt.sbprint(sb, "]")

	case ^Obj_Hash_Table:
		fmt.sbprint(sb, "{ ")
		i := 0
		for key, value in data {
			fmt.sbprintf(sb, "%s:", key)
			obj_inspect(value, sb)
			if i < len(data) - 1 do fmt.sbprint(sb, ", ")
			i += 1
		}
		fmt.sbprint(sb, " }")
	}
}
