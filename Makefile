run:
	odin run . -vet -debug -out:monkey_odin.exe

test:
	odin test ./tests -vet -sanitize:address -define:ODIN_TEST_SHORT_LOGS=false -define:ODIN_TEST_ALWAYS_REPORT_MEMORY=true