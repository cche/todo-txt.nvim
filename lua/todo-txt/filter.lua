local parser = require("todo-txt.parser")
local M = {}

-- Returns a filtered list of entries (table of {entry=..., orig_index=...}) that match the given context or project tag
function M.filter_by_tag(entries, tag)
  local is_context = tag:sub(1, 1) == "@"
  local is_project = tag:sub(1, 1) == "+"
  if not (is_context or is_project) then
    return {}
  end

  local key = tag:sub(2)
  local filtered = {}
  for _, item in ipairs(entries) do
    local contexts, projects = parser.extract_tags(item.entry)
    if (is_context and contexts[key]) or (is_project and projects[key]) then
      table.insert(filtered, item)
    end
  end
  return filtered
end

function M.get_due_entries(entries)
  local due_entries = {}

  for i, entry in ipairs(entries) do
    local due = parser.extract_due(entry)
    if due then
      -- Keep the original index for marking as complete
      table.insert(due_entries, { index = i, entry = entry, due = due })
    end
  end

  -- Sort by due date
  table.sort(due_entries, function(a, b)
    return a.due < b.due
  end)

  return due_entries
end

return M
