local formatter = require("todo-txt.formatter")

describe("formatter", function()
  it("formats basic task with only description", function()
    local task = {
      line = "Buy groceries",
      is_done = false
    }
    assert.equals("Buy groceries", formatter.format(task))
  end)

  it("formats task with priority", function()
    local task = {
      line = "Important meeting",
      priority = "A",
      is_done = false
    }
    assert.equals("(A) Important meeting", formatter.format(task))
  end)

  it("formats task with creation date", function()
    local task = {
      line = "Call dentist",
      created = "2025-08-19",
      is_done = false
    }
    assert.equals("2025-08-19 Call dentist", formatter.format(task))
  end)

  it("formats task with priority and creation date", function()
    local task = {
      line = "Review code",
      priority = "B",
      created = "2025-08-19",
      is_done = false
    }
    assert.equals("(B) 2025-08-19 Review code", formatter.format(task))
  end)

  it("formats completed task without priority", function()
    local task = {
      line = "Finished task",
      created = "2025-08-18",
      completed = "2025-08-19",
      is_done = true
    }
    assert.equals("x 2025-08-18 2025-08-19 Finished task", formatter.format(task))
  end)

  it("formats completed task with priority", function()
    local task = {
      line = "Important done task",
      priority = "A",
      created = "2025-08-18",
      completed = "2025-08-19",
      is_done = true
    }
    assert.equals("x (A) 2025-08-18 2025-08-19 Important done task", formatter.format(task))
  end)

  it("formats completed task without completion date", function()
    local task = {
      line = "Done but no completion date",
      priority = "C",
      created = "2025-08-18",
      is_done = true
    }
    assert.equals("x (C) 2025-08-18 Done but no completion date", formatter.format(task))
  end)

  it("formats task with only completion mark", function()
    local task = {
      line = "Simple done task",
      is_done = true
    }
    assert.equals("x Simple done task", formatter.format(task))
  end)

  it("ignores completion date for non-completed tasks", function()
    local task = {
      line = "Not done task",
      priority = "B",
      created = "2025-08-18",
      completed = "2025-08-19", -- This should be ignored
      is_done = false
    }
    assert.equals("(B) 2025-08-18 Not done task", formatter.format(task))
  end)

  it("handles empty task description", function()
    local task = {
      line = "",
      priority = "A",
      created = "2025-08-19",
      is_done = false
    }
    assert.equals("(A) 2025-08-19 ", formatter.format(task))
  end)

  it("handles nil values gracefully", function()
    local task = {
      line = "Task with nils",
      priority = nil,
      created = nil,
      completed = nil,
      is_done = false
    }
    assert.equals("Task with nils", formatter.format(task))
  end)
end)