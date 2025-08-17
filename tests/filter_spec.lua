local filter = require("todo-txt.filter")

describe("filter.get_due_entries", function()
  it("returns only entries that have due and sorts ascending by date", function()
    local entries = {
      "Task no due",
      "(A) Task with due:2025-01-03",
      "Task with due:2025-01-01",
      "Task with due:2025-01-02 and extras",
    }

    local due_entries = filter.get_due_entries(entries)

    -- Should only include 3 entries, skipping the first
    assert.equals(3, #due_entries)

    -- Sorted ascending by due date with correct indices
    assert.equals("2025-01-01", due_entries[1].due)
    assert.equals(3, due_entries[1].index)
    assert.equals("2025-01-02", due_entries[2].due)
    assert.equals(4, due_entries[2].index)
    assert.equals("2025-01-03", due_entries[3].due)
    assert.equals(2, due_entries[3].index)
  end)
end)
