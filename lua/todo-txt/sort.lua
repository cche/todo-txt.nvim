local parser = require("todo-txt.parser")
local util = require("todo-txt.util")

local M = {}

-- priority_value is centralized in util

-- entries: array of either strings or { entry=..., orig_index=... }
function M.sort_entries(entries, opts)
  opts = opts or {}
  local order = opts.by or { 'priority', 'due' }
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
    local ap = util.priority_value(pa)
    local bp = util.priority_value(pb)
    local da = parser.extract_due(ta)
    local db = parser.extract_due(tb)

    local function cmp_key(key)
      if key == 'priority' then
        if ap ~= bp then return ap < bp end
      elseif key == 'due' then
        if da and db then
          if da ~= db then return da < db end
        elseif da then
          return true
        elseif db then
          return false
        end
      end
      return nil
    end

    for _, key in ipairs(order) do
      local res = cmp_key(key)
      if res ~= nil then return res end
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
