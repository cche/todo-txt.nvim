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
  table.insert(regions, {
    group = "TodoNumber",
    start_col = 0,
    end_col = 3,
  })

  -- Check if task is completed
  --[[
  if line:match("^%s*%d+%. x %d%d%d%d%-%d%d%-%d%d") then
		table.insert(regions, {
			group = "TodoCompleted",
			start_col = 4,
			end_col = -1,
		})
		return regions
	end
  ]]

  if line:match("^%s*%d+%. x") then
    table.insert(regions, {
      group = "TodoCompleted",
      start_col = 4,
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

  -- Highlight priorities (A-Z)
  local priority_start = line:find("%([A-Z]%)")
  if priority_start then
    table.insert(regions, {
      group = "TodoPriority",
      start_col = priority_start - 1,
      end_col = priority_start + 2,
    })
  end

  -- Highlight projects (+project)
  for start_idx in line:gmatch("()%+%w+") do
    local project = line:match("^%+%w+", start_idx)
    if project then
      table.insert(regions, {
        group = "TodoProject",
        start_col = start_idx - 1,
        end_col = start_idx + #project - 1,
      })
    end
  end

  -- Highlight contexts (@context)
  for start_idx in line:gmatch("()@%w+") do
    local context = line:match("^@%w+", start_idx)
    if context then
      table.insert(regions, {
        group = "TodoContext",
        start_col = start_idx - 1,
        end_col = start_idx + #context - 1,
      })
    end
  end

  -- Highlight due dates
  for start_idx, date in line:gmatch("()due:(%d%d%d%d%-%d%d%-%d%d)") do
    local due_date = os.time({
      year = tonumber(date:sub(1, 4)),
      month = tonumber(date:sub(6, 7)),
      day = tonumber(date:sub(9, 10)),
    })
    local today = os.time()
    local group = "TodoDue"
    if due_date < today then
      group = "TodoOverdue"
    end
    table.insert(regions, {
      group = group,
      start_col = start_idx - 1,
      end_col = start_idx + 3 + #date,
    })
  end

  return regions
end

return M
