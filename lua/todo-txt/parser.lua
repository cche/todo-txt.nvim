local M = {}

-- Extract priority letter (A-Z) at start like: "(A) ..."
function M.extract_priority(line)
  return line:match("^%((%u)%)") or line:match("^x %((%u)%)")
end

-- Extract due date in YYYY-MM-DD after due:
function M.extract_due(line)
  return line:match("due:(%d%d%d%d%-%d%d%-%d%d)")
end

-- Determine if entry is completed (supports with/without priority preservation)
function M.is_done(line)
  return line:match("^x ") ~= nil
end

function M.is_tracking(line)
  return line:match("#Tracking") ~= nil
end
-- Extract creation date (first YYYY-MM-DD after optional priority/complete markers)
function M.extract_created(line)
  return line:match("%f[%d](%d%d%d%d%-%d%d%-%d%d)%f[^%d]")
end

-- Extract completion date if present after x (with or without priority in between)
function M.extract_completed(line)
  local with_pri = line:match("^x %([A-Z]%) (%d%d%d%d%-%d%d%-%d%d)")
  if with_pri then return with_pri end
  return line:match("^x (%d%d%d%d%-%d%d%-%d%d)")
end

-- Collect contexts (@tag) and projects (+tag) allowing letters, digits, _ and -
function M.extract_tags(line)
  local contexts, projects = {}, {}
  for ctx in line:gmatch("@([%w_%-]+)") do
    contexts[ctx] = true
  end
  for proj in line:gmatch("%+([%w_%-]+)") do
    projects[proj] = true
  end
  return contexts, projects
end

-- Return positional info for tags for highlighting
-- Each item: { kind = 'context'|'project', start_col = <0-based>, end_col = <exclusive> }
function M.extract_tag_positions(line)
  local positions = {}
  for start_idx, word in line:gmatch("()%+([%w_%-]+)") do
    local len = 1 + #word -- includes '+'
    table.insert(positions, {
      kind = 'project',
      start_col = start_idx - 1,
      end_col = (start_idx - 1) + len,
    })
  end
  for start_idx, word in line:gmatch("()@([%w_%-]+)") do
    local len = 1 + #word -- includes '@'
    table.insert(positions, {
      kind = 'context',
      start_col = start_idx - 1,
      end_col = (start_idx - 1) + len,
    })
  end
  return positions
end

-- Parse full line into a structured table
function M.parse(line)
  local raw_line = line
  local priority = M.extract_priority(line)
  local due = M.extract_due(line)
  local created = M.extract_created(line)
  local completed = M.extract_completed(line)
  local is_done = M.is_done(line)
  local contexts, projects = M.extract_tags(line)
  local start_time = M.extract_start_time(line)
  local end_time = M.extract_start_time(line)
  local is_tracking = M.extract_start_time(line)
  local tracked_time = M.extract_start_time(line)

  -- If completed and no leading priority, allow capturing priority immediately after 'x '
  if is_done and not priority then
    local pri_after_done = line:match("^x %((%u)%)")
    if pri_after_done then
      priority = pri_after_done
    end
  end

  -- Remove extracted parts from the line to get the pure description
  local description = line
  if is_done then
    description = description:gsub("^x %([A-Z]%) %d%d%d%d%-%d%d%-%d%d ", "", 1)
    description = description:gsub("^x %d%d%d%d%-%d%d%-%d%d ", "", 1)
  end
  if priority then
    description = description:gsub("^%([A-Z]%) ", "", 1)
  end
  if created then
    description = description:gsub("^%d%d%d%d%-%d%d%-%d%d ", "", 1)
  end
  description = description:gsub("^%s*", "") -- Trim leading spaces

  return {
    raw_line = raw_line,
    line = description, -- This will now be the pure description
    priority = priority,
    due = due,
    created = created,
    completed = completed,
    is_done = is_done,
    contexts = contexts,
    projects = projects,
    start_time = start_time,
    end_time = end_time,
    is_tracking = is_tracking,
    tracked_time = tracked_time
  }
end

return M
