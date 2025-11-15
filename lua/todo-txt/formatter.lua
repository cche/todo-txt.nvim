local M = {}

-- Formats a task table into a todo.txt string
function M.format(task_table)
  local parts = {}

  -- Add completion mark if done
  if task_table.is_done then
    table.insert(parts, "x")
  end

  if task_table.is_tracking then
    table.insert(parts, "#tracking_todo#")
  end

  if task_table.start_time then
    table.insert(parts, "start_time:" .. task_table.start_time)
  end

  if task_table.end_time then
    table.insert(parts, "end_time:" .. task_table.end_time)
  end

  if task_table.tracked_time then
    table.insert(parts, "total_time: ".. task_table.tracked_time)
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

  -- Add the pure task description
  table.insert(parts, task_table.line)

  return table.concat(parts, " ")
end

return M
