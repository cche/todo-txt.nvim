-- lua/task.lua
local storage = require("storage")

local M = {}

local config = {}

function M.setup(opts)
  config = opts
end

-- Function to add a new entry to the todo.txt file
function M.add_entry(entry, priority)
  if entry and entry:match("%S") then
    local date = os.date("%Y-%m-%d")
    local formatted_entry = ""

    -- Extract priority if provided
    if priority and priority:match("^[A-Z]$") then
      formatted_entry = formatted_entry .. "(" .. priority .. ") "
    end

    formatted_entry = formatted_entry .. date .. " "

    -- Trim whitespace from the task text
    local task_text = entry:gsub("^%s*(.-)%s*$", "%1")
    formatted_entry = formatted_entry .. task_text

    local entries = storage.get_entries(config.todo_file)
    table.insert(entries, formatted_entry)
    storage.write_entries(config.todo_file, entries)
    return true
  end
  return false
end

-- Function to mark an entry as complete
function M.toggle_mark_complete(index)
  local entries = storage.get_entries(config.todo_file)
  if index < 1 or index > #entries then
    vim.notify(
      string.format("todo-txt: toggle_mark_complete() invalid index %s (entries: %d)", tostring(index), #entries),
      vim.log.levels.ERROR
    )
    return false
  end
  if index >= 1 and index <= #entries then
    local entry = entries[index]
    -- if not completed mark as completed
    if not entry:match("^x ") then
      local completion_date = os.date("%Y-%m-%d")
      -- Check if entry has priority and capture both priority letter and rest of the task
      local priority_letter, rest = entry:match("^%(([A-Z])%) (.+)$")
      if priority_letter then
        -- Keep x at start, but put completion date after priority
        entries[index] = "x (" .. priority_letter .. ") " .. completion_date .. " " .. rest
      else
        -- If no priority, add completion mark and date at the start
        entries[index] = "x " .. completion_date .. " " .. entry
      end
      storage.write_entries(config.todo_file, entries)
      return true
    end
    -- Check if completed and it has a priority
    local priority, rest = entry:match("^x %(([A-Z])%) %d%d%d%d%-%d%d%-%d%d (.+)$")
    if priority then
      entries[index] = "(" .. priority .. ") " .. rest
      storage.write_entries(config.todo_file, entries)
      return true
    end
    -- if completed, unmark it
    rest = entry:match("^x %d%d%d%d%-%d%d%-%d%d (.+)$")
    if rest then
      entries[index] = rest
      storage.write_entries(config.todo_file, entries)
      return true
    end
    vim.notify(
      string.format("todo-txt: toggle_mark_complete() could not toggle entry at index %d (unexpected format)", index),
      vim.log.levels.WARN
    )
  end
  return false
end

function M.delete_entry(index)
  local entries = storage.get_entries(config.todo_file)
  if index >= 1 and index <= #entries then
    table.remove(entries, index)
    storage.write_entries(config.todo_file, entries)
    return true
  end
  vim.notify(
    string.format("todo-txt: delete_entry() invalid index %s (entries: %d)", tostring(index), #entries),
    vim.log.levels.ERROR
  )
  return false
end

-- Function to edit an entry
function M.edit_entry(index, new_content)
  local entries = storage.get_entries(config.todo_file)
  if index >= 1 and index <= #entries then
    entries[index] = new_content
    storage.write_entries(config.todo_file, entries)
    -- Check if this should be returned.
    return entries
  end
  vim.notify(
    string.format("todo-txt: edit_entry() invalid index %s (entries: %d)", tostring(index), #entries),
    vim.log.levels.ERROR
  )
  return nil
end

-- Function to set priority of an entry
function M.set_priority(index, priority)
  local entries = storage.get_entries(config.todo_file)
  if index >= 1 and index <= #entries then
    local entry = entries[index]
    -- Remove existing priority if any
    entry = entry:gsub("^%([A-Z]%) ", "")
    -- Add new priority if provided and valid
    if priority and priority:match("^[A-Z]$") then
      entry = "(" .. priority .. ") " .. entry
    end
    entries[index] = entry
    storage.write_entries(config.todo_file, entries)
    return true
  end
  vim.notify(
    string.format("todo-txt: set_priority() invalid index %s (entries: %d)", tostring(index), #entries),
    vim.log.levels.ERROR
  )
  return false
end

-- Function to archive completed tasks
function M.archive_done_tasks()
  local entries = storage.get_entries(config.todo_file)
  local remaining_entries = {}
  local done_entries = {}

  -- Separate completed and uncompleted tasks
  for _, entry in ipairs(entries) do
    if entry:match("^x ") then
      table.insert(done_entries, entry)
    else
      table.insert(remaining_entries, entry)
    end
  end

  -- If we found completed tasks
  if #done_entries > 0 then
    -- Write remaining tasks back to todo.txt
    storage.write_entries(config.todo_file, remaining_entries)

    -- Append completed tasks to done.txt
    storage.append_to_done_file(config.done_file, done_entries)

    -- Return number of archived tasks
    return #done_entries
  end

  vim.notify("todo-txt: archive_done_tasks() found no completed tasks to archive", vim.log.levels.INFO)
  return 0
end

return M
