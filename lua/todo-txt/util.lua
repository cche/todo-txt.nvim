local api = vim.api
local parser = require("todo-txt.parser")

local M = {}

function M.priority_value(priority)
  if not priority then
    return 27 -- after Z
  end
  return string.byte(priority) - string.byte("A") + 1
end

function M.notify_error(msg)
  vim.notify(msg, vim.log.levels.ERROR)
end

function M.notify_warn(msg)
  vim.notify(msg, vim.log.levels.WARN)
end

function M.get_current_task_index()
  local current_line = api.nvim_win_get_cursor(0)[1]
  local line_content = api.nvim_buf_get_lines(0, current_line - 1, current_line, false)[1]
  local index = tonumber(line_content:match("^%s*(%d+)%."))
  return index
end

-- Calculate total time from start/end timestamps plus any previously tracked time
-- Returns a formatted string like "tracked: 2h 30m 45s " or "tracked: 15m 30s "
-- @param end_time: Unix timestamp when tracking stopped
-- @param start_time: Unix timestamp when tracking started
-- @param prevHour: Previously accumulated hours from past sessions
-- @param prevMin: Previously accumulated minutes from past sessions
-- @param prevSec: Previously accumulated seconds from past sessions
function M.calculate_total_time(end_time, start_time, prevHour, prevMin, prevSec)
  local string = "tracked:"
  -- Calculate difference between start and end times
  local diffSec = os.difftime(tonumber(end_time), tonumber(start_time))
  local diffMin = diffSec / 60
  local diffHour = diffMin / 60
  local secMod = math.fmod(diffSec, 60)
  local minMod = math.fmod(diffMin, 60)

  -- Extract whole units from current session
  local secFlat = math.floor(secMod)
  local minFlat = math.floor(minMod)
  local hourFlat = math.floor(diffHour)

  -- Add current session time to previously accumulated time
  local totalSec = secFlat + tonumber(prevSec)
  local totalMin = minFlat + tonumber(prevMin)
  local totalHour = hourFlat + tonumber(prevHour)

  -- Handle seconds overflow (carry to minutes)
  if totalSec >= 60 then
    totalMin = totalMin + math.floor(totalSec / 60)
    totalSec = math.fmod(totalSec, 60)
  end

  -- Handle minutes overflow (carry to hours)
  if totalMin >= 60 then
    totalHour = totalHour + math.floor(totalMin / 60)
    totalMin = math.fmod(totalMin, 60)
  end

  -- Build formatted time string: 'tracked: XhXmXs'
  string = string .. totalHour .. "h"
  string = string .. totalMin .. "m"
  string = string .. totalSec .. "s"

  return string
end

return M
