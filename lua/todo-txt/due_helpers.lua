-- Due date helper functions for quick date entry
local M = {}

-- Get date string in YYYY-MM-DD format
local function format_date(year, month, day)
  return string.format("%04d-%02d-%02d", year, month, day)
end

local function get_current_date()
    local time = os.time()
    local date = os.date("*t", time)
    return format_date(date.year, date.month, date.day)
end

-- Add days to current date
local function add_days(days)
  local time = os.time() + (days * 24 * 60 * 60)
  local date = os.date("*t", time)
  return format_date(date.year, date.month, date.day)
end

-- Get date for next occurrence of a weekday (1=Monday, 7=Sunday)
local function next_weekday(target_day)
  local today = os.date("*t")
  local current_day = (today.wday == 1) and 7 or (today.wday - 1) -- Convert Sunday=1 to Sunday=7
  
  local days_ahead = target_day - current_day
  if days_ahead <= 0 then
    days_ahead = days_ahead + 7
  end
  
  return add_days(days_ahead)
end

-- Map of shortcuts to their date functions
M.shortcuts = {
  [":today"] = function() return add_days(0) end,
  [":tomorrow"] = function() return add_days(1) end,
  [":nextweek"] = function() return add_days(7) end,
  [":monday"] = function() return next_weekday(1) end,
  [":tuesday"] = function() return next_weekday(2) end,
  [":wednesday"] = function() return next_weekday(3) end,
  [":thursday"] = function() return next_weekday(4) end,
  [":friday"] = function() return next_weekday(5) end,
  [":saturday"] = function() return next_weekday(6) end,
  [":sunday"] = function() return next_weekday(7) end,
  [":1d"] = function() return add_days(1) end,
  [":2d"] = function() return add_days(2) end,
  [":3d"] = function() return add_days(3) end,
  [":1w"] = function() return add_days(7) end,
  [":2w"] = function() return add_days(14) end,
  [":1m"] = function() return add_days(30) end,
  [":start"] = function() return get_current_date() end,
  [":end"] = function() return get_current_date() end,
}

-- Expand due date shortcuts in text
-- Example: "Task :today" -> "Task due:2025-01-23"
function M.expand_shortcuts(text)
  if not text then return text end
  
  local modified = text
  
  for shortcut, date_fn in pairs(M.shortcuts) do
    -- Match shortcut at word boundary or after space
    local pattern = "(%s)" .. shortcut:gsub(":", "%%:") .. "(%s?)"
    modified = modified:gsub(pattern, function(before, after)
      local date = date_fn()
      -- If there's already a due: prefix before, don't add another
      if before:match("due:$") then
        return before .. date .. after
      else
        return before .. "due:" .. date .. after
      end
    end)
  end
  
  return modified
end

-- Get list of available shortcuts for completion
function M.get_shortcuts_list()
  local list = {}
  for shortcut, _ in pairs(M.shortcuts) do
    table.insert(list, shortcut)
  end
  table.sort(list)
  return list
end

-- Get completion items for due date shortcuts
function M.get_completion_items()
  local items = {}
  
  local descriptions = {
    [":today"] = "Today",
    [":tomorrow"] = "Tomorrow",
    [":nextweek"] = "Next week",
    [":monday"] = "Next Monday",
    [":tuesday"] = "Next Tuesday",
    [":wednesday"] = "Next Wednesday",
    [":thursday"] = "Next Thursday",
    [":friday"] = "Next Friday",
    [":saturday"] = "Next Saturday",
    [":sunday"] = "Next Sunday",
    [":1d"] = "1 day from now",
    [":2d"] = "2 days from now",
    [":3d"] = "3 days from now",
    [":1w"] = "1 week from now",
    [":2w"] = "2 weeks from now",
    [":1m"] = "1 month from now",
  }
  
  for shortcut, date_fn in pairs(M.shortcuts) do
    local date = date_fn()
    table.insert(items, {
      shortcut = shortcut,
      date = date,
      description = descriptions[shortcut] or shortcut,
      display = string.format("%s (%s → due:%s)", shortcut, descriptions[shortcut] or "", date)
    })
  end
  
  -- Sort by shortcut name
  table.sort(items, function(a, b) return a.shortcut < b.shortcut end)
  
  return items
end

return M
