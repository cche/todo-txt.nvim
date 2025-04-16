local plenary_test = require("plenary.test_harness")

plenary_test.setup()
-- Optional: Set up Neovim options for the tests
-- vim.opt.wrap = false  -- Example

-- Optional: Run tests in a separate process (more isolated)
-- spawn = true,

-- Load and run your test files.  Glob patterns are supported.
plenary_test.run("tests/todo-txt_spec.lua")

-- Run all tests in the 'tests' directory
-- plenary_test.run('tests/**/*.lua')

-- Run tests with a specific name or pattern
-- plenary_test.run({'tests/test_your_plugin.lua:test_function_1'}) -- Run only test_function_1
-- plenary_test.run({'tests/test_your_plugin.lua:test_f*'}) -- Run tests that start with test_f*
--
-- RUN with :luafile tests/init.lua
