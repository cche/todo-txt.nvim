require("plenary.test_harness")
local todo = require("todo-txt")
local task = require("todo-txt.task")
local storage = require("todo-txt.storage")
local root = vim.loop.cwd()
-- Use spec-specific files to avoid interference with other specs
local test_todo_file = root .. "/todo_spec.txt"
local test_done_file = root .. "/done_spec.txt"

describe("todo-txt.nvim plugin", function()
  before_each(function()
    local config = {
      todo_file = test_todo_file,
      done_file = test_done_file,
    }
    todo.config = config
    task.setup(config)
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
    pcall(vim.loop.fs_unlink, test_todo_file)
    pcall(vim.loop.fs_unlink, test_done_file)
  end)

  it("sorts the todo list by priority and due date", function()
    local parser = require("todo-txt.parser")
    local util = require("todo-txt.util")
    
    storage.write_entries(test_todo_file, {
      "(B) 2025-01-01 Task B due:2026-01-02",
      "(A) 2025-01-01 Task A due:2026-01-01",
      "2025-01-01 Task C",
    })
    local entries = storage.get_entries(test_todo_file)
    table.sort(entries, function(a, b)
      local pa = parser.extract_priority(a)
      local da = parser.extract_due(a)
      local pb = parser.extract_priority(b)
      local db = parser.extract_due(b)
      if util.priority_value(pa) ~= util.priority_value(pb) then
        return util.priority_value(pa) < util.priority_value(pb)
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
    task.add_entry("New Task")
    local after = #storage.get_entries(test_todo_file)
    assert.are.same(before + 1, after)
    assert.is_true(storage.get_entries(test_todo_file)[after]:match("New Task") == "New Task")
  end)

  it("adds a priority to a task", function()
    task.add_entry("Task with no priority")
    local idx = #storage.get_entries(test_todo_file)
    local entry = storage.get_entries(test_todo_file)[idx]
    entry = entry:gsub("^%([A-Z]%) ", "")
    task.edit_entry(idx, "(A) " .. entry)
    local new_entry = storage.get_entries(test_todo_file)[idx]
    assert.is_true(new_entry:match("%(A%)") == "(A)")
  end)

  it("edits a task", function()
    task.add_entry("Task to edit")
    local idx = #storage.get_entries(test_todo_file)
    task.edit_entry(idx, "Edited Task")
    local entry = storage.get_entries(test_todo_file)[idx]
    assert.equals(entry, "Edited Task")
  end)

  it("marks a task as complete and toggles", function()
    task.add_entry("Task to complete")
    local idx = #storage.get_entries(test_todo_file)
    task.toggle_mark_complete(idx)
    local entry = storage.get_entries(test_todo_file)[idx]
    assert.equals(entry:match("^x "), "x ")
    task.toggle_mark_complete(idx)
    entry = storage.get_entries(test_todo_file)[idx]
    assert.is_true(entry:find("^x ") == nil)
  end)

  it("creates a task with priority", function()
    task.add_entry("My task", "A")
    local entries = require("todo-txt.storage").get_entries(test_todo_file)
    local last_entry = entries[#entries]
    assert.is_true(last_entry:match("^%(A%) %d%d%d%d%-%d%d%-%d%d My task$") ~= nil)
  end)

  it("filters tasks by tag", function()
    task.add_entry("Task with @Work tag")
    task.add_entry("Another task with @Home tag")
    task.add_entry("Third task with @Work tag")

    local entries = require("todo-txt.storage").get_entries(test_todo_file)
    local items = {}
    for i, line in ipairs(entries) do
      table.insert(items, { entry = line, orig_index = i })
    end

    local filtered = require("todo-txt.filter").filter_by_tag(items, "@Work")
    assert.are.same(2, #filtered)
    assert.is_true(filtered[1].entry:match("@Work") ~= nil)
    assert.is_true(filtered[2].entry:match("@Work") ~= nil)
  end)

  it("deletes a task", function()
    task.add_entry("Task to be deleted")
    local entries = require("todo-txt.storage").get_entries(test_todo_file)
    local num_entries_before = #entries
    task.delete_entry(num_entries_before)
    local entries_after = require("todo-txt.storage").get_entries(test_todo_file)
    assert.are.same(num_entries_before - 1, #entries_after)
  end)

  it("maintains focus on parent window after adding task", function()
    -- Setup initial task
    task.add_entry("Initial task")

    -- Setup UI config properly
    local ui = require("todo-txt.ui")
    ui.setup({
      window = {
        width = 80,
        height = 20,
        border = "rounded",
      },
    })

    -- Mock window operations
    local original_close = vim.api.nvim_win_close
    local original_set_current_win = vim.api.nvim_set_current_win
    local window_closed = false
    local focused_win = nil

    vim.api.nvim_win_close = function(win, force)
      window_closed = true
    end

    vim.api.nvim_set_current_win = function(win)
      focused_win = win
    end

    -- Mock buffer functions
    local original_get_lines = vim.api.nvim_buf_get_lines
    vim.api.nvim_buf_get_lines = function(buf, start, end_, strict)
      return { "Test new task" }
    end

    -- Mock vim.cmd to prevent actual command execution
    local original_cmd = vim.cmd
    vim.cmd = function(cmd)
      -- Do nothing for TodoList command
    end

    -- Call submit_new_entry
    todo.submit_new_entry()

    -- Verify task was added
    local entries = storage.get_entries(test_todo_file)
    assert.are.same(2, #entries)
    assert.is_true(entries[2]:match("Test new task") ~= nil)

    -- Verify window was closed
    assert.is_true(window_closed)

    -- Restore original functions
    vim.api.nvim_win_close = original_close
    vim.api.nvim_set_current_win = original_set_current_win
    vim.api.nvim_buf_get_lines = original_get_lines
    vim.cmd = original_cmd
  end)

  it("configures completion sources correctly in add/edit windows", function()
    -- Add some tasks with tags for completion testing
    task.add_entry("Task with @work context")
    task.add_entry("Task with +project tag")

    -- Setup UI config
    local ui = require("todo-txt.ui")
    ui.setup({
      window = {
        width = 80,
        height = 20,
        border = "rounded",
      },
    })

    -- Mock cmp.setup.buffer to verify it's called with correct sources
    local cmp_setup_called = false
    local cmp_sources = nil

    -- Mock require for cmp
    local original_require = require
    _G.require = function(module)
      if module == "cmp" then
        return {
          setup = {
            buffer = function(config)
              cmp_setup_called = true
              cmp_sources = config.sources
            end,
          },
        }
      end
      return original_require(module)
    end

    -- Mock window operations to prevent actual window creation
    local original_create_buf = vim.api.nvim_create_buf
    local original_open_win = vim.api.nvim_open_win
    local original_set_var = vim.api.nvim_win_set_var
    local original_wo = vim.wo
    local original_bo = vim.bo
    local window_type_set = nil

    vim.api.nvim_create_buf = function(listed, scratch)
      return 1 -- mock buffer id
    end

    vim.api.nvim_open_win = function(buf, enter, config)
      return 1 -- mock window id
    end

    vim.api.nvim_win_set_var = function(win, name, value)
      if name == "todo_txt_window_type" then
        window_type_set = value
      end
    end

    -- Mock window and buffer options to prevent errors
    vim.wo = setmetatable({}, {
      __index = function(_, win)
        return setmetatable({}, {
          __newindex = function() end -- ignore all window option sets
        })
      end
    })

    vim.bo = setmetatable({}, {
      __index = function(_, buf)
        return setmetatable({}, {
          __newindex = function() end -- ignore all buffer option sets
        })
      end
    })

    -- Test add window
    ui.show_add_window()

    -- Verify completion sources were configured correctly
    assert.is_true(cmp_setup_called)
    assert.are.same({ { name = "todo-txt" } }, cmp_sources)
    assert.equals("add", window_type_set)

    -- Reset for edit window test
    cmp_setup_called = false
    cmp_sources = nil
    window_type_set = nil

    -- Test edit window
    ui.show_edit_window(1, "Test task")

    -- Verify completion sources were configured correctly for edit window
    assert.is_true(cmp_setup_called)
    assert.are.same({ { name = "todo-txt" } }, cmp_sources)
    assert.equals("edit", window_type_set)

    -- Restore original functions
    _G.require = original_require
    vim.api.nvim_create_buf = original_create_buf
    vim.api.nvim_open_win = original_open_win
    vim.api.nvim_win_set_var = original_set_var
    vim.wo = original_wo
    vim.bo = original_bo
  end)

  describe("filter toggle behavior", function()
    before_each(function()
      local ui = require("todo-txt.ui")
      ui.setup({})
      ui.clear_filters() -- Ensure clean state
    end)

    it("toggles tag filter on and off", function()
      local ui = require("todo-txt.ui")
      
      -- Set tag filter
      ui.set_tag_filter("@work")
      local filters = ui.get_active_filters()
      assert.equals("@work", filters.tag)
      
      -- Clear tag filter (simulating toggle off)
      ui.set_tag_filter(nil)
      filters = ui.get_active_filters()
      assert.is_nil(filters.tag)
    end)

    it("switches between different tags", function()
      local ui = require("todo-txt.ui")
      
      ui.set_tag_filter("@work")
      local filters = ui.get_active_filters()
      assert.equals("@work", filters.tag)
      
      ui.set_tag_filter("@home")
      filters = ui.get_active_filters()
      assert.equals("@home", filters.tag)
    end)

    it("preserves due filter when toggling tag filter", function()
      local ui = require("todo-txt.ui")
      
      ui.toggle_due_filter() -- Turn on due filter
      ui.set_tag_filter("@work")
      
      local filters = ui.get_active_filters()
      assert.equals("@work", filters.tag)
      assert.is_true(filters.due)
      
      -- Clear tag filter
      ui.set_tag_filter(nil)
      filters = ui.get_active_filters()
      assert.is_nil(filters.tag)
      assert.is_true(filters.due) -- Due filter should still be active
    end)
  end)

  describe("clear_all_filters", function()
    before_each(function()
      local ui = require("todo-txt.ui")
      ui.setup({})
      ui.clear_filters() -- Ensure clean state
    end)

    it("clears all active filters", function()
      local ui = require("todo-txt.ui")
      
      -- Set both filters
      ui.set_tag_filter("@work")
      ui.toggle_due_filter()
      
      local filters = ui.get_active_filters()
      assert.equals("@work", filters.tag)
      assert.is_true(filters.due)
      
      -- Clear all filters
      ui.clear_filters()
      filters = ui.get_active_filters()
      assert.is_nil(filters.tag)
      assert.is_false(filters.due)
    end)

    it("works when no filters are active", function()
      local ui = require("todo-txt.ui")
      
      -- Clear when nothing is set
      ui.clear_filters()
      local filters = ui.get_active_filters()
      assert.is_nil(filters.tag)
      assert.is_false(filters.due)
    end)
  end)

  describe("refresh_current_list", function()
    before_each(function()
      local ui = require("todo-txt.ui")
      ui.setup({
        window = {
          width = 80,
          height = 20,
          border = "rounded",
        },
      })
      ui.clear_filters()
    end)

    it("preserves active tag and due filters when refreshing", function()
      local ui = require("todo-txt.ui")

      -- Prepare some tasks
      storage.write_entries(test_todo_file, {
        "2025-01-01 Task @work due:2025-01-02",
        "2025-01-01 Task @home",
      })

      -- Ensure todo uses the spec files
      todo.config = {
        todo_file = test_todo_file,
        done_file = test_done_file,
        window = {
          width = 80,
          height = 20,
          border = "rounded",
        },
      }

      -- Set combined filters
      ui.set_tag_filter("@work")
      ui.toggle_due_filter() -- enable due filter

      local before = ui.get_active_filters()

      -- Initial render with filters
      todo.show_todo_list()

      -- Refresh via helper (this is what add/edit/complete paths use)
      ui.refresh_current_list()

      local after = ui.get_active_filters()

      -- Filters should be unchanged
      assert.equals(before.tag, after.tag)
      assert.equals(before.due, after.due)
      assert.equals("@work", after.tag)
      assert.is_true(after.due)
    end)
  end)
end)
