local parser = require("todo-txt.parser")
local M = {}

-- Filter entries by tag (context or project)
local function filter_by_tag(entries, tag)
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

-- Filter entries that have due dates
local function filter_due(entries)
  local due_entries = {}

  for i, item in ipairs(entries) do
    local entry_text = item.entry or item
    local due = parser.extract_due(entry_text)
    if due then
      -- Preserve structure: maintain both index and orig_index for compatibility
      if item.orig_index then
        table.insert(due_entries, { entry = entry_text, orig_index = item.orig_index, index = item.orig_index, due = due })
      else
        table.insert(due_entries, { entry = entry_text, index = i, orig_index = i, due = due })
      end
    end
  end

  -- Sort by due date
  table.sort(due_entries, function(a, b)
    return a.due < b.due
  end)

  return due_entries
end

-- Unified filter interface
-- filter_type: nil (no filter), "due", or "tag"
-- filter_value: tag string (e.g., "@context" or "+project") when filter_type is "tag"
function M.filter_entries(entries, filter_type, filter_value)
  if filter_type == "due" then
    return filter_due(entries)
  elseif filter_type == "tag" and filter_value then
    return filter_by_tag(entries, filter_value)
  end
  return entries  -- no filter
end

-- Backward compatibility: keep old function names as wrappers
function M.filter_by_tag(entries, tag)
  return filter_by_tag(entries, tag)
end

function M.get_due_entries(entries)
  return filter_due(entries)
end

return M
