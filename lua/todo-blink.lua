--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}
local todo = require("todo-txt")
local parser = require("todo-txt.parser")

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

-- Check if we're in the add window
local function is_available()
  -- Prefer window variable set by ui.lua
  local ok, wt = pcall(vim.api.nvim_win_get_var, 0, "todo_txt_window_type")
  if ok and (wt == "add" or wt == "edit") then
    return true
  end
  -- Fallback to title inspection
  local win_config = vim.api.nvim_win_get_config(0)
  if win_config.title
    and type(win_config.title) == "table"
    and win_config.title[1]
    and type(win_config.title[1]) == "table"
    and (win_config.title[1][1] == " Add Todo " or win_config.title[1][1] == " Edit Todo ") then
    return true
  end
  return false
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
  return { "@", "+" }
end

function source:get_completions(ctx, callback)
  -- Debug: Print that our source is being called
  print("todo-blink: get_completions called")
  
  -- Only provide completions in the add window
  if not is_available() then
    print("todo-blink: not available")
    callback({ items = {} })
    return
  end

  local completions = get_all_completions()
  print("todo-blink: found " .. #completions.contexts .. " contexts, " .. #completions.projects .. " projects")
  local items = {}

  -- Get the current line and cursor position
  local line = ctx.line
  local col = ctx.cursor and ctx.cursor.col or ctx.cursor[2] or #line
  local row = ctx.cursor and ctx.cursor.row or ctx.cursor[1] or 0
  print("todo-blink: line='" .. line .. "', col=" .. tostring(col) .. ", row=" .. tostring(row))
  local before_cursor = line:sub(1, col)
  local current_word = string.match(before_cursor, "[@+][%w_%-]*$")

  if not current_word then
    print("todo-blink: no trigger word found")
    callback({ items = {} })
    return
  end

  print("todo-blink: found trigger word '" .. current_word .. "'")
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
