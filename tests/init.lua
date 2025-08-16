local plenary_test = require("plenary.test_harness")

plenary_test.setup()
-- Optional: Set up Neovim options for the tests
-- vim.opt.wrap = false  -- Example

-- Optional: Run tests in a separate process (more isolated)
-- spawn = true,

-- Run all specs in the 'tests' directory
plenary_test.run('tests/*_spec.lua')

-- RUN with :luafile tests/init.lua
