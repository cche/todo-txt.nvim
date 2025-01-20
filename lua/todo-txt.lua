-- todo.nvim - A Neovim plugin for todo.txt management
local api = vim.api
local highlights = require("highlights")
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
}

-- Store references to the main list windows
local list_windows = {
  todo = { buf = nil, win = nil },
  due = { buf = nil, win = nil },
}

-- Create a centered floating window
local function create_floating_window(width, height, title)
  local columns = vim.o.columns
  local lines = vim.o.lines

  -- Use config values if provided, otherwise calculate as 80% of screen space
  local win_width = width or M.config.window.width
  local win_height = height or M.config.window.height

  local win_opts = {
    relative = "editor",
    width = win_width,
    height = win_height,
    col = math.floor((columns - win_width) / 2),
    row = math.floor((lines - win_height) / 2),
    style = "minimal",
    border = M.config.window.border,
    title = title,
    title_pos = "center",
  }

  local buf = api.nvim_create_buf(false, true)
  local win = api.nvim_open_win(buf, true, win_opts)

  -- Set window-local options
  vim.wo[win].wrap = true
  vim.bo[buf].modifiable = true
  vim.bo[buf].buftype = "nofile"

  return buf, win
end

-- Helper function to get parent window type
local function get_window_type(win_id)
  local win_config = win_id and api.nvim_win_get_config(win_id)
  if
    win_config
    and win_config.title
    and type(win_config.title) == "table"
    and win_config.title[1]
    and type(win_config.title[1]) == "table"
  then
    local title = win_config.title[1][1]
    if title == " Due Tasks " then
      return "due"
    elseif title == " Todo List " then
      return "todo"
    end
  end
  return nil
end

-- Function to update list window contents
local function update_list_window(entries, window_type, title)
  local win_info = list_windows[window_type]
  if not win_info or not win_info.win or not api.nvim_win_is_valid(win_info.win) then
    -- Create new window if it doesn't exist or is invalid
    local buf, win = create_floating_window(nil, nil, title)
    win_info = { buf = buf, win = win }
    list_windows[window_type] = win_info

    -- Set buffer filetype
    vim.bo[buf].filetype = "todo"

    -- Set keymaps for the todo list window
    local opts = { noremap = true, silent = true }
    api.nvim_buf_set_keymap(win_info.buf, "n", "q", "<cmd>q<CR>", opts)
    api.nvim_buf_set_keymap(
      win_info.buf,
      "n",
      "<CR>",
      '<cmd>lua require("todo-txt").mark_selected_complete()<CR>',
      opts
    )
    api.nvim_buf_set_keymap(win_info.buf, "n", "a", '<cmd>lua require("todo-txt").show_add_window()<CR>', opts)
    api.nvim_buf_set_keymap(win_info.buf, "n", "e", '<cmd>lua require("todo-txt").show_edit_window()<CR>', opts)
    api.nvim_buf_set_keymap(win_info.buf, "n", "p", '<cmd>lua require("todo-txt").show_priority_window()<CR>', opts)
  end

  -- Clear and update buffer contents
  api.nvim_set_option_value("modifiable", true, { buf = win_info.buf })

  -- Prepare display lines with numbers
  local lines = {}
  for i, entry in ipairs(entries) do
    local index = entry.index or i
    local display_line = string.format("%2d. %s", index, entry.entry or entry)
    table.insert(lines, display_line)
  end

  api.nvim_buf_set_lines(win_info.buf, 0, -1, false, lines)

  -- Apply syntax highlighting
  api.nvim_buf_clear_namespace(win_info.buf, -1, 0, -1)
  local ns_id = api.nvim_create_namespace("todo_highlights")

  for i, line in ipairs(lines) do
    local regions = highlights.get_highlights(i, line)
    for _, region in ipairs(regions) do
      api.nvim_buf_add_highlight(win_info.buf, ns_id, region.group, i - 1, region.start_col, region.end_col)
    end
  end

  api.nvim_set_option_value("modifiable", false, { buf = win_info.buf })
  return win_info.buf, win_info.win
end

-- Function to get entries from todo.txt file
function M.get_entries()
  local file = io.open(M.config.todo_file, "r")
  if not file then
    error("Could not open todo.txt file")
  end

  local entries = {}
  for line in file:lines() do
    if line ~= "" then
      table.insert(entries, line)
    end
  end
  file:close()
  return entries
end

-- Function to write entries back to file
local function write_entries(entries)
  local file = io.open(M.config.todo_file, "w")
  if not file then
    error("Could not open todo.txt file for writing")
  end
  for _, entry in ipairs(entries) do
    file:write(entry .. "\n")
  end
  file:close()
end

