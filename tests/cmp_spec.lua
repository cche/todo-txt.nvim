require('plenary.busted')
local cmp_source = require('todo-cmp')

-- Helper to call complete and capture items
local function complete_with(line)
  local items
  cmp_source.complete(nil, { context = { cursor_before_line = line } }, function(res)
    items = res
  end)
  -- In this synchronous implementation, callback runs immediately
  return items or {}
end

describe('todo-cmp source', function()
  local orig_is_available
  local orig_get_entries
  before_each(function()
    -- Force availability
    orig_is_available = cmp_source.is_available
    cmp_source.is_available = function() return true end
    -- Stub entries
    local todo = require('todo-txt')
    orig_get_entries = todo.get_entries
    todo.get_entries = function()
      return {
        '(A) 2025-01-01 Work on +Proj_Main @home-office',
        '2025-01-02 Another +Proj_Main @ctx2',
        '2025-01-03 Mixed +proj-aux_1 @work',
      }
    end
  end)

  after_each(function()
    cmp_source.is_available = orig_is_available
    local todo = require('todo-txt')
    todo.get_entries = orig_get_entries
  end)

  it('completes contexts after @ using parser tags', function()
    local items = complete_with('Do something @ho')
    local labels = {}
    for _, it in ipairs(items) do labels[#labels+1] = it.label end
    -- should include both @home-office and @ctx2 and @work filtered by prefix 'ho'
    assert.truthy(vim.tbl_contains(labels, '@home-office'))
    -- ensure detail marks context
    local ctx_item = vim.tbl_filter(function(it) return it.detail == 'context' end, items)
    assert.is_true(#ctx_item > 0)
  end)

  it('completes projects after + using parser tags', function()
    local items = complete_with('Do something +Proj')
    local labels = {}
    for _, it in ipairs(items) do labels[#labels+1] = it.label end
    assert.truthy(vim.tbl_contains(labels, '+Proj_Main'))
    assert.truthy(vim.tbl_contains(labels, '+proj-aux_1'))
    local proj_item = vim.tbl_filter(function(it) return it.detail == 'project' end, items)
    assert.is_true(#proj_item > 0)
  end)
end)
