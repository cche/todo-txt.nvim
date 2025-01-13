-- todo.nvim - A Neovim plugin for todo.txt management
local api = vim.api
local highlights = require("highlights")
local M = {}

-- Configuration with defaults
M.config = {
	todo_file = vim.fn.expand("~/src/repos/todo-txt.nvim/todo.txt"),
	window = {
		width = 60,
		height = 10,
		border = "rounded",
	},
}

-- Create a centered floating window
local function create_floating_window(width, height, title)
	local columns = vim.o.columns
	local lines = vim.o.lines

	-- Calculate dimensions (80% of screen space)
	local win_width = width or math.floor(columns * 0.8)
	local win_height = height or math.floor(lines * 0.8)

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

-- Function to read the todo.txt file and return a list of entries
function M.get_entries()
	local file = io.open(M.config.todo_file, "r")
	if not file then
		-- Create the file if it doesn't exist
		file = io.open(M.config.todo_file, "w")
		if file then
			file:close()
			file = io.open(M.config.todo_file, "r")
		else
			error("Could not create todo.txt file")
		end
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
			entries[index] = "x " .. completion_date .. " " .. entry
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
		return entries
	end
	return nil
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
	api.nvim_buf_set_keymap(buf, "i", "<Esc>", "<Esc><cmd>q<CR>", opts)
	api.nvim_buf_set_keymap(
		buf,
		"n",
		"<CR>",
		string.format('<cmd>lua require("todo-txt").submit_edit(%d)<CR>', index),
		opts
	)
	api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>q<CR>", opts)

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
		-- Get the parent buffer and check its type
		local parent_buf = vim.fn.bufnr("#")
		local parent_type = vim.bo[parent_buf].filetype

		-- Close the edit window
		api.nvim_win_close(0, true)

		-- Refresh the appropriate view
		if parent_type == "todo" then
			-- Check if we were in the due list by looking at the window title
			local parent_win = vim.fn.win_findbuf(parent_buf)[1]
			if parent_win then
				local win_config = api.nvim_win_get_config(parent_win)
				if
					win_config
					and win_config.title
					and type(win_config.title) == "string"
					and win_config.title:match("Due Tasks")
				then
					M.show_due_list()
				else
					M.show_todo_list()
				end
			end
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

-- Display due entries in floating window
function M.show_due_list()
	local due_entries = get_due_entries()
	local buf, win = create_floating_window(nil, nil, " Due Tasks ")

	-- Set buffer filetype
	vim.bo[buf].filetype = "todo"

	-- Prepare display lines with numbers and highlighting
	local lines = {}
	for _, entry in ipairs(due_entries) do
		local display_line = string.format("%2d. %s", entry.index, entry.entry)
		table.insert(lines, display_line)
	end

	api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Apply syntax highlighting
	api.nvim_buf_clear_namespace(buf, -1, 0, -1)
	local ns_id = api.nvim_create_namespace("todo_highlights")

	for i, line in ipairs(lines) do
		local regions = highlights.get_highlights(i, line)
		for _, region in ipairs(regions) do
			api.nvim_buf_add_highlight(buf, ns_id, region.group, i - 1, region.start_col, region.end_col)
		end
	end

	-- Set keymaps for the todo list window
	local opts = { noremap = true, silent = true }
	api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>q<CR>", opts)
	api.nvim_buf_set_keymap(buf, "n", "<CR>", '<cmd>lua require("todo-txt").mark_selected_complete()<CR>', opts)
	api.nvim_buf_set_keymap(buf, "n", "a", '<cmd>lua require("todo-txt").show_add_window()<CR>', opts)
	api.nvim_buf_set_keymap(buf, "n", "e", '<cmd>lua require("todo-txt").show_edit_window()<CR>', opts)

	-- Make buffer non-modifiable after setting content
	vim.bo[buf].modifiable = false
end

-- Display todo list in floating window
function M.show_todo_list()
	local entries = M.get_entries()
	local buf, win = create_floating_window(nil, nil, " Todo List ")

	-- Set buffer filetype
	vim.bo[buf].filetype = "todo"

	-- Prepare display lines with numbers
	local lines = {}
	for i, entry in ipairs(entries) do
		local display_line = string.format("%2d. %s", i, entry)
		table.insert(lines, display_line)
	end

	api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Apply syntax highlighting
	api.nvim_buf_clear_namespace(buf, -1, 0, -1)
	local ns_id = api.nvim_create_namespace("todo_highlights")

	for i, line in ipairs(lines) do
		local regions = highlights.get_highlights(i, line)
		for _, region in ipairs(regions) do
			api.nvim_buf_add_highlight(buf, ns_id, region.group, i - 1, region.start_col, region.end_col)
		end
	end

	-- Set keymaps for the todo list window
	local opts = { noremap = true, silent = true }
	api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>q<CR>", opts)
	api.nvim_buf_set_keymap(buf, "n", "<CR>", '<cmd>lua require("todo-txt").mark_selected_complete()<CR>', opts)
	api.nvim_buf_set_keymap(buf, "n", "a", '<cmd>lua require("todo-txt").show_add_window()<CR>', opts)
	api.nvim_buf_set_keymap(buf, "n", "e", '<cmd>lua require("todo-txt").show_edit_window()<CR>', opts)

	-- Make buffer non-modifiable after setting content
	vim.bo[buf].modifiable = false
end

-- Show add entry window
function M.show_add_window()
	local buf, win = create_floating_window(M.config.window.width, 1, " Add Todo ")

	-- Enable insert mode immediately
	vim.cmd("startinsert")

	-- Set keymaps for the add window
	local opts = { noremap = true, silent = true }
	api.nvim_buf_set_keymap(buf, "i", "<CR>", '<Esc><cmd>lua require("todo-txt").submit_new_entry()<CR>', opts)
	api.nvim_buf_set_keymap(buf, "i", "<Esc>", "<Esc><cmd>q<CR>", opts)
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

-- Mark selected item as complete
function M.mark_selected_complete()
	local current_line = api.nvim_win_get_cursor(0)[1]
	local line_content = api.nvim_buf_get_lines(0, current_line - 1, current_line, false)[1]
	local index = tonumber(line_content:match("^%s*(%d+)%."))

	if mark_complete(index) then
		api.nvim_win_close(0, true)
		M.show_todo_list() -- Refresh the list
	end
end

-- Set up commands
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Set up highlight groups
	highlights.setup()

	-- Create user commands
	api.nvim_create_user_command("TodoList", M.show_todo_list, {})
	api.nvim_create_user_command("TodoAdd", M.show_add_window, {})
	api.nvim_create_user_command("TodoDue", M.show_due_list, {})

	-- Create default key mappings if not disabled
	if not (opts and opts.disable_default_mappings) then
		vim.keymap.set("n", "<leader>tt", M.show_todo_list, { desc = "Todo List", noremap = true, silent = true })
		vim.keymap.set("n", "<leader>ta", M.show_add_window, { desc = "Add Todo", noremap = true, silent = true })
		vim.keymap.set("n", "<leader>td", M.show_due_list, { desc = "Due Tasks", noremap = true, silent = true })
	end

	-- Register nvim-cmp source
	local has_cmp, cmp = pcall(require, "cmp")
	if has_cmp then
		cmp.register_source("todo-txt", require("todo-cmp").new())
	end
end

return M
