-- lua/storage.lua
local M = {}

-- Function to get entries from todo.txt file
function M.get_entries(file_path)
  local file = io.open(file_path, "r")
  if not file then
    vim.notify("Could not open todo.txt file: " .. file_path, vim.log.levels.ERROR)
    return {}
  end

  local entries = {}
  for line in file:lines() do
    if line ~= "" then
      table.insert(entries, line)
    end
  end
  file:close()
  return entries
end

-- Function to write entries back to file
function M.write_entries(file_path, entries)
  local file = io.open(file_path, "w")
  if not file then
    vim.notify("Could not open todo.txt file for writing: " .. file_path, vim.log.levels.ERROR)
    return false
  end
  for _, entry in ipairs(entries) do
    file:write(entry .. "\n")
  end
  file:close()
  return true
end

-- Function to append entries to done.txt
function M.append_to_done_file(file_path, entries)
  -- Ensure directory exists
  local dir = vim.fn.fnamemodify(file_path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  
  local file = io.open(file_path, "a")
  if not file then
    vim.notify("Could not open done.txt file for writing: " .. file_path, vim.log.levels.ERROR)
    return false
  end
  for _, entry in ipairs(entries) do
    file:write(entry .. "\n")
  end
  file:close()
  return true
end

return M
