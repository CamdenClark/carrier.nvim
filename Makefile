# Default test command
TEST_CMD = nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests {minimal_init = 'tests/minimal.vim'}"

.PHONY: test

# Default target to run all tests
test:
	$(TEST_CMD)

# Target to run a specific test file
test-file:
ifdef FILE
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/$(FILE) {minimal_init = 'tests/minimal.vim'}"
else
	@echo "Please specify a test file using FILE=<filename>"
	@echo "Example: make test-file FILE=mytest.lua"
endif
