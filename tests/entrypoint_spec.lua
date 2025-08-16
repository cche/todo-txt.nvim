local todo = require("todo-txt")
local task = require("todo-txt.task")
local storage = require("todo-txt.storage")

describe("todo-txt public API and defaults", function()
  local test_dir
  local todo_file

  before_each(function()
    -- Use project base directory as test directory
    test_dir = vim.loop.cwd()
    todo_file = test_dir .. "/todo.txt"
    -- Use setup to ensure defaults (done_file) and module wiring are applied
    todo.setup({
      todo_file = todo_file,
    })
    -- Ensure clean files
    local f = io.open(todo_file, "w")
    if f then f:close() end
    local f2 = io.open(test_dir .. "/done.txt", "w")
    if f2 then f2:close() end
  end)

  after_each(function()
    -- Best-effort cleanup of files in project root
    pcall(vim.loop.fs_unlink, todo_file)
    pcall(vim.loop.fs_unlink, test_dir .. "/done.txt")
  end)

  it("exposes get_entries() returning file contents", function()
    storage.write_entries(todo_file, {
      "2025-01-01 Task A",
      "2025-01-02 Task B",
    })
    local entries = todo.get_entries()
    assert.are.same(2, #entries)
    assert.equals("2025-01-01 Task A", entries[1])
    assert.equals("2025-01-02 Task B", entries[2])
  end)

  it("archives to default done.txt when done_file not provided", function()
    -- Create and complete a task
    task.add_entry("Archive me")
    local idx = #todo.get_entries()
    task.toggle_mark_complete(idx)

    local archived = task.archive_done_tasks()
    assert.are.same(1, archived)

    local done_entries = storage.get_entries(test_dir .. "/done.txt")
    assert.are.same(1, #done_entries)
    assert.is_true(done_entries[1]:match("^x ") ~= nil)
  end)
end)