-- Function to add a new entry to the todo.txt file
local function add_entry(entry)
  if entry and entry:match("%S") then -- Check if entry is not empty or just whitespace
    local date = os.date("%Y-%m-%d")
    local formatted_entry = date .. " " .. entry:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
    local entries = M.get_entries()
    table.insert(entries, formatted_entry)
    write_entries(entries)
    return true
  end
  return false
end

-- Function to mark an entry as complete
local function mark_complete(index)
  local entries = M.get_entries()
  if index >= 1 and index <= #entries then
    local entry = entries[index]
    if not entry:match("^x %d%d%d%d%-%d%d%-%d%d") then
      local completion_date = os.date("%Y-%m-%d")
      -- Check if entry has priority and capture both priority letter and rest of the task
      local priority_letter, rest = entry:match("^%(([A-Z])%) (.+)$")
      if priority_letter then
        -- Keep x at start, but put completion date after priority
        entries[index] = "x (" .. priority_letter .. ") " .. completion_date .. " " .. rest
      else
        -- If no priority, add completion mark and date at the start
        entries[index] = "x " .. completion_date .. " " .. entry
      end
      write_entries(entries)
      return true
    end
  end
  return false
end

-- Function to edit an entry
local function edit_entry(index, new_content)
  local entries = M.get_entries()
  if index >= 1 and index <= #entries then
    entries[index] = new_content
    write_entries(entries)
    -- Check if this should be returned.
    return entries
  end
  return nil
end

-- Function to set priority of an entry
local function set_priority(index, priority)
  local entries = M.get_entries()
  if index >= 1 and index <= #entries then
    local entry = entries[index]
    -- Remove existing priority if any
    entry = entry:gsub("^%([A-Z]%) ", "")
    -- Add new priority if provided and valid
    if priority and priority:match("^[A-Z]$") then
      entry = "(" .. priority .. ") " .. entry
    end
    entries[index] = entry
    write_entries(entries)
    return true
  end
  return false
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
  local entries = M.get_entries()
  local original_entry = entries[index]

  -- Create edit window
  local buf, win = create_floating_window(M.config.window.width, 1, " Edit Todo ")

  -- Set the original content
  api.nvim_buf_set_lines(buf, 0, -1, false, { original_entry })

  -- Set keymaps for the edit window
  local opts = { noremap = true, silent = true }
  api.nvim_buf_set_keymap(
    buf,
    "i",
    "<CR>",
    string.format('<Esc><cmd>lua require("todo-txt").submit_edit(%d)<CR>', index),
    opts
  )
  api.nvim_buf_set_keymap(
    buf,
    "n",
    "<CR>",
    string.format('<cmd>lua require("todo-txt").submit_edit(%d)<CR>', index),
    opts
  )
  api.nvim_buf_set_keymap(buf, "n", "<esc>", "<cmd>q<CR>", opts)

  -- Enable insert mode
  vim.cmd("startinsert!")
  vim.cmd("normal! $")
end

-- Submit edited entry
function M.submit_edit(index)
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  local new_content = lines[1]

  local updated_entries = edit_entry(index, new_content)
  if updated_entries then
    -- Get the parent window before closing the edit window
    local parent_win = vim.fn.win_getid(vim.fn.winnr("#"))
    local window_type = get_window_type(parent_win)

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

  -- Create priority window
  local buf, win = create_floating_window(30, 1, " Set Priority (A-Z) ")

  -- Set keymaps for the priority window
  local opts = { noremap = true, silent = true }

  -- Handle any single character input
  api.nvim_buf_set_keymap(buf, "i", "<CR>", "<Esc><cmd>lua require('todo-txt').submit_priority()<CR>", opts)
  api.nvim_buf_set_keymap(buf, "i", "<Esc>", "<Esc><cmd>q<CR>", opts)

  -- Store the task index in a buffer variable
  api.nvim_buf_set_var(buf, "todo_index", index)

  -- Enable insert mode
  vim.cmd("startinsert")
end

-- Submit priority from priority window
function M.submit_priority()
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  local priority = lines[1]
  local index = api.nvim_buf_get_var(0, "todo_index")

  -- Close the priority window
  api.nvim_win_close(0, true)

  if set_priority(index, priority) then
    -- Get the parent window type and refresh
    local parent_win = vim.fn.win_getid(vim.fn.winnr("#"))
    local window_type = get_window_type(parent_win)

    if window_type == "due" then
      M.show_due_list()
    else
      M.show_todo_list()
    end
  end
end

-- Function to filter entries by due date
local function get_due_entries()
  local entries = M.get_entries()
  local due_entries = {}

  for i, entry in ipairs(entries) do
    if entry:match("due:%d%d%d%d%-%d%d%-%d%d") then
      -- Keep the original index for marking as complete
      table.insert(due_entries, { index = i, entry = entry })
    end
  end

  -- Sort by due date
  table.sort(due_entries, function(a, b)
    local date_a = a.entry:match("due:(%d%d%d%d%-%d%d%-%d%d)")
    local date_b = b.entry:match("due:(%d%d%d%d%-%d%d%-%d%d)")
    return date_a < date_b
  end)

  return due_entries
