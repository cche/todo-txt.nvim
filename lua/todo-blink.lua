--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}
local todo = require("todo-txt")
local parser = require("todo-txt.parser")
local ui = require("todo-txt.ui")
local due_helpers = require("todo-txt.due_helpers")

-- Get all unique contexts and projects from the todo file
local function get_all_completions()
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

-- Check if we're in the add/edit window
local function is_available()
  return ui.is_todo_input_window()
end

function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts or {}
  return self
end

-- Enable the source only in todo windows
function source:enabled()
  return is_available()
end

-- Non-alphanumeric characters that trigger the source
function source:get_trigger_characters()
  return { "@", "+", ":" }
end

function source:get_completions(ctx, callback)
  -- Only provide completions in the add window
  if not is_available() then
    callback({ items = {} })
    return
  end

  local completions = get_all_completions()
  local items = {}

  -- Get the current line and cursor position
  local line = ctx.line
  local col = ctx.cursor and ctx.cursor.col or ctx.cursor[2] or #line
  local row = ctx.cursor and ctx.cursor.row or ctx.cursor[1] or 0
  local before_cursor = line:sub(1, col)
  
  -- Check for due date shortcuts (e.g., :today, :tomorrow)
  -- Only trigger if preceded by space or at start of line to avoid conflict with priority syntax (A:)
  local due_shortcut = string.match(before_cursor, "%s(:[%w]*)$")
  if due_shortcut then
    local due_items = due_helpers.get_completion_items()
    for _, item in ipairs(due_items) do
      if item.shortcut:find(due_shortcut, 1, true) == 1 then
        local start_col = col - #due_shortcut
        table.insert(items, {
          label = item.shortcut,
          kind = pcall(require, 'blink.cmp.types') and require('blink.cmp.types').CompletionItemKind.Event or 5,
          detail = item.description .. " → due:" .. item.date,
          filterText = item.shortcut,
          textEdit = {
            newText = item.shortcut,
            range = {
              start = { line = row - 1, character = start_col },
              ["end"] = { line = row - 1, character = col },
            },
          },
          insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
        })
      end
    end
    callback({ items = items, is_incomplete_backward = false, is_incomplete_forward = false })
    return
  end
  
  -- Check for tag completions
  local current_word = string.match(before_cursor, "[@+][%w_%-]*$")

  if not current_word then
    callback({ items = {} })
    return
  end
  local prefix = current_word:sub(1, 1)
  local input = current_word:sub(2)

  -- Calculate the range to replace (from start of current_word to cursor)
  local start_col = col - #current_word
  local end_col = col

  if prefix == "@" then
    -- Context completion
    for _, context_name in ipairs(completions.contexts) do
      if context_name:lower():find(input:lower(), 1, true) then
        --- @type lsp.CompletionItem
        local item = {
          label = "@" .. context_name,
          kind = pcall(require, 'blink.cmp.types') and require('blink.cmp.types').CompletionItemKind.Text or 1,
          detail = "context",
          filterText = "@" .. context_name,
          textEdit = {
            newText = "@" .. context_name,
            range = {
              start = { line = row - 1, character = start_col },
              ["end"] = { line = row - 1, character = end_col },
            },
          },
          insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
        }
        table.insert(items, item)
      end
    end
  elseif prefix == "+" then
    -- Project completion
    for _, project in ipairs(completions.projects) do
      if project:lower():find(input:lower(), 1, true) then
        --- @type lsp.CompletionItem
        local item = {
          label = "+" .. project,
          kind = pcall(require, 'blink.cmp.types') and require('blink.cmp.types').CompletionItemKind.Keyword or 14,
          detail = "project",
          filterText = "+" .. project,
          textEdit = {
            newText = "+" .. project,
            range = {
              start = { line = row - 1, character = start_col },
              ["end"] = { line = row - 1, character = end_col },
            },
          },
          insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
        }
        table.insert(items, item)
      end
    end
  end

  callback({
    items = items,
    is_incomplete_backward = false,
    is_incomplete_forward = false,
  })
end

return source
