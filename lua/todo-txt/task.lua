-- lua/todo-txt/task.lua
local storage = require("todo-txt.storage")
local parser = require("todo-txt.parser")
local formatter = require("todo-txt.formatter")
local util = require("todo-txt.util")

local M = {}

-- Module-local configuration set via setup()
local config = {}

-- Initialize module configuration
function M.setup(cfg)
    config = cfg or {}
end

-- Validate index and return entry, notify on error
local function get_entry_by_index(index, entries)
    if index < 1 or index > #entries then
        util.notify_error(string.format("task: invalid index %s (entries: %d)", tostring(index), #entries))
        return nil
    end
    return entries[index]
end

local function is_valid_index(index, entries_count)
    if index < 1 or index > entries_count then
        util.notify_error(string.format("Invalid index %s (entries: %d)", tostring(index), entries_count))
        return false
    end
    return true
end

-- Function to add a new entry to the todo.txt file
function M.add_entry(entry_text, priority)
    if not entry_text or not entry_text:match("%S") then
        return false
    end

    local date = os.date("%Y-%m-%d")
    local task_table = {
        line = entry_text:gsub("^%s*(.-)%s*$", "%1"), -- This is now the pure description
        priority = priority and priority:match("^[A-Z]$") and priority or nil,
        created = date,
        is_done = false,
    }

    local formatted_entry = formatter.format(task_table)
    local entries = storage.get_entries(config.todo_file)
    table.insert(entries, formatted_entry)
    storage.write_entries(config.todo_file, entries)
    return true
end

-- Function to mark an entry as complete
function M.toggle_mark_complete(index)
    local entries = storage.get_entries(config.todo_file)
    local entry_line = get_entry_by_index(index, entries)
    if not entry_line then
        return false
    end

    local task_table = parser.parse(entry_line)

    if task_table.is_done then
        -- Unmark as completed
        task_table.is_done = false
        task_table.completed = nil
    else
        -- Mark as completed
        task_table.is_done = true
        task_table.completed = os.date("%Y-%m-%d")

        -- If task was being tracked when completed, stop tracking and calculate final time
        if task_table.is_tracking then
            task_table.is_tracking = false
            task_table.end_time = os.time()
            if task_table.tracked_time then
                -- Add current session to previously accumulated time
                local prevHour, prevMin, prevSec = parser.extract_previous_total(task_table.tracked_time)
                task_table.tracked_time = util.calculate_total_time(task_table.end_time, task_table.start_time, prevHour,
                    prevMin, prevSec)
            else
                -- First and final tracking session
                task_table.tracked_time = util.calculate_total_time(task_table.end_time, task_table.start_time, 0, 0, 0)
            end
        end
    end

    entries[index] = formatter.format(task_table)
    storage.write_entries(config.todo_file, entries)
    return true
end

-- Toggle time tracking on/off for a specific task
-- When starting tracking: sets is_tracking=true and records start_time
-- When stopping tracking: calculates total time including any previous sessions
function M.toggle_mark_tracking(index)
    local entries = storage.get_entries(config.todo_file)
    local entry_line = get_entry_by_index(index, entries)
    if not entry_line then
        return false
    end

    local task_table = parser.parse(entry_line)

    if task_table.is_tracking then
        -- Stop tracking: calculate and accumulate total time
        task_table.is_tracking = false
        task_table.end_time = os.time()
        if task_table.tracked_time then
            -- Add current session time to previously tracked time
            local prevHour, prevMin, prevSec = parser.extract_previous_total(task_table.tracked_time)
            task_table.tracked_time = util.calculate_total_time(task_table.end_time, task_table.start_time, prevHour,
                prevMin, prevSec)
        else
            -- First tracking session - start from zero
            task_table.tracked_time = util.calculate_total_time(task_table.end_time, task_table.start_time, 0, 0, 0)
        end
    else
        -- Start tracking: mark as active and record start time
        task_table.is_tracking = true
        task_table.start_time = os.time()
    end

    entries[index] = formatter.format(task_table)
    storage.write_entries(config.todo_file, entries)
    return true
end

function M.delete_entry(index)
    local entries = storage.get_entries(config.todo_file)
    local entry_line = get_entry_by_index(index, entries)
    if not entry_line then
        return false
    end
    table.remove(entries, index)
    storage.write_entries(config.todo_file, entries)
    return true
end

-- Function to edit an entry
function M.edit_entry(index, new_content)
    local entries = storage.get_entries(config.todo_file)
    local entry_line = get_entry_by_index(index, entries)
    if not entry_line then
        return nil
    end
    entries[index] = new_content
    storage.write_entries(config.todo_file, entries)
    -- Check if this should be returned.
    return entries
end

-- Function to set priority of an entry
function M.set_priority(index, priority)
    local entries = storage.get_entries(config.todo_file)
    local entry_line = get_entry_by_index(index, entries)
    if not entry_line then
        return false
    end

    local task_table = parser.parse(entry_line)

    if priority and priority:match("^[A-Z]$") then
        task_table.priority = priority
    else
        task_table.priority = nil
    end

    entries[index] = formatter.format(task_table)
    storage.write_entries(config.todo_file, entries)
    return true
end

-- Function to archive completed tasks
function M.archive_done_tasks()
    local entries = storage.get_entries(config.todo_file)
    local remaining_entries = {}
    local done_entries = {}

    -- Separate completed and uncompleted tasks
    for _, entry_line in ipairs(entries) do
        local task_table = parser.parse(entry_line)
        if task_table.is_done then
            table.insert(done_entries, entry_line)
        else
            table.insert(remaining_entries, entry_line)
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

    util.notify_warn("found no completed tasks to archive")
    return 0
end

return M
