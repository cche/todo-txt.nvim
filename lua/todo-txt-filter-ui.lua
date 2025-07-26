local api = vim.api
local filter = require("filter")
local M = {}

-- Helper to extract the tag under cursor (context or project)
local function get_tag_under_cursor()
  local line = api.nvim_get_current_line()
  local col = api.nvim_win_get_cursor(0)[2] + 1
  -- Find all tags in the line and their positions
  local tags = {}
  local search_start = 1
  while true do
    local start, stop = line:find("[@+][%w_%-]+", search_start)
    if not start then break end
    local tag = line:sub(start, stop)
    table.insert(tags, {start=start, stop=stop, tag=tag})
    search_start = stop + 1
  end
  for _, t in ipairs(tags) do
    if col >= t.start and col <= t.stop then
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
  local file_entries = require("todo-txt").get_entries()
  local entries = {}
  for i, line in ipairs(file_entries) do
    table.insert(entries, { entry = line, orig_index = i })
  end
  local filtered = filter.filter_by_tag(entries, tag)
  if #filtered == 0 then
    vim.notify("No tasks found for tag " .. tag, vim.log.levels.INFO)
    return
  end
  require("todo-txt").update_list_window(filtered, "todo", " Filter: " .. tag .. " ")
end

return M
