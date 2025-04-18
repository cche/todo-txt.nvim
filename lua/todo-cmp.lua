local source = {}
local todo = require("todo-txt")

source.new = function()
	return setmetatable({}, { __index = source })
end

-- Get all unique contexts and projects from the todo file
local function get_completions()
	local entries = todo.get_entries()
	local contexts = {}
	local projects = {}

	for _, entry in ipairs(entries) do
		-- Find all contexts (@context)
		for context in entry:gmatch("@(%w+)") do
			contexts[context] = true
		end
		-- Find all projects (+project)
		for project in entry:gmatch("%+(%w+)") do
			projects[project] = true
		end
	end

	return {
		contexts = vim.tbl_keys(contexts),
		projects = vim.tbl_keys(projects),
	}
end

source.get_trigger_characters = function()
	return { "@", "+" }
end

source.get_keyword_pattern = function()
	return [[\k*]]
end

-- Check if we're in the add window
function source.is_available()
	local win_config = vim.api.nvim_win_get_config(0)
	return win_config.title 
		and type(win_config.title) == "table"
		and win_config.title[1]
		and type(win_config.title[1]) == "table"
		and (win_config.title[1][1] == " Add Todo " or win_config.title[1][1] == " Edit Todo ")
end

source.complete = function(self, params, callback)
	-- Only provide completions in the add window
	if not source.is_available() then
		callback({})
		return
	end

	local completions = get_completions()
	local items = {}

	-- Get the current input
	local line = params.context.cursor_before_line
	local current_word = string.match(line, "[@+]%w*$")

	if not current_word then
		callback(items)
		return
	end

	local prefix = current_word:sub(1, 1)
	local input = current_word:sub(2)

	if prefix == "@" then
		-- Context completion
		for _, context in ipairs(completions.contexts) do
			if context:lower():find(input:lower(), 1, true) then
				table.insert(items, {
					label = "@" .. context,
					filterText = "@" .. context,
					insertText = context,
					kind = 15, -- Value for Text
					detail = "context",
				})
			end
		end
	elseif prefix == "+" then
		-- Project completion
		for _, project in ipairs(completions.projects) do
			if project:lower():find(input:lower(), 1, true) then
				table.insert(items, {
					label = "+" .. project,
					filterText = "+" .. project,
					insertText = project,
					kind = 14, -- Value for Keyword
					detail = "project",
				})
			end
		end
	end

	callback(items)
end

return source
