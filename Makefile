ARGS=-vet -no-bounds-check
ARGS_DBG=-vet -debug
EXE_NAME=monkey_odin.exe

build:
	odin build . $(ARGS) -out:$(EXE_NAME)

build_dbg:
	odin build . $(ARGS_DBG) -out:$(EXE_NAME)

run:
	odin run . $(ARGS_DBG) -out:$(EXE_NAME)

test:
	odin test ./tests -vet -sanitize:address -define:ODIN_TEST_SHORT_LOGS=false -define:ODIN_TEST_ALWAYS_REPORT_MEMORY=true