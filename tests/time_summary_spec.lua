local time_summary = require("todo-txt.time_summary")
local storage = require("todo-txt.storage")
local task = require("todo-txt.task")

describe("time_summary", function()
  local config = { todo_file = vim.fn.tempname(), done_file = vim.fn.tempname() }
  task.setup(config)

  before_each(function()
    pcall(vim.loop.fs_unlink, config.todo_file)
    pcall(vim.loop.fs_unlink, config.done_file)
    local f = io.open(config.todo_file, "w")
    if f then
      f:close()
    end
    local f2 = io.open(config.done_file, "w")
    if f2 then
      f2:close()
    end
  end)

  describe("aggregate_time_by_tags", function()
    it("should aggregate time by projects", function()
      local entries = {
        "(A) 2024-01-01 Task 1 +project1 @context1 tracked:1h30m0s",
        "(B) 2024-01-02 Task 2 +project1 @context2 tracked:2h15m30s",
        "(C) 2024-01-03 Task 3 +project2 @context1 tracked:0h45m15s",
      }
      storage.write_entries(config.todo_file, entries)

      local summary = time_summary.aggregate_time_by_tags(config)

      assert.equals(13530, summary.projects["project1"])
      assert.equals(2715, summary.projects["project2"])
    end)

    it("should aggregate time by contexts", function()
      local entries = {
        "(A) 2024-01-01 Task 1 +project1 @context1 tracked:1h30m0s",
        "(B) 2024-01-02 Task 2 +project1 @context2 tracked:2h15m30s",
        "(C) 2024-01-03 Task 3 +project2 @context1 tracked:0h45m15s",
      }
      storage.write_entries(config.todo_file, entries)

      local summary = time_summary.aggregate_time_by_tags(config)

      assert.equals(8115, summary.contexts["context1"])
      assert.equals(8130, summary.contexts["context2"])
    end)

    it("should calculate total time", function()
      local entries = {
        "(A) 2024-01-01 Task 1 +project1 @context1 tracked:1h30m0s",
        "(B) 2024-01-02 Task 2 +project1 @context2 tracked:2h15m30s",
        "(C) 2024-01-03 Task 3 +project2 @context1 tracked:0h45m15s",
      }
      storage.write_entries(config.todo_file, entries)

      local summary = time_summary.aggregate_time_by_tags(config)

      assert.equals(16245, summary.total)
    end)

    it("should include tasks from both todo.txt and done.txt", function()
      local todo_entries = {
        "(A) 2024-01-01 Task 1 +project1 tracked:1h0m0s",
      }
      local done_entries = {
        "x 2024-01-02 2024-01-01 Task 2 +project1 tracked:2h0m0s",
      }
      storage.write_entries(config.todo_file, todo_entries)
      storage.write_entries(config.done_file, done_entries)

      local summary = time_summary.aggregate_time_by_tags(config)

      assert.equals(10800, summary.projects["project1"])
      assert.equals(10800, summary.total)
    end)

    it("should handle tasks without tracked time", function()
      local entries = {
        "(A) 2024-01-01 Task 1 +project1",
        "(B) 2024-01-02 Task 2 +project2 tracked:1h0m0s",
      }
      storage.write_entries(config.todo_file, entries)

      local summary = time_summary.aggregate_time_by_tags(config)

      assert.is_nil(summary.projects["project1"])
      assert.equals(3600, summary.projects["project2"])
      assert.equals(3600, summary.total)
    end)

    it("should handle tasks with multiple projects and contexts", function()
      local entries = {
        "(A) 2024-01-01 Task 1 +project1 +project2 @context1 @context2 tracked:1h0m0s",
      }
      storage.write_entries(config.todo_file, entries)

      local summary = time_summary.aggregate_time_by_tags(config)

      assert.equals(3600, summary.projects["project1"])
      assert.equals(3600, summary.projects["project2"])
      assert.equals(3600, summary.contexts["context1"])
      assert.equals(3600, summary.contexts["context2"])
      assert.equals(3600, summary.total)
    end)

    it("should return empty summary when no tasks have tracked time", function()
      local entries = {
        "(A) 2024-01-01 Task 1 +project1",
        "(B) 2024-01-02 Task 2 +project2",
      }
      storage.write_entries(config.todo_file, entries)

      local summary = time_summary.aggregate_time_by_tags(config)

      assert.is_true(next(summary.projects) == nil)
      assert.is_true(next(summary.contexts) == nil)
      assert.equals(0, summary.total)
    end)
  end)

  describe("format_summary", function()
    it("should format summary with projects and contexts", function()
      local summary = {
        projects = { project1 = 5400, project2 = 3600 },
        contexts = { context1 = 7200, context2 = 1800 },
        total = 9000,
      }

      local lines = time_summary.format_summary(summary)

      assert.is_true(#lines > 0)
      assert.is_not_nil(lines[1]:match("Time Tracking Summary"))
      local has_project = false
      local has_context = false
      for _, line in ipairs(lines) do
        if line:match("%+project1") then
          has_project = true
        end
        if line:match("@context1") then
          has_context = true
        end
      end
      assert.is_true(has_project)
      assert.is_true(has_context)
    end)

    it("should sort projects by time descending", function()
      local summary = {
        projects = { project1 = 1800, project2 = 7200, project3 = 3600 },
        contexts = {},
        total = 12600,
      }

      local lines = time_summary.format_summary(summary)

      local project2_line, project3_line, project1_line
      for i, line in ipairs(lines) do
        if line:match("%+project1") then
          project1_line = i
        elseif line:match("%+project2") then
          project2_line = i
        elseif line:match("%+project3") then
          project3_line = i
        end
      end

      assert.is_true(project2_line < project3_line)
      assert.is_true(project3_line < project1_line)
    end)
  end)
end)
