local M = {}

-- Formats a task table into a todo.txt string
function M.format(task_table)
  local parts = {}

  -- Add completion mark if done
  if task_table.is_done then
    table.insert(parts, "x")
  end

  -- Add priority if present
  if task_table.priority then
    table.insert(parts, "(" .. task_table.priority .. ")")
  end

  -- Add creation date if present
  if task_table.created then
    table.insert(parts, task_table.created)
  end

  -- Add completion date after creation if present
  if task_table.is_done and task_table.completed then
    table.insert(parts, task_table.completed)
  end

  -- Add time tracking marker if task is currently being tracked
  if task_table.is_tracking then
    table.insert(parts, "#track#")
  end

  -- Add accumulated time tracking information if present
  if task_table.tracked_time then
    table.insert(parts, task_table.tracked_time)
  end

  -- Add the pure task description
  table.insert(parts, task_table.line)

  -- Add start timestamp for active or completed tracking sessions
  if task_table.start_time then
    table.insert(parts, "start:" .. task_table.start_time)
  end

  -- Add end timestamp when tracking session is stopped
  if task_table.end_time then
    table.insert(parts, "end:" .. task_table.end_time)
  end

  return table.concat(parts, " ")
end

return M
