local M = {}

function M.check()
  local health = vim.health or require("health")
  
  health.start("todo-txt.nvim")
  
  -- Check if todo file exists
  local todo = require("todo-txt")
  if todo.config and todo.config.todo_file then
    if vim.fn.filereadable(todo.config.todo_file) == 1 then
      health.ok("Todo file exists: " .. todo.config.todo_file)
    else
      health.warn("Todo file not found: " .. todo.config.todo_file)
    end
  else
    health.error("Todo file not configured")
  end
  
  -- Check if done file is writable
  if todo.config and todo.config.done_file then
    local dir = vim.fn.fnamemodify(todo.config.done_file, ":h")
    if vim.fn.isdirectory(dir) == 1 then
      health.ok("Done file directory exists: " .. dir)
    else
      health.error("Done file directory does not exist: " .. dir)
    end
  end
  
  -- Check for completion sources
  local has_cmp = pcall(require, "cmp")
  local has_blink = pcall(require, "blink.cmp")
  
  if has_cmp then
    health.ok("nvim-cmp detected")
  end
  
  if has_blink then
    health.ok("blink.cmp detected")
  end
  
  if not has_cmp and not has_blink then
    health.info("No completion framework detected (optional)")
  end
  
  -- Check plenary for tests
  local has_plenary = pcall(require, "plenary")
  if has_plenary then
    health.ok("plenary.nvim available for testing")
  else
    health.info("plenary.nvim not found (only needed for development)")
  end
end

return M
