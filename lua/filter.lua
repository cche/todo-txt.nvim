local M = {}

-- Returns a filtered list of entries (table of {entry=..., orig_index=...}) that match the given context or project tag
function M.filter_by_tag(entries, tag)
  local is_context = tag:sub(1, 1) == "@"
  local is_project = tag:sub(1, 1) == "+"
  if not (is_context or is_project) then
    return {}
  end

  local filtered = {}
  for _, item in ipairs(entries) do
    local text = item.entry or item
    for word in text:gmatch("%S+") do
      if word == tag then
        table.insert(filtered, item)
        break
      end
    end
  end
  return filtered
end

function M.get_due_entries(entries)
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

return M
