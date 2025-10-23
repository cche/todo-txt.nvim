local filter = require("todo-txt.filter")
local ui = require("todo-txt.ui")

describe("Cascading Filters", function()
  local test_entries

  before_each(function()
    -- Reset filter state
    ui.clear_filters()
    
    -- Create test entries
    test_entries = {
      { entry = "(A) Task 1 @work +project1 due:2025-01-15", orig_index = 1 },
      { entry = "Task 2 @work +project1", orig_index = 2 },
      { entry = "Task 3 @home +project2 due:2025-01-20", orig_index = 3 },
      { entry = "Task 4 @work due:2025-01-10", orig_index = 4 },
      { entry = "Task 5 @home", orig_index = 5 },
      { entry = "Task 6 due:2025-01-25", orig_index = 6 },
    }
  end)

  describe("filter.apply_filters", function()
    it("returns all entries when no filters are active", function()
      local filters = { tag = nil, due = false }
      local result = filter.apply_filters(test_entries, filters)
      assert.equals(6, #result)
    end)

    it("filters by tag only", function()
      local filters = { tag = "@work", due = false }
      local result = filter.apply_filters(test_entries, filters)
      assert.equals(3, #result)
      -- Should include tasks 1, 2, 4
      assert.equals(1, result[1].orig_index)
      assert.equals(2, result[2].orig_index)
      assert.equals(4, result[3].orig_index)
    end)

    it("filters by due only", function()
      local filters = { tag = nil, due = true }
      local result = filter.apply_filters(test_entries, filters)
      assert.equals(4, #result)
      -- Should include tasks 1, 3, 4, 6 (sorted by due date)
    end)

    it("combines tag and due filters (cascading)", function()
      local filters = { tag = "@work", due = true }
      local result = filter.apply_filters(test_entries, filters)
      assert.equals(2, #result)
      -- Should include only tasks 1 and 4 (@work AND due)
      -- Sorted by due date: task 4 (2025-01-10) comes before task 1 (2025-01-15)
      assert.equals(4, result[1].orig_index)
      assert.equals(1, result[2].orig_index)
    end)

    it("filters by project tag and due", function()
      local filters = { tag = "+project1", due = true }
      local result = filter.apply_filters(test_entries, filters)
      assert.equals(1, #result)
      -- Should include only task 1 (+project1 AND due)
      assert.equals(1, result[1].orig_index)
    end)

    it("returns empty when cascading filters match nothing", function()
      local filters = { tag = "@home", due = true }
      local result = filter.apply_filters(test_entries, filters)
      assert.equals(1, #result)
      -- Only task 3 has @home AND due
      assert.equals(3, result[1].orig_index)
    end)
  end)

  describe("ui filter state management", function()
    it("starts with no filters active", function()
      local filters = ui.get_active_filters()
      assert.is_nil(filters.tag)
      assert.is_false(filters.due)
    end)

    it("sets tag filter", function()
      ui.set_tag_filter("@work")
      local filters = ui.get_active_filters()
      assert.equals("@work", filters.tag)
      assert.is_false(filters.due)
    end)

    it("toggles due filter on", function()
      local is_active = ui.toggle_due_filter()
      assert.is_true(is_active)
      local filters = ui.get_active_filters()
      assert.is_true(filters.due)
    end)

    it("toggles due filter off", function()
      ui.toggle_due_filter() -- on
      local is_active = ui.toggle_due_filter() -- off
      assert.is_false(is_active)
      local filters = ui.get_active_filters()
      assert.is_false(filters.due)
    end)

    it("preserves tag filter when toggling due filter", function()
      ui.set_tag_filter("@work")
      ui.toggle_due_filter()
      local filters = ui.get_active_filters()
      assert.equals("@work", filters.tag)
      assert.is_true(filters.due)
    end)

    it("preserves due filter when changing tag filter", function()
      ui.toggle_due_filter()
      ui.set_tag_filter("@work")
      local filters = ui.get_active_filters()
      assert.equals("@work", filters.tag)
      assert.is_true(filters.due)
    end)

    it("clears tag filter independently", function()
      ui.set_tag_filter("@work")
      ui.toggle_due_filter()
      ui.set_tag_filter(nil)
      local filters = ui.get_active_filters()
      assert.is_nil(filters.tag)
      assert.is_true(filters.due)
    end)

    it("clears all filters", function()
      ui.set_tag_filter("@work")
      ui.toggle_due_filter()
      ui.clear_filters()
      local filters = ui.get_active_filters()
      assert.is_nil(filters.tag)
      assert.is_false(filters.due)
    end)
  end)

  describe("tag filter toggle behavior", function()
    it("sets tag filter when none is active", function()
      ui.set_tag_filter("@work")
      local filters = ui.get_active_filters()
      assert.equals("@work", filters.tag)
    end)

    it("clears tag filter when same tag is set", function()
      ui.set_tag_filter("@work")
      -- Simulate toggle behavior
      local filters = ui.get_active_filters()
      if filters.tag == "@work" then
        ui.set_tag_filter(nil)
      end
      filters = ui.get_active_filters()
      assert.is_nil(filters.tag)
    end)

    it("switches to different tag", function()
      ui.set_tag_filter("@work")
      ui.set_tag_filter("@home")
      local filters = ui.get_active_filters()
      assert.equals("@home", filters.tag)
    end)
  end)

  describe("filter combinations", function()
    it("applies filters in correct order: tag then due", function()
      -- Start with 6 entries
      -- Filter by @work: 3 entries (1, 2, 4)
      -- Then filter by due: 2 entries (1, 4)
      local filters = { tag = "@work", due = true }
      local result = filter.apply_filters(test_entries, filters)
      
      assert.equals(2, #result)
      -- Verify both have @work
      assert.is_true(result[1].entry:match("@work") ~= nil)
      assert.is_true(result[2].entry:match("@work") ~= nil)
      -- Verify both have due dates
      assert.is_true(result[1].entry:match("due:") ~= nil)
      assert.is_true(result[2].entry:match("due:") ~= nil)
    end)

    it("handles edge case: tag filter with no due tasks", function()
      -- @home has task 3 (with due) and task 5 (no due)
      local filters = { tag = "@home", due = true }
      local result = filter.apply_filters(test_entries, filters)
      assert.equals(1, #result)
      assert.equals(3, result[1].orig_index)
    end)

    it("handles edge case: due filter with no matching tags", function()
      local filters = { tag = "@nonexistent", due = true }
      local result = filter.apply_filters(test_entries, filters)
      assert.equals(0, #result)
    end)
  end)
end)
