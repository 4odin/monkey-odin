package monkey_tests

import "core:log"
import st "core:strings"
import "core:testing"

import m "../monkey"

@(test)
test_ast_to_string :: proc(t: ^testing.T) {
	another_var := m.Node(m.Node_Identifier{value = "another_var"})

	program := m.Node_Program{m.Node(m.Node_Let_Statement{name = "my_var", value = &another_var})}
	defer delete(program)

	sb := st.builder_make(context.temp_allocator)
	defer free_all(context.temp_allocator)
	m.ast_to_string(program, &sb)

	expected := "let my_var = another_var;"

	if st.to_string(sb) != expected {
		log.errorf(
			"ast_to_string returned wrong value for program, expected='%s', got='%s'",
			expected,
			st.to_string(sb),
		)
		testing.fail(t)
	}
}
