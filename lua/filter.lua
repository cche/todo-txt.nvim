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

return M
