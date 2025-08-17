local parser = require("todo-txt.parser")
local M = {}

-- Define highlight groups
function M.setup()
  local highlights = {
    TodoCompleted = { link = "Comment" },
    TodoDate = { link = "Special" },
    TodoPriority = { link = "Type" },
    TodoProject = { link = "Identifier" },
    TodoContext = { link = "String" },
    TodoNumber = { link = "Number" },
    TodoDue = { link = "WarningMsg" },
    TodoOverdue = { link = "ErrorMsg" },
  }

  for group, settings in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, settings)
  end
end

-- Function to get highlight groups for different parts of a todo entry
function M.get_highlights(line_nr, line)
  local regions = {}

  -- Highlight line number
  do
    local _, e = line:find("^%s*%d+%.%s")
    if e then
      table.insert(regions, {
        group = "TodoNumber",
        start_col = 0,
        end_col = e,
      })
    else
      table.insert(regions, {
        group = "TodoNumber",
        start_col = 0,
        end_col = 3,
      })
    end
  end

  -- Check if task is completed (consider numeric prefix)
  local _, num_end = line:find("^%s*%d+%.%s")
  local tail = num_end and line:sub(num_end + 1) or line
  if parser.is_done(tail) then
    local start_col = num_end or 0
    table.insert(regions, {
      group = "TodoCompleted",
      start_col = start_col,
      end_col = -1,
    })
    return regions
  end

  -- Highlight dates (YYYY-MM-DD)
  for start_idx, date in line:gmatch("()(%d%d%d%d%-%d%d%-%d%d)") do
    table.insert(regions, {
      group = "TodoDate",
      start_col = start_idx - 1,
      end_col = start_idx + 9,
    })
  end

  -- Highlight priorities (A-Z) anywhere in the rendered line
  local priority_start = line:find("%([A-Z]%)")
  if priority_start then
    table.insert(regions, {
      group = "TodoPriority",
      start_col = priority_start - 1,
      end_col = priority_start + 2,
    })
  end

  -- Highlight tags using parser-provided positions
  do
    local positions = parser.extract_tag_positions(line)
    for _, pos in ipairs(positions) do
      table.insert(regions, {
        group = (pos.kind == 'project') and "TodoProject" or "TodoContext",
        start_col = pos.start_col,
        end_col = pos.end_col,
      })
    end
  end

  -- Highlight due date (use parser to extract then locate span)
  do
    local date = parser.extract_due(line)
    if date then
      local needle = "due:" .. date
      local start_idx = line:find(needle, 1, true)
      if start_idx then
        local due_date = os.time({
          year = tonumber(date:sub(1, 4)),
          month = tonumber(date:sub(6, 7)),
          day = tonumber(date:sub(9, 10)),
          hour = 0, min = 0, sec = 0,
        })
        local now = os.date("*t")
        local today = os.time({year = now.year, month = now.month, day = now.day, hour = 0, min = 0, sec = 0})
        local group = (due_date < today) and "TodoOverdue" or "TodoDue"
        table.insert(regions, {
          group = group,
          start_col = start_idx - 1,
          end_col = start_idx - 1 + #needle,
        })
      end
    end
  end

  return regions
end

return M
