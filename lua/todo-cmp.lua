local source = {}
local todo = require("todo-txt")
local parser = require("todo-txt.parser")
local ui = require("todo-txt.ui")
local due_helpers = require("todo-txt.due_helpers")

source.new = function()
  return setmetatable({}, { __index = source })
end

-- Get all unique contexts and projects from the todo file
local function get_completions()
  local entries = todo.get_entries()
  local contexts = {}
  local projects = {}

  for _, entry in ipairs(entries) do
    local ctxs, projs = parser.extract_tags(entry)
    for k in pairs(ctxs) do
      contexts[k] = true
    end
    for k in pairs(projs) do
      projects[k] = true
    end
  end

  return {
    contexts = vim.tbl_keys(contexts),
    projects = vim.tbl_keys(projects),
  }
end

source.get_trigger_characters = function()
  return { "@", "+", ":" }
end

source.get_keyword_pattern = function()
  -- return [[[\w\-]*]]
  return [[\k*]]
end

-- Check if we're in the add/edit window
function source.is_available()
  return ui.is_todo_input_window()
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
  
  -- Check for due date shortcuts (e.g., :today, :tomorrow)
  -- Only trigger if preceded by space or at start of line to avoid conflict with priority syntax (A:)
  local due_shortcut = string.match(line, "%s(:[%w]*)$")
  if due_shortcut then
    local due_items = due_helpers.get_completion_items()
    for _, item in ipairs(due_items) do
      if item.shortcut:find(due_shortcut, 1, true) == 1 then
        table.insert(items, {
          label = item.shortcut,
          kind = require("cmp").lsp.CompletionItemKind.Event,
          detail = item.description .. " → due:" .. item.date,
          insertText = item.shortcut,
        })
      end
    end
    callback(items)
    return
  end
  
  -- Check for tag completions
  local current_word = string.match(line, "[@+][%w_%-]*$")

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
