package monkey_evaluator

import "core:fmt"
import "core:reflect"
import st "core:strings"

Null :: struct {}

Object_Base :: union {
	int,
	bool,
	string,

	// Objects
	Null,
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

	// unreachable
	return Null{}
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

_obj_type_val :: reflect.union_variant_typeid

@(private = "file")
_obj_type_ptr :: proc(obj: ^Object) -> typeid {
	return reflect.union_variant_typeid(obj^)
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

	case Null:
		fmt.sbprint(sb, "(null)")
	}
}
