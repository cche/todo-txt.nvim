-- lua/todo-txt/ui.lua
local api = vim.api
local highlights = require("todo-txt.highlights")

local M = {}

local config = {}
local list_window = { buf = nil, win = nil }
local active_filters = { tag = nil, due = false }  -- tracks active filters (can be combined)

-- Create a single namespace for this plugin's highlights
local NS_ID = api.nvim_create_namespace("todo_txt_highlights")

function M.setup(opts)
  config = opts
end

-- Create a centered floating window
local function create_floating_window(width, height, title)
  local columns = vim.o.columns
  local lines = vim.o.lines

  -- Use config values if provided, otherwise calculate as 80% of screen space
  local win_width = width or config.window.width
  local win_height = height or config.window.height

  local win_opts = {
    relative = "editor",
    width = win_width,
    height = win_height,
    col = math.floor((columns - win_width) / 2),
    row = math.floor((lines - win_height) / 2),
    style = "minimal",
    border = config.window.border,
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

-- Helper function to check if we're in a todo input window (add/edit)
function M.is_todo_input_window()
  local ok, wt = pcall(api.nvim_win_get_var, 0, "todo_txt_window_type")
  return ok and (wt == "add" or wt == "edit")
end

-- Get current filter state
function M.get_active_filters()
  return active_filters
end

-- Set tag filter
function M.set_tag_filter(tag)
  active_filters.tag = tag
end

-- Toggle due filter
function M.toggle_due_filter()
  active_filters.due = not active_filters.due
  return active_filters.due
end

-- Clear all filters
function M.clear_filters()
  active_filters.tag = nil
  active_filters.due = false
end

-- Function to update list window contents
function M.update_list_window(entries, title)
  if not list_window.win or not api.nvim_win_is_valid(list_window.win) then
    -- Create new window if it doesn't exist or is invalid
    local buf, win = create_floating_window(nil, nil, title)
    list_window.buf = buf
    list_window.win = win
    -- Mark as todo list window
    pcall(api.nvim_win_set_var, win, "todo_txt_window_type", "todo")

    -- Set buffer filetype
    vim.bo[buf].filetype = "todo"

    -- Set keymaps for the todo list window
    local opts = { noremap = true, silent = true }
    api.nvim_buf_set_keymap(list_window.buf, "n", "q", "<cmd>q<CR>", opts)
    api.nvim_buf_set_keymap(
      list_window.buf,
      "n",
      "<CR>",
      '<cmd>lua require("todo-txt").toggle_selected_complete()<CR>',
      opts
    )
    api.nvim_buf_set_keymap(list_window.buf, "n", "s", '<cmd>lua require("todo-txt").toggle_selected_tracking()<CR>', opts)
    api.nvim_buf_set_keymap(list_window.buf, "n", "a", '<cmd>lua require("todo-txt").show_add_window()<CR>', opts)
    api.nvim_buf_set_keymap(list_window.buf, "n", "e", '<cmd>lua require("todo-txt").show_edit_window()<CR>', opts)
    api.nvim_buf_set_keymap(list_window.buf, "n", "p", '<cmd>lua require("todo-txt").show_priority_window()<CR>', opts)
    -- Filter by tag under cursor
    api.nvim_buf_set_keymap(
      list_window.buf,
      "n",
      "f",
      '<cmd>lua require("todo-txt").filter_by_tag_under_cursor()<CR>',
      opts
    )
    api.nvim_buf_set_keymap(list_window.buf, "n", "dd", '<cmd>lua require("todo-txt").delete_selected_entry()<CR>', opts)
    -- Toggle due filter
    api.nvim_buf_set_keymap(list_window.buf, "n", "d", '<cmd>lua require("todo-txt").toggle_due_filter()<CR>', opts)
    -- Clear all filters (show all)
    api.nvim_buf_set_keymap(list_window.buf, "n", "r", '<cmd>lua require("todo-txt").clear_all_filters()<CR>', opts)
  end

  -- Update window title if it changed
  if list_window.win and api.nvim_win_is_valid(list_window.win) then
    local win_config = api.nvim_win_get_config(list_window.win)
    if win_config.title and type(win_config.title) == "table" and win_config.title[1] and win_config.title[1][1] ~= title then
      win_config.title = title
      api.nvim_win_set_config(list_window.win, win_config)
    end
  end

  -- Clear and update buffer contents
  api.nvim_set_option_value("modifiable", true, { buf = list_window.buf })

  -- Prepare display lines with original file indexes
  local lines = {}
  for i, entry in ipairs(entries) do
    local index = entry.orig_index or entry.index or i
    local display_line = string.format("%2d. %s", index, entry.entry or entry)
    table.insert(lines, display_line)
  end

  api.nvim_buf_set_lines(list_window.buf, 0, -1, false, lines)

  -- Apply syntax highlighting
  api.nvim_buf_clear_namespace(list_window.buf, NS_ID, 0, -1)

  for i, line in ipairs(lines) do
    local regions = highlights.get_highlights(i, line)
    for _, region in ipairs(regions) do
      api.nvim_buf_add_highlight(list_window.buf, NS_ID, region.group, i - 1, region.start_col, region.end_col)
    end
  end

  api.nvim_set_option_value("modifiable", false, { buf = list_window.buf })
  
  -- Focus the window if it exists and is valid
  if list_window.win and api.nvim_win_is_valid(list_window.win) then
    api.nvim_set_current_win(list_window.win)
  end
  
  return list_window.buf, list_window.win
end

-- Refresh the current list window with the active filter
function M.refresh_current_list()
  -- Use user command to refresh - it will apply the current filter
  vim.cmd("TodoList")
end

-- Show edit window for an entry
function M.show_edit_window(index, original_entry)
  -- Create edit window
  local buf, win = create_floating_window(config.window.width, 1, " Edit Todo ")

  -- Set window type for completion source detection
  pcall(api.nvim_win_set_var, win, "todo_txt_window_type", "edit")
  
  -- Configure completion sources - disable other sources, enable only todo-txt
  local has_cmp, cmp = pcall(require, "cmp")
  if has_cmp then
    cmp.setup.buffer({
      sources = {
        { name = "todo-txt" }
      }
    })
  end
  
  -- Configure blink.cmp if available
  local has_blink, blink = pcall(require, "blink.cmp")
  if has_blink then
    -- Set buffer-local sources for blink.cmp to only show todo completions
    vim.api.nvim_buf_set_var(buf, "blink_cmp_sources", { "todo" })
  end

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

-- Show priority window for an entry
function M.show_priority_window(index)
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

function M.show_add_window()
  local buf, win = create_floating_window(config.window.width, 1, " Add Todo ")
  
  -- Set window type for completion source detection
  pcall(api.nvim_win_set_var, win, "todo_txt_window_type", "add")
  
  -- Configure completion sources - disable other sources, enable only todo-txt
  local has_cmp, cmp = pcall(require, "cmp")
  if has_cmp then
    cmp.setup.buffer({
      sources = {
        { name = "todo-txt" }
      }
    })
  end
  
  -- Configure blink.cmp if available
  local has_blink, blink = pcall(require, "blink.cmp")
  if has_blink then
    -- Set buffer-local sources for blink.cmp to only show todo completions
    vim.api.nvim_buf_set_var(buf, "blink_cmp_sources", { "todo" })
  end
  
  vim.cmd("startinsert")
  local opts = { noremap = true, silent = true }
  api.nvim_buf_set_keymap(buf, "i", "<CR>", '<Esc><cmd>lua require("todo-txt").submit_new_entry()<CR>', opts)
  api.nvim_buf_set_keymap(buf, "n", "<CR>", '<cmd>lua require("todo-txt").submit_new_entry()<CR>', opts)
  api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<Esc><cmd>q<CR>", opts)
end

return M
