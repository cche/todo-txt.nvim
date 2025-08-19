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

return M
