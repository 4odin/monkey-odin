package monkey_evaluator

import "core:fmt"
import "core:reflect"
import st "core:strings"

Null :: struct {}

Object :: union {
	int,
	bool,
	string,

	// Objects
	Null,
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
	_obj_inspect_main,
	_obj_inspect_alter,
}

@(private = "file")
_obj_inspect_alter :: proc(obj: Object, sb: ^st.Builder) {
	obj := obj
	_obj_inspect_main(&obj, sb)
}

@(private = "file")
_obj_inspect_main :: proc(obj: ^Object, sb: ^st.Builder) {
	#partial switch data in obj {
	case bool, int, string:
		fmt.sbprint(sb, data)

	case Null:
		fmt.sbprint(sb, "(null)")
	}
}