end

-- Display entries in floating window
function M.show_todo_list()
  local entries = M.get_entries()
  return update_list_window(entries, "todo", " Todo List ")
end

-- Display due entries in floating window
function M.show_due_list()
  local due_entries = get_due_entries()
  return update_list_window(due_entries, "due", " Due Tasks ")
end

-- Show add entry window
function M.show_add_window()
  local buf, win = create_floating_window(M.config.window.width, 1, " Add Todo ")

  -- Enable insert mode immediately
  vim.cmd("startinsert")

  -- Set keymaps for the add window
  local opts = { noremap = true, silent = true }
  api.nvim_buf_set_keymap(buf, "i", "<CR>", '<Esc><cmd>lua require("todo-txt").submit_new_entry()<CR>', opts)
  api.nvim_buf_set_keymap(buf, "n", "<CR>", '<cmd>lua require("todo-txt").submit_new_entry()<CR>', opts)
  api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<Esc><cmd>q<CR>", opts)
end

-- Submit new entry from add window
function M.submit_new_entry()
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  local entry = lines[1]
  if add_entry(entry) then
    api.nvim_win_close(0, true)
    M.show_todo_list() -- Refresh the main todo list
  end
end

-- Mark selected entry as complete
function M.mark_selected_complete()
  local current_line = api.nvim_win_get_cursor(0)[1]
  local line_content = api.nvim_buf_get_lines(0, current_line - 1, current_line, false)[1]
  local index = tonumber(line_content:match("^%s*(%d+)%."))

  if index and mark_complete(index) then
    -- Get the current window type
    local window_type = get_window_type(0)

    -- Refresh the appropriate view
    if window_type == "due" then
      M.show_due_list()
    else
      M.show_todo_list()
    end
  end
end

-- Function to get the done file path
local function get_done_file()
  -- If done_file is not set, use the same directory as todo_file with "done.txt" name
  if not M.config.done_file then
    local todo_dir = vim.fn.fnamemodify(M.config.todo_file, ":h")
    M.config.done_file = todo_dir .. "/done.txt"
  end
  return M.config.done_file
end

-- Function to append entries to done.txt
local function append_to_done_file(entries)
  local done_file = get_done_file()
  local file = io.open(done_file, "a")
  if not file then
    error("Could not open done.txt file for writing")
  end
  for _, entry in ipairs(entries) do
    file:write(entry .. "\n")
  end
  file:close()
end

-- Function to archive completed tasks
function M.archive_done_tasks()
  local entries = M.get_entries()
  local remaining_entries = {}
  local done_entries = {}

  -- Separate completed and uncompleted tasks
  for _, entry in ipairs(entries) do
    if entry:match("^x ") then
      table.insert(done_entries, entry)
    else
      table.insert(remaining_entries, entry)
    end
  end

  -- If we found completed tasks
  if #done_entries > 0 then
    -- Write remaining tasks back to todo.txt
    write_entries(remaining_entries)

    -- Append completed tasks to done.txt
    append_to_done_file(done_entries)

    -- Refresh the current view
    local window_type = get_window_type(0)

    if window_type == "due" then
      M.show_due_list()
    else
      M.show_todo_list()
    end

    -- Return number of archived tasks
    return #done_entries
  end

  return 0
end

-- Set up commands
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.config.todo_file = vim.fn.expand(M.config.todo_file)
  if M.config.done_file then
    M.config.done_file = vim.fn.expand(M.config.done_file)
  end

  -- Set up highlight groups
  highlights.setup()

  -- Create user commands
  api.nvim_create_user_command("TodoList", M.show_todo_list, {})
  api.nvim_create_user_command("TodoAdd", M.show_add_window, {})
  api.nvim_create_user_command("TodoDue", M.show_due_list, {})
  api.nvim_create_user_command("TodoArchive", M.archive_done_tasks, {})

  -- Create default key mappings if not disabled
  if not (opts and opts.disable_default_mappings) then
    vim.keymap.set("n", "<leader>tt", M.show_todo_list, { desc = "Todo List", noremap = true, silent = true })
    vim.keymap.set("n", "<leader>ta", M.show_add_window, { desc = "Add Todo", noremap = true, silent = true })
    vim.keymap.set("n", "<leader>td", M.show_due_list, { desc = "Due Tasks", noremap = true, silent = true })
    vim.keymap.set(
      "n",
      "<leader>tz",
      M.archive_done_tasks,
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
