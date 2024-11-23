package monkey_evaluator

import "core:fmt"
import "core:reflect"
import st "core:strings"

import ma "../ast"

Obj_Null :: struct {}
Obj_Function :: struct {
	parameters: [dynamic]ma.Node_Identifier,
	body:       ma.Node_Block_Expression,
	env:        ^Environment,
}

Object_Base :: union {
	int,
	bool,
	string,

	// Objects
	Obj_Null,
	^Obj_Function,
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
	return Obj_Null{}
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
	}
}
