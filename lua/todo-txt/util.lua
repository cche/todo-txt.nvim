local api = vim.api

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

function M.calculate_total_time(end_time, start_time, prev_end, prev_start)
  local prevSec = 0
  local prevMin = 0
  local prevHour = 0

  if prev_end and prev_start then
    local prevDiffSec = os.difftime(prev_end, prev_start)
    local prevDiffMin = prevDiffSec / 60
    local prevDiffHour = prevDiffMin / 60
    local prevSecMod = math.fmod(prevDiffSec, 60)
    local prevMinMod = math.fmod(prevDiffMin, 60)

    prevSec = math.floor(prevSecMod)
    prevMin = math.floor(prevMinMod)
    prevHour = math.floor(prevDiffHour)
  end

  local string = 'total_time: '
  local diffSec = os.difftime(end_time, start_time)
  local diffMin = diffSec / 60
  local diffHour = diffMin / 60
  local secMod = math.fmod(diffSec, 60)
  local minMod = math.fmod(diffMin, 60)

  local secFlat = math.floor(secMod)
  local minFlat = math.floor(minMod)
  local hourFlat = math.floor(diffHour)

  if hourFlat > 0 then
    string = string .. hourFlat + prevHour .. " Hours "
  end

  if minFlat > 0 then
    string = string .. minFlat + prevMin.. " Minutes "
  end

  if hourFlat < 1 and secFlat > 0 then
    string = string .. secFlat + prevSec .. " Seconds"
  end

  return string
end

return M
