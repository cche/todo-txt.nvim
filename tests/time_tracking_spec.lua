local task = require("todo-txt.task")
local storage = require("todo-txt.storage")
local parser = require("todo-txt.parser")
local util = require("todo-txt.util")

describe("time_tracking", function()
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

  describe("basic start/stop tracking", function()
    it("should start tracking a task", function()
      task.add_entry("test task", "A")
      local before_time = os.time()

      assert.truthy(task.toggle_mark_tracking(1))

      local entries = storage.get_entries(config.todo_file)
      local t = parser.parse(entries[1])

      assert.is_truthy(t.start_time)
      local start_time = tonumber(t.start_time)
      assert.is_true(start_time >= before_time and start_time <= os.time())
      assert.is_nil(t.tracked_time)
      assert.equals("test task", t.line)
    end)

    it("should stop tracking and calculate time", function()
      task.add_entry("test task", "A")

      -- Start tracking
      assert.truthy(task.toggle_mark_tracking(1))

      -- Wait a moment to ensure time passes
      os.execute("sleep 1")

      -- Stop tracking
      assert.truthy(task.toggle_mark_tracking(1))

      local entries = storage.get_entries(config.todo_file)
      local t = parser.parse(entries[1])

      assert.is_nil(t.start_time)
      assert.is_truthy(t.tracked_time)
      assert.is_truthy(t.tracked_time:match("tracked:"))
      assert.equals("test task", t.line)
    end)

    it("should allow restarting tracking after stopping", function()
      task.add_entry("test task", "A")

      -- Start tracking
      assert.truthy(task.toggle_mark_tracking(1))
      os.execute("sleep 1")

      -- Stop tracking
      assert.truthy(task.toggle_mark_tracking(1))

      local entries = storage.get_entries(config.todo_file)
      local t = parser.parse(entries[1])
      local first_tracked = t.tracked_time

      -- Restart tracking
      assert.truthy(task.toggle_mark_tracking(1))

      entries = storage.get_entries(config.todo_file)
      t = parser.parse(entries[1])

      assert.is_truthy(t.start_time)
      assert.is_truthy(t.tracked_time)
      assert.equals(first_tracked, t.tracked_time)
      assert.equals("test task", t.line)
    end)

    it("should preserve task properties when tracking", function()
      task.add_entry("test task with +project @context", "B")

      assert.truthy(task.toggle_mark_tracking(1))

      local entries = storage.get_entries(config.todo_file)
      local t = parser.parse(entries[1])

      assert.equals("B", t.priority)
      assert.is_truthy(t.created)
      assert.is_truthy(t.projects["project"])
      assert.is_truthy(t.contexts["context"])
      assert.equals("test task with +project @context", t.line)
    end)
  end)

  describe("integration with task completion", function()
    it("should stop tracking when marking task complete", function()
      task.add_entry("test task", "A")

      -- Start tracking
      assert.truthy(task.toggle_mark_tracking(1))
      os.execute("sleep 1")

      -- Mark complete (should stop tracking)
      assert.truthy(task.toggle_mark_complete(1))

      local entries = storage.get_entries(config.todo_file)
      local t = parser.parse(entries[1])

      assert.is_true(t.is_done)
      assert.is_nil(t.start_time)
      assert.is_truthy(t.tracked_time)
      assert.is_truthy(t.completed)
      assert.equals("test task", t.line)
    end)

    it("should complete task normally when not tracking", function()
      task.add_entry("test task", "A")

      assert.truthy(task.toggle_mark_complete(1))

      local entries = storage.get_entries(config.todo_file)
      local t = parser.parse(entries[1])

      assert.is_true(t.is_done)
      assert.is_nil(t.start_time)
      assert.is_nil(t.tracked_time)
      assert.is_truthy(t.completed)
      assert.equals("test task", t.line)
    end)

    it("should preserve tracked time when uncompleting task", function()
      task.add_entry("test task", "A")

      -- Start tracking, stop, then complete
      assert.truthy(task.toggle_mark_tracking(1))
      os.execute("sleep 1")
      assert.truthy(task.toggle_mark_tracking(1))

      local entries = storage.get_entries(config.todo_file)
      local t = parser.parse(entries[1])
      local tracked_time = t.tracked_time

      -- Complete then uncomplete
      assert.truthy(task.toggle_mark_complete(1))
      assert.truthy(task.toggle_mark_complete(1))

      entries = storage.get_entries(config.todo_file)
      t = parser.parse(entries[1])

      assert.is_false(t.is_done)
      assert.equals(tracked_time, t.tracked_time)
      assert.equals("test task", t.line)
    end)

    it("should preserve priority when completing tracked task", function()
      task.add_entry("test task", "A")

      assert.truthy(task.toggle_mark_tracking(1))
      os.execute("sleep 1")
      assert.truthy(task.toggle_mark_complete(1))

      local entries = storage.get_entries(config.todo_file)
      local t = parser.parse(entries[1])

      assert.is_true(t.is_done)
      assert.equals("A", t.priority)
      assert.is_truthy(t.tracked_time)
      assert.equals("test task", t.line)
    end)
  end)

  describe("time calculation and formatting", function()
    it("should properly format time less than 1 minute with seconds", function()
      local end_time = 1000
      local start_time = 970 -- 30 seconds
      local result = util.calculate_total_time(end_time, start_time, 0, 0, 0)

      assert.equals("tracked:0h0m30s", result)
    end)

    it("should properly format time less than 1 hour with minutes and seconds", function()
      local end_time = 2000
      local start_time = 1500 -- 500 seconds = 8 minutes 20 seconds
      local result = util.calculate_total_time(end_time, start_time, 0, 0, 0)

      assert.equals("tracked:0h8m20s", result)
    end)

    it("should properly format time over 1 hour", function()
      local end_time = 10000
      local start_time = 6400 -- 3600 seconds = 1 hour
      local result = util.calculate_total_time(end_time, start_time, 0, 0, 0)

      assert.equals("tracked:1h0m0s", result)
    end)

    it("should format hours, minutes and seconds when over 1 hour", function()
      local end_time = 10000
      local start_time = 4550 -- 5450 seconds = 1h 30m 50s
      local result = util.calculate_total_time(end_time, start_time, 0, 0, 0)

      assert.equals("tracked:1h30m50s", result)
    end)

    it("should handle very large hour values", function()
      -- Simulate 100 hours
      local end_time = 360000
      local start_time = 0
      local result = util.calculate_total_time(end_time, start_time, 0, 0, 0)

      assert.equals("tracked:100h0m0s", result)
    end)

    it("should handle zero time", function()
      local end_time = 1000
      local start_time = 1000
      local result = util.calculate_total_time(end_time, start_time, 0, 0, 0)

      assert.equals("tracked:0h0m0s", result)
    end)

    it("should accumulate with previous hours", function()
      local end_time = 1500
      local start_time = 1000 -- 500 seconds = 8m 20s
      local result = util.calculate_total_time(end_time, start_time, 2, 0, 0)

      -- 2h + 8m 20s = 2h 8m (no seconds shown since >= 1h)
      assert.equals("tracked:2h8m20s", result)
    end)

    it("should accumulate with previous minutes", function()
      local end_time = 1500
      local start_time = 1000 -- 500 seconds = 8m 20s
      local result = util.calculate_total_time(end_time, start_time, 0, 45, 0)

      -- 45m + 8m 20s = 53m 20s
      assert.equals("tracked:0h53m20s", result)
    end)

    it("should accumulate with previous seconds", function()
      local end_time = 1050
      local start_time = 1000 -- 50 seconds
      local result = util.calculate_total_time(end_time, start_time, 0, 0, 25)

      -- 25s + 50s = 75s = 1m 15s
      assert.equals("tracked:0h1m15s", result)
    end)

    it("should carry over seconds to minutes", function()
      local end_time = 1090
      local start_time = 1000 -- 90 seconds
      local result = util.calculate_total_time(end_time, start_time, 0, 0, 0)

      -- 90s = 1m 30s
      assert.equals("tracked:0h1m30s", result)
    end)

    it("should carry over minutes to hours", function()
      local end_time = 4800
      local start_time = 1200 -- 3600 seconds = 60 minutes
      local result = util.calculate_total_time(end_time, start_time, 0, 30, 0)

      -- 30m + 60m = 90m = 1h 30m
      assert.equals("tracked:1h30m0s", result)
    end)

    it("should handle complex accumulation with carries", function()
      local end_time = 1200
      local start_time = 1000 -- 200 seconds = 3m 20s
      local result = util.calculate_total_time(end_time, start_time, 1, 58, 45)

      -- 1h 58m 45s + 3m 20s = 1h 61m 65s = 2h 2m 5s
      assert.equals("tracked:2h2m5s", result)
    end)
  end)

  describe("parser extraction functions", function()
    it("should extract start_time", function()
      local line = "(A) 2025-01-23 test task start:1234567890"
      local start_time = parser.extract_start_time(line)

      assert.equals("1234567890", start_time)
    end)

    it("should return nil when no start_time present", function()
      local line = "(A) 2025-01-23 test task"
      local start_time = parser.extract_start_time(line)

      assert.is_nil(start_time)
    end)

    it("should extract tracked_time with hours", function()
      local line = "test task tracked:2h30m0s"
      local tracked = parser.extract_tracked_time(line)

      assert.equals("tracked:2h30m0s", tracked)
    end)

    it("should extract tracked_time without hours", function()
      local line = "test task tracked:0h15m30s"
      local tracked = parser.extract_tracked_time(line)

      assert.equals("tracked:0h15m30s", tracked)
    end)

    it("should return nil when no tracked_time present", function()
      local line = "test task"
      local tracked = parser.extract_tracked_time(line)

      assert.is_nil(tracked)
    end)

    it("should extract previous total with hours", function()
      local line = "tracked:2h30m0s"
      local hours, minutes, seconds = parser.extract_tracked_time(line):match("tracked:(%d+)h(%d+)m(%d+)s")

      assert.equals("2", hours)
      assert.equals("30", minutes)
      assert.equals("0", seconds)
    end)

    it("should extract previous total without hours", function()
      local line = "tracked:0h45m30s"
      local hours, minutes, seconds = parser.extract_tracked_time(line):match("tracked:(%d+)h(%d+)m(%d+)s")

      assert.equals("0", hours)
      assert.equals("45", minutes)
      assert.equals("30", seconds)
    end)

    it("should clean tracking metadata from description", function()
      local line = "test task start:1234567890 tracked:2h30m0s"
      local clean = parser.clean_tracking_metadata(line)

      assert.equals("test task", clean)
    end)

    it("should clean tracking metadata with multiple spaces", function()
      local line = "test task   start:1234567890   tracked:2h30m0s"
      local clean = parser.clean_tracking_metadata(line)

      assert.equals("test task", clean)
    end)

    it("should handle line with no tracking metadata", function()
      local line = "test task with +project @context"
      local clean = parser.clean_tracking_metadata(line)

      assert.equals("test task with +project @context", clean)
    end)
  end)

  describe("full parse/format round-trip with tracking", function()
    it("should parse task with active tracking", function()
      local line = "(A) 2025-01-23 test task start:1234567890"
      local t = parser.parse(line)

      assert.equals("A", t.priority)
      assert.equals("2025-01-23", t.created)
      assert.equals("test task", t.line)
      assert.equals("1234567890", t.start_time)
      assert.is_nil(t.tracked_time)
      assert.is_false(t.is_done)
    end)

    it("should parse task with completed tracking", function()
      local line = "(A) 2025-01-23 test task tracked:2h30m5s"
      local t = parser.parse(line)

      assert.equals("A", t.priority)
      assert.equals("2025-01-23", t.created)
      assert.equals("test task", t.line)
      assert.is_nil(t.start_time)
      assert.equals("tracked:2h30m5s", t.tracked_time)
      assert.is_false(t.is_done)
    end)

    it("should parse completed task with tracking", function()
      local line = "x (A) 2025-01-24 2025-01-23 test task tracked:1h15m35s"
      local t = parser.parse(line)

      assert.is_true(t.is_done)
      assert.equals("A", t.priority)
      assert.equals("2025-01-24", t.created)
      assert.equals("2025-01-24", t.completed)
      assert.equals("test task", t.line)
      assert.equals("tracked:1h15m35s", t.tracked_time)
      assert.is_nil(t.start_time)
    end)

    it("should parse task with projects, contexts, and tracking", function()
      local line = "(B) 2025-01-23 work on +myproject @office start:1234567890"
      local t = parser.parse(line)

      assert.equals("B", t.priority)
      assert.equals("work on +myproject @office", t.line)
      assert.is_truthy(t.projects["myproject"])
      assert.is_truthy(t.contexts["office"])
      assert.equals("1234567890", t.start_time)
    end)
  end)
end)
