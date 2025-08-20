require('plenary.busted')
local blink_source = require('todo-blink')

-- Helper to call get_completions and capture items
local function complete_with(line, col)
  local source = blink_source.new()
  local ctx = {
    line = line,
    cursor = { 
      row = 1, 
      col = col or #line 
    }
  }
  local items
  source:get_completions(ctx, function(result)
    items = result.items
  end)
  return items or {}
end

describe('todo-blink source', function()
  local orig_get_entries
  local orig_nvim_win_get_var
  
  before_each(function()
    -- Mock window variable to force availability
    orig_nvim_win_get_var = vim.api.nvim_win_get_var
    vim.api.nvim_win_get_var = function(win, var)
      if var == "todo_txt_window_type" then
        return "add"
      end
      return orig_nvim_win_get_var(win, var)
    end
    
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
    vim.api.nvim_win_get_var = orig_nvim_win_get_var
    local todo = require('todo-txt')
    todo.get_entries = orig_get_entries
  end)

  it('completes contexts after @ using parser tags', function()
    local items = complete_with('Do something @ho', 15)
    local labels = {}
    for _, it in ipairs(items) do labels[#labels+1] = it.label end
    -- should include @home-office filtered by prefix 'ho'
    assert.truthy(vim.tbl_contains(labels, '@home-office'))
    -- ensure detail marks context
    local ctx_item = vim.tbl_filter(function(it) return it.detail == 'context' end, items)
    assert.is_true(#ctx_item > 0)
    -- check that textEdit replaces the whole @ho with @home-office
    local home_office_item = vim.tbl_filter(function(it) return it.label == '@home-office' end, items)[1]
    assert.equals('@home-office', home_office_item.textEdit.newText)
    assert.equals(13, home_office_item.textEdit.range.start.character) -- start of @ho
    assert.equals(15, home_office_item.textEdit.range['end'].character) -- end of @ho
  end)

  it('completes projects after + using parser tags', function()
    local items = complete_with('Do something +Proj', 17)
    local labels = {}
    for _, it in ipairs(items) do labels[#labels+1] = it.label end
    assert.truthy(vim.tbl_contains(labels, '+Proj_Main'))
    assert.truthy(vim.tbl_contains(labels, '+proj-aux_1'))
    local proj_item = vim.tbl_filter(function(it) return it.detail == 'project' end, items)
    assert.is_true(#proj_item > 0)
    -- check that textEdit replaces the whole +Proj with +Proj_Main
    local proj_main_item = vim.tbl_filter(function(it) return it.label == '+Proj_Main' end, items)[1]
    assert.equals('+Proj_Main', proj_main_item.textEdit.newText)
    assert.equals(13, proj_main_item.textEdit.range.start.character) -- start of +Proj
    assert.equals(17, proj_main_item.textEdit.range['end'].character) -- end of +Proj
  end)

  it('returns empty when not in add/edit window', function()
    -- Override the window variable to simulate not being in add window
    vim.api.nvim_win_get_var = function(win, var)
      if var == "todo_txt_window_type" then
        error("Variable not found")
      end
      return orig_nvim_win_get_var(win, var)
    end
    
    -- Also mock win_get_config to return empty title
    local orig_nvim_win_get_config = vim.api.nvim_win_get_config
    vim.api.nvim_win_get_config = function(win)
      return { title = nil }
    end
    
    local items = complete_with('Do something @ho', 15)
    assert.equals(0, #items)
    
    -- Restore
    vim.api.nvim_win_get_config = orig_nvim_win_get_config
  end)

  it('returns empty when no trigger character found', function()
    local items = complete_with('Do something normal', 19)
    assert.equals(0, #items)
  end)

  it('has correct trigger characters', function()
    local source = blink_source.new()
    local triggers = source:get_trigger_characters()
    assert.truthy(vim.tbl_contains(triggers, '@'))
    assert.truthy(vim.tbl_contains(triggers, '+'))
  end)

  it('enabled returns true when available', function()
    local source = blink_source.new()
    assert.is_true(source:enabled())
  end)

  it('enabled returns false when not available', function()
    -- Override the window variable to simulate not being in add window
    vim.api.nvim_win_get_var = function(win, var)
      if var == "todo_txt_window_type" then
        error("Variable not found")
      end
      return orig_nvim_win_get_var(win, var)
    end
    
    -- Also mock win_get_config to return empty title
    local orig_nvim_win_get_config = vim.api.nvim_win_get_config
    vim.api.nvim_win_get_config = function(win)
      return { title = nil }
    end
    
    local source = blink_source.new()
    assert.is_false(source:enabled())
    
    -- Restore
    vim.api.nvim_win_get_config = orig_nvim_win_get_config
  end)
end)
