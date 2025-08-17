local M = {}

-- Extract priority letter (A-Z) at start like: "(A) ..."
function M.extract_priority(line)
  return line:match("^%((%u)%)")
end

-- Extract due date in YYYY-MM-DD after due:
function M.extract_due(line)
  return line:match("due:(%d%d%d%d%-%d%d%-%d%d)")
end

-- Determine if entry is completed (supports with/without priority preservation)
function M.is_done(line)
  return line:match("^x ") ~= nil
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
  local priority = M.extract_priority(line)
  local due = M.extract_due(line)
  local created = M.extract_created(line)
  local completed = M.extract_completed(line)
  local is_done = M.is_done(line)
  local contexts, projects = M.extract_tags(line)
  return {
    line = line,
    priority = priority,
    due = due,
    created = created,
    completed = completed,
    is_done = is_done,
    contexts = contexts,
    projects = projects,
  }
end

return M
