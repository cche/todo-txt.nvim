-- todo.nvim - A Neovim plugin for todo.txt management
local api = vim.api
local storage = require("todo-txt.storage")
local task = require("todo-txt.task")
local ui = require("todo-txt.ui")
local filter = require("todo-txt.filter")
local highlights = require("todo-txt.highlights")
local parser = require("todo-txt.parser")
local sortmod = require("todo-txt.sort")
local util = require("todo-txt.util")
local M = {}

-- Configuration with defaults
M.config = {
  todo_file = vim.fn.expand("~/todo.txt"),
  done_file = nil,
  window = {
    width = math.floor(vim.o.columns * 0.8),
    height = math.floor(vim.o.lines * 0.8),
    border = "rounded",
  },
  sort = {
    by = { 'priority', 'due' },
  },
}

-- Helper to extract the tag under cursor (context or project)
local function get_tag_under_cursor()
  local line = api.nvim_get_current_line()
  local col = api.nvim_win_get_cursor(0)[2] + 1
  -- Find all tags in the line and their positions
  local tags = {}
  local search_start = 1
  while true do
    local start, stop = line:find("[@+][%w_%-]+", search_start)
    if not start then
      break
    end
    local tag = line:sub(start, stop)
    table.insert(tags, { start = start, stop = stop, tag = tag })
    search_start = stop + 1
  end
  for _, t in ipairs(tags) do
    if (col >= t.start and col <= t.stop) or (col == t.stop + 1) then
      return t.tag
    end
  end
  return nil
end

function M.filter_by_tag_under_cursor()
  local tag = get_tag_under_cursor()
  if not tag then
    vim.notify("No @context or +project tag under cursor", vim.log.levels.INFO)
    return
  end
  -- Get all entries (with orig_index)
  local file_entries = storage.get_entries(M.config.todo_file)
  local entries = {}
  for i, line in ipairs(file_entries) do
    table.insert(entries, { entry = line, orig_index = i })
  end
  local filtered = filter.filter_by_tag(entries, tag)
  if #filtered == 0 then
    vim.notify("No tasks found for tag " .. tag, vim.log.levels.INFO)
    return
  end
  ui.update_list_window(filtered, "todo", " Filter: " .. tag .. " ")
end

-- Helper function to extract priority and due date
function M.extract_priority_and_due(entry)
  local text = entry.entry or entry
  local priority = parser.extract_priority(text)
  local due = parser.extract_due(text)
  return priority, due
end

-- Function to get priority value
function M.priority_value(priority)
  return util.priority_value(priority)
end

-- Show edit window for an entry
function M.show_edit_window()
  local current_line = api.nvim_win_get_cursor(0)[1]
  local line_content = api.nvim_buf_get_lines(0, current_line - 1, current_line, false)[1]
  local index = tonumber(line_content:match("^%s*(%d+)%."))

  if not index then
    return
  end

  -- Get the original entry without the line number prefix
  local entries = storage.get_entries(M.config.todo_file)
  local original_entry = entries[index]

  ui.show_edit_window(index, original_entry)
end

-- Submit edited entry
function M.submit_edit(index)
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  local new_content = lines[1]

  local updated_entries = task.edit_entry(index, new_content)
  if updated_entries then
    -- Get the parent window before closing the edit window
    local parent_win = vim.fn.win_getid(vim.fn.winnr("#"))
    local window_type = ui.get_window_type(parent_win)

    -- Close the edit window
    api.nvim_win_close(0, true)

    -- Refresh the appropriate view
    if window_type == "due" then
      M.show_due_list()
    else
      M.show_todo_list()
    end
  end
end

-- Show priority window for an entry
function M.show_priority_window()
  local current_line = api.nvim_win_get_cursor(0)[1]
  local line_content = api.nvim_buf_get_lines(0, current_line - 1, current_line, false)[1]
  local index = tonumber(line_content:match("^%s*(%d+)%."))

  if not index then
    return
  end

  ui.show_priority_window(index)
end

-- Submit priority from priority window
function M.submit_priority()
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  local priority = lines[1]
  local index = api.nvim_buf_get_var(0, "todo_index")

  -- Close the priority window
  api.nvim_win_close(0, true)

  if task.set_priority(index, priority) then
    -- Get the parent window type and refresh
    local parent_win = vim.fn.win_getid(vim.fn.winnr("#"))
    local window_type = ui.get_window_type(parent_win)

    if window_type == "due" then
      M.show_due_list()
    else
      M.show_todo_list()
    end
  end
