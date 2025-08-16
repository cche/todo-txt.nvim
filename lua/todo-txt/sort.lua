local parser = require("todo-txt.parser")

local M = {}

local function priority_value(priority)
  if not priority then
    return 27 -- after Z
  end
  return string.byte(priority) - string.byte("A") + 1
end

-- entries: array of either strings or { entry=..., orig_index=... }
function M.sort_entries(entries)
  -- decorate with original positions for stability
  local decorated = {}
  for i, e in ipairs(entries) do
    decorated[i] = { idx = i, val = e }
  end

  table.sort(decorated, function(a, b)
    local ta = a.val.entry or a.val
    local tb = b.val.entry or b.val
    local pa = parser.extract_priority(ta)
    local pb = parser.extract_priority(tb)
    local ap = priority_value(pa)
    local bp = priority_value(pb)
    if ap ~= bp then
      return ap < bp
    end
    local da = parser.extract_due(ta)
    local db = parser.extract_due(tb)
    if da and db then
      if da ~= db then
        return da < db
      end
      -- stable tie-breaker
      return a.idx < b.idx
    elseif da then
      return true
    elseif db then
      return false
    end
    -- stable tie-breaker
    return a.idx < b.idx
  end)

  -- undecorate back to entries
  for i, item in ipairs(decorated) do
    entries[i] = item.val
  end
  return entries
end

return M
