local sortmod = require("todo-txt.sort")

describe("sort module", function()
  it("sorts by priority A..Z, then by due date", function()
    local entries = {
      "(B) 2025-01-01 Task B due:2026-01-02",
      "(A) 2025-01-01 Task A due:2026-01-03",
      "(A) 2025-01-01 Task A earlier due:2026-01-01",
      "2025-01-01 No priority",
    }

    sortmod.sort_entries(entries)

    assert.is_true(entries[1]:match("^%(%u%)") == "(A)")
    assert.is_true(entries[2]:match("^%(%u%)") == "(A)")
    -- The earlier due date should come first among (A)
    assert.is_true(entries[1]:match("earlier") == "earlier")
    assert.is_true(entries[3]:match("^%(%u%)") == "(B)")
    assert.is_true(entries[4]:match("^%(%u%)") == nil)
  end)

  it("keeps relative order when neither due nor priority differ", function()
    local entries = {
      "2025-01-01 Task 1",
      "2025-01-01 Task 2",
    }

    sortmod.sort_entries(entries)
    assert.equals("2025-01-01 Task 1", entries[1])
    assert.equals("2025-01-01 Task 2", entries[2])
  end)
end)
