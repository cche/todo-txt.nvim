local due_helpers = require("todo-txt.due_helpers")

describe("Due date helpers", function()
  describe("expand_shortcuts", function()
    it("expands :today to due:YYYY-MM-DD format", function()
      local text = "Task :today"
      local result = due_helpers.expand_shortcuts(text)
      assert.is_true(result:match("Task due:%d%d%d%d%-%d%d%-%d%d") ~= nil)
    end)

    it("expands :tomorrow to due:YYYY-MM-DD format", function()
      local text = "Task :tomorrow"
      local result = due_helpers.expand_shortcuts(text)
      assert.is_true(result:match("Task due:%d%d%d%d%-%d%d%-%d%d") ~= nil)
    end)

    it("expands :nextweek to due:YYYY-MM-DD format", function()
      local text = "Task :nextweek"
      local result = due_helpers.expand_shortcuts(text)
      assert.is_true(result:match("Task due:%d%d%d%d%-%d%d%-%d%d") ~= nil)
    end)

    it("expands weekday shortcuts like :monday", function()
      local text = "Task :monday"
      local result = due_helpers.expand_shortcuts(text)
      assert.is_true(result:match("Task due:%d%d%d%d%-%d%d%-%d%d") ~= nil)
    end)

    it("expands relative day shortcuts like :1d, :2d", function()
      local text = "Task :1d another :2d"
      local result = due_helpers.expand_shortcuts(text)
      -- Should have two due dates
      local count = 0
      for _ in result:gmatch("due:") do
        count = count + 1
      end
      assert.equals(2, count)
    end)

    it("expands week shortcuts like :1w, :2w", function()
      local text = "Task :1w"
      local result = due_helpers.expand_shortcuts(text)
      assert.is_true(result:match("Task due:%d%d%d%d%-%d%d%-%d%d") ~= nil)
    end)

    it("expands month shortcuts like :1m", function()
      local text = "Task :1m"
      local result = due_helpers.expand_shortcuts(text)
      assert.is_true(result:match("Task due:%d%d%d%d%-%d%d%-%d%d") ~= nil)
    end)

    it("handles multiple shortcuts in one text", function()
      local text = "Task1 :today Task2 :tomorrow"
      local result = due_helpers.expand_shortcuts(text)
      local count = 0
      for _ in result:gmatch("due:") do
        count = count + 1
      end
      assert.equals(2, count)
    end)

    it("does not expand shortcuts that are part of other words", function()
      local text = "Task about history:today"
      local result = due_helpers.expand_shortcuts(text)
      -- Should not expand because : is preceded by a letter
      assert.equals(text, result)
    end)

    it("does not expand priority syntax like A:", function()
      local text = "A: Important task"
      local result = due_helpers.expand_shortcuts(text)
      -- Should not expand A: as it's priority syntax
      assert.equals(text, result)
    end)

    it("expands shortcuts in tasks with priority", function()
      local text = "A: Important task :today"
      local result = due_helpers.expand_shortcuts(text)
      -- Should expand :today but not touch A:
      assert.is_true(result:match("^A: Important task due:%d%d%d%d%-%d%d%-%d%d$") ~= nil)
    end)

    it("handles text without shortcuts", function()
      local text = "Regular task without shortcuts"
      local result = due_helpers.expand_shortcuts(text)
      assert.equals(text, result)
    end)

    it("handles empty text", function()
      local result = due_helpers.expand_shortcuts("")
      assert.equals("", result)
    end)

    it("handles nil text", function()
      local result = due_helpers.expand_shortcuts(nil)
      assert.is_nil(result)
    end)

    it("preserves existing due: prefix", function()
      local text = "Task due::today"
      local result = due_helpers.expand_shortcuts(text)
      -- Should result in due:YYYY-MM-DD, not due:due:YYYY-MM-DD
      local count = 0
      for _ in result:gmatch("due:") do
        count = count + 1
      end
      assert.equals(1, count)
    end)
  end)

  describe("get_shortcuts_list", function()
    it("returns a list of available shortcuts", function()
      local shortcuts = due_helpers.get_shortcuts_list()
      assert.is_true(#shortcuts > 0)
      assert.is_true(vim.tbl_contains(shortcuts, ":today"))
      assert.is_true(vim.tbl_contains(shortcuts, ":tomorrow"))
      assert.is_true(vim.tbl_contains(shortcuts, ":nextweek"))
    end)

    it("returns sorted list", function()
      local shortcuts = due_helpers.get_shortcuts_list()
      local sorted = vim.deepcopy(shortcuts)
      table.sort(sorted)
      assert.are.same(sorted, shortcuts)
    end)
  end)

  describe("get_completion_items", function()
    it("returns completion items with all required fields", function()
      local items = due_helpers.get_completion_items()
      assert.is_true(#items > 0)
      
      for _, item in ipairs(items) do
        assert.is_not_nil(item.shortcut)
        assert.is_not_nil(item.date)
        assert.is_not_nil(item.description)
        assert.is_not_nil(item.display)
        -- Date should be in YYYY-MM-DD format
        assert.is_true(item.date:match("%d%d%d%d%-%d%d%-%d%d") ~= nil)
      end
    end)

    it("includes common shortcuts", function()
      local items = due_helpers.get_completion_items()
      local shortcuts = {}
      for _, item in ipairs(items) do
        shortcuts[item.shortcut] = true
      end
      
      assert.is_true(shortcuts[":today"])
      assert.is_true(shortcuts[":tomorrow"])
      assert.is_true(shortcuts[":nextweek"])
      assert.is_true(shortcuts[":monday"])
      assert.is_true(shortcuts[":1d"])
      assert.is_true(shortcuts[":1w"])
    end)
  end)

  describe("date calculations", function()
    it("calculates :tomorrow as one day ahead", function()
      local today_text = "Task :today"
      local tomorrow_text = "Task :tomorrow"
      
      local today_result = due_helpers.expand_shortcuts(today_text)
      local tomorrow_result = due_helpers.expand_shortcuts(tomorrow_text)
      
      local today_date = today_result:match("due:(%d%d%d%d%-%d%d%-%d%d)")
      local tomorrow_date = tomorrow_result:match("due:(%d%d%d%d%-%d%d%-%d%d)")
      
      -- Parse dates
      local ty, tm, td = today_date:match("(%d+)%-(%d+)%-(%d+)")
      local tomy, tomm, tomd = tomorrow_date:match("(%d+)%-(%d+)%-(%d+)")
      
      local today_time = os.time({year=ty, month=tm, day=td})
      local tomorrow_time = os.time({year=tomy, month=tomm, day=tomd})
      
      -- Tomorrow should be 1 day (86400 seconds) ahead
      assert.equals(86400, tomorrow_time - today_time)
    end)

    it("calculates :nextweek as 7 days ahead", function()
      local today_text = "Task :today"
      local nextweek_text = "Task :nextweek"
      
      local today_result = due_helpers.expand_shortcuts(today_text)
      local nextweek_result = due_helpers.expand_shortcuts(nextweek_text)
      
      local today_date = today_result:match("due:(%d%d%d%d%-%d%d%-%d%d)")
      local nextweek_date = nextweek_result:match("due:(%d%d%d%d%-%d%d%-%d%d)")
      
      -- Parse dates
      local ty, tm, td = today_date:match("(%d+)%-(%d+)%-(%d+)")
      local nwy, nwm, nwd = nextweek_date:match("(%d+)%-(%d+)%-(%d+)")
      
      local today_time = os.time({year=ty, month=tm, day=td})
      local nextweek_time = os.time({year=nwy, month=nwm, day=nwd})
      
      -- Next week should be 7 days (604800 seconds) ahead
      assert.equals(604800, nextweek_time - today_time)
    end)
  end)
end)
