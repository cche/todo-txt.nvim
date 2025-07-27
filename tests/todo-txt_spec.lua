local todo = require("todo-txt")
local storage = require("storage")
local test_todo_file = "/tmp/todo-txt-test.txt"
local test_done_file = "/tmp/todo-txt-done.txt"

describe("todo-txt.nvim plugin", function()
  before_each(function()
    todo.config.todo_file = test_todo_file
    todo.config.done_file = test_done_file
    -- Clear files before each test
    local f = io.open(test_todo_file, "w")
    if f then
      f:close()
    end
    local f2 = io.open(test_done_file, "w")
    if f2 then
      f2:close()
    end
  end)

  after_each(function()
    os.remove(test_todo_file)
    os.remove(test_done_file)
  end)

  it("sorts the todo list by priority and due date", function()
    storage.write_entries(test_todo_file, {
      "(B) 2025-01-01 Task B due:2026-01-02",
      "(A) 2025-01-01 Task A due:2026-01-01",
      "2025-01-01 Task C",
    })
    local entries = storage.get_entries(test_todo_file)
    table.sort(entries, function(a, b)
      local pa, da = todo.extract_priority_and_due(a)
      local pb, db = todo.extract_priority_and_due(b)
      if todo.priority_value(pa) ~= todo.priority_value(pb) then
        return todo.priority_value(pa) < todo.priority_value(pb)
      end
      if da and db then
        return da < db
      elseif da then
        return true
      elseif db then
        return false
      end
      return false
    end)
    assert.is_true(entries[1]:match("%(A%)") == "(A)", "First should be priority A")
    assert.is_true(entries[2]:match("%(B%)") == "(B)", "Second should be priority B")
    assert.is_true(entries[3]:match("Task C") == "Task C", "Last should be unprioritized")
  end)

  it("shows only tasks with due date", function()
    storage.write_entries(test_todo_file, {
      "2025-01-01 Task A due:2025-01-01",
      "2025-01-01 Task B",
      "2025-01-01 Task C due:2025-01-02",
    })
    local entries = storage.get_entries(test_todo_file)
    local due = {}
    for _, e in ipairs(entries) do
      if e:match("due:%d%d%d%d%-%d%d%-%d%d") then
        table.insert(due, e)
      end
    end
    assert.are.same(2, #due)
    assert.equals(due[1]:match("Task A"), "Task A")
    assert.equals(due[2]:match("Task C"), "Task C")
  end)

  it("adds a new entry", function()
    local before = #storage.get_entries(test_todo_file)
    todo.add_entry("New Task")
    local after = #storage.get_entries(test_todo_file)
    assert.are.same(before + 1, after)
    assert.is_true(storage.get_entries(test_todo_file)[after]:match("New Task") == "New Task")
  end)

  it("adds a priority to a task", function()
    todo.add_entry("Task with no priority")
    local idx = #storage.get_entries(test_todo_file)
    local entry = storage.get_entries(test_todo_file)[idx]
    entry = entry:gsub("^%([A-Z]%) ", "")
    todo.edit_entry(idx, "(A) " .. entry)
    local new_entry = storage.get_entries(test_todo_file)[idx]
    assert.is_true(new_entry:match("%(A%)") == "(A)")
  end)

  it("edits a task", function()
    todo.add_entry("Task to edit")
    local idx = #storage.get_entries(test_todo_file)
    todo.edit_entry(idx, "Edited Task")
    local entry = storage.get_entries(test_todo_file)[idx]
    assert.equals(entry, "Edited Task")
  end)

  it("marks a task as complete and toggles", function()
    todo.add_entry("Task to complete")
    local idx = #storage.get_entries(test_todo_file)
    todo.toggle_mark_complete(idx)
    local entry = storage.get_entries(test_todo_file)[idx]
    assert.equals(entry:match("^x "), "x ")
    todo.toggle_mark_complete(idx)
    entry = storage.get_entries(test_todo_file)[idx]
    assert.is_true(entry:find("^x ") == nil)
  end)

  it("creates a task with priority", function()
    require("todo-txt").add_entry("My task", "A")
    local entries = require("storage").get_entries(test_todo_file)
    local last_entry = entries[#entries]
    assert.is_true(last_entry:match("^%(A%) %d%d%d%d%-%d%d%-%d%d My task$") ~= nil)
  end)

  it("filters tasks by tag", function()
    require("todo-txt").add_entry("Task with @Work tag")
    require("todo-txt").add_entry("Another task with @Home tag")
    require("todo-txt").add_entry("Third task with @Work tag")

    local entries = require("storage").get_entries(test_todo_file)
    local items = {}
    for i, line in ipairs(entries) do
      table.insert(items, { entry = line, orig_index = i })
    end

    local filtered = require("filter").filter_by_tag(items, "@Work")
    assert.are.same(2, #filtered)
    assert.is_true(filtered[1].entry:match("@Work") ~= nil)
    assert.is_true(filtered[2].entry:match("@Work") ~= nil)
  end)

  it("deletes a task", function()
    require("todo-txt").add_entry("Task to be deleted")
    local entries = require("storage").get_entries(test_todo_file)
    local num_entries_before = #entries
    require("todo-txt").delete_entry(num_entries_before)
    local entries_after = require("storage").get_entries(test_todo_file)
    assert.are.same(num_entries_before - 1, #entries_after)
  end)
end)
