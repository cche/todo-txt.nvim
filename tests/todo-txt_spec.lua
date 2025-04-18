local todo = require("todo-txt")
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
    todo.add_entry("(B) 2025-01-01 Task B due:2026-01-02")
    todo.add_entry("(A) 2025-01-01 Task A due:2026-01-01")
    todo.add_entry("Task C")
    local entries = todo.get_entries()
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
    todo.add_entry("Task A due:2025-01-01")
    todo.add_entry("Task B")
    todo.add_entry("Task C due:2025-01-02")
    local entries = todo.get_entries()
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
    local before = #todo.get_entries()
    todo.add_entry("New Task")
    local after = #todo.get_entries()
    assert.are.same(before + 1, after)
    assert.is_true(todo.get_entries()[after]:match("New Task") == "New Task")
  end)

  it("adds a priority to a task", function()
    todo.add_entry("Task with no priority")
    local idx = #todo.get_entries()
    local entry = todo.get_entries()[idx]
    entry = entry:gsub("^%([A-Z]%) ", "")
    todo.edit_entry(idx, "(A) " .. entry)
    local new_entry = todo.get_entries()[idx]
    assert.is_true(new_entry:match("%(A%)") == "(A)")
  end)

  it("edits a task", function()
    todo.add_entry("Task to edit")
    local idx = #todo.get_entries()
    todo.edit_entry(idx, "Edited Task")
    local entry = todo.get_entries()[idx]
    assert.equals(entry:match("Edited Task"), "Edited Task")
  end)

  it("marks a task as complete and toggles", function()
    todo.add_entry("Task to complete")
    local idx = #todo.get_entries()
    todo.toggle_mark_complete(idx)
    local entry = todo.get_entries()[idx]
    assert.equals(entry:match("^x "), "x ")
    todo.toggle_mark_complete(idx)
    entry = todo.get_entries()[idx]
    assert.is_true(entry:find("^x ") == nil)
  end)
end)
