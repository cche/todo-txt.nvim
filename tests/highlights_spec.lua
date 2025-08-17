local highlights = require("todo-txt.highlights")

describe("highlights.get_highlights", function()
  it("highlights priority, tags, and due", function()
    local line = "  1. (A) 2025-01-01 Work on +Project @Home due:2099-01-01"
    local regs = highlights.get_highlights(1, line)

    local has_pri, has_ctx, has_proj, has_due = false, false, false, false
    for _, r in ipairs(regs) do
      if r.group == "TodoPriority" then has_pri = true end
      if r.group == "TodoContext" then has_ctx = true end
      if r.group == "TodoProject" then has_proj = true end
      if r.group == "TodoDue" then has_due = true end
    end

    assert.is_true(has_pri)
    assert.is_true(has_ctx)
    assert.is_true(has_proj)
    assert.is_true(has_due)
  end)

  it("highlights overdue due-dates as TodoOverdue", function()
    local line = "  2. (B) Something due:1999-01-01"
    local regs = highlights.get_highlights(2, line)
    local has_overdue = false
    for _, r in ipairs(regs) do
      if r.group == "TodoOverdue" then has_overdue = true end
    end
    assert.is_true(has_overdue)
  end)

  it("marks completed tasks with TodoCompleted and stops further highlighting", function()
    local line = "  3. x 2025-01-02 Done task +Proj @Ctx"
    local regs = highlights.get_highlights(3, line)

    local has_completed = false
    local has_priority_or_due = false
    for _, r in ipairs(regs) do
      if r.group == "TodoCompleted" then has_completed = true end
      if r.group == "TodoPriority" or r.group == "TodoDue" or r.group == "TodoOverdue" then
        has_priority_or_due = true
      end
    end

    assert.is_true(has_completed)
    assert.is_false(has_priority_or_due)
  end)
end)