end

-- Display entries in floating window
function M.show_todo_list()
  local file_entries = storage.get_entries(M.config.todo_file)
  local entries = {}
  for i, line in ipairs(file_entries) do
    table.insert(entries, { entry = line, orig_index = i })
  end
  sortmod.sort_entries(entries, M.config.sort)
  return ui.update_list_window(entries, "todo", " Todo List ")
end

function M.show_due_list()
  local entries = storage.get_entries(M.config.todo_file)
  local due_entries = filter.get_due_entries(entries)
  return ui.update_list_window(due_entries, "due", " Due Tasks ")
end

function M.get_entries()
  return storage.get_entries(M.config.todo_file)
end

function M.show_add_window()
  ui.show_add_window()
end

function M.submit_new_entry()
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  local entry = lines[1]

  -- Extract priority from the entry (if provided)
  local priority, task_text = entry:match("^([A-Z]):%s*(.+)$")

  if not priority then
    task_text = entry
  end

  if task.add_entry(task_text, priority) then
    -- Get the parent window before closing the add window
    local parent_win = vim.fn.win_getid(vim.fn.winnr("#"))
    local window_type = ui.get_window_type(parent_win)

    -- Close the add window
    api.nvim_win_close(0, true)

    -- Refresh the appropriate view based on the parent window type
    if window_type == "due" then
      M.show_due_list()
    else
      M.show_todo_list()
    end
  end
end

function M.delete_selected_entry()
  local current_line = api.nvim_win_get_cursor(0)[1]
  local line_content = api.nvim_buf_get_lines(0, current_line - 1, current_line, false)[1]
  local index = tonumber(line_content:match("^%s*(%d+)%."))
  if index and task.delete_entry(index) then
    local window_type = ui.get_window_type(0)
    if window_type == "due" then
      M.show_due_list()
    else
      M.show_todo_list()
    end
  end
end

function M.toggle_selected_complete()
  local current_line = api.nvim_win_get_cursor(0)[1]
  local line_content = api.nvim_buf_get_lines(0, current_line - 1, current_line, false)[1]
  local index = tonumber(line_content:match("^%s*(%d+)%."))
  if index and task.toggle_mark_complete(index) then
    local window_type = ui.get_window_type(0)
    if window_type == "due" then
      M.show_due_list()
    else
      M.show_todo_list()
    end
  end
end

-- Set up commands
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.config.todo_file = vim.fn.expand(M.config.todo_file)
  if not M.config.done_file or M.config.done_file == "" then
    local dir
    if vim.fs and vim.fs.dirname then
      dir = vim.fs.dirname(M.config.todo_file)
      M.config.done_file = vim.fs.joinpath(dir, "done.txt")
    else
      dir = vim.fn.fnamemodify(M.config.todo_file, ":h")
      M.config.done_file = dir .. "/done.txt"
    end
  else
    M.config.done_file = vim.fn.expand(M.config.done_file)
  end

  -- Pass config to other modules
  task.setup(M.config)
  ui.setup(M.config)

  -- Set up highlight groups
  highlights.setup()

  -- Create user commands
  api.nvim_create_user_command("TodoList", M.show_todo_list, {})
  api.nvim_create_user_command("TodoAdd", M.show_add_window, {})
  api.nvim_create_user_command("TodoDue", M.show_due_list, {})
  api.nvim_create_user_command("TodoArchive", task.archive_done_tasks, {})

  -- Create default key mappings if not disabled
  if not (opts and opts.disable_default_mappings) then
    vim.keymap.set("n", "<leader>tt", M.show_todo_list, { desc = "Todo List", noremap = true, silent = true })
    vim.keymap.set("n", "<leader>ta", M.show_add_window, { desc = "Add Todo", noremap = true, silent = true })
    vim.keymap.set("n", "<leader>td", M.show_due_list, { desc = "Due Tasks", noremap = true, silent = true })
    vim.keymap.set(
      "n",
      "<leader>tz",
      task.archive_done_tasks,
      { desc = "Archive Done Tasks", noremap = true, silent = true }
    )
  end

  -- Register nvim-cmp source
  local has_cmp, cmp = pcall(require, "cmp")
  if has_cmp then
    cmp.register_source("todo-txt", require("todo-cmp").new())
  end
end

return M