# todo-txt.nvim

A Neovim plugin for managing your todo.txt files directly from within Neovim. This plugin provides a clean and efficient interface for working with [todo.txt](http://todotxt.org/) format files, following the todo.txt format specification.

## Features

- Create todo items with automatic creation date prefixing
- Add priority when adding a task by starting with the priority and a colon i.e. "A: new task"
- Mark tasks as complete with automatically added completion date
- Edit existing tasks through a floating window interface
- View all tasks in a sorted list
- Clean and minimal UI with customizable floating window
- Seamless integration with Neovim
- Archive completed tasks to a separate file
- Add or change task priorities
- Filter by tag (@context or +project) and/or due date
- Cascading filters (filter by tag and due date)
- Due date helpers with shortcuts (`:today`, `:tomorrow`, `:nextweek`, etc.)
- Simplified blink.cmp integration
- Track tasks to calculate total time spent on a task

## Features I might implement in the future

- [x] Add due date helpers to nvim-cmp
- [ ] Improve tag filter by using the completion instead of being on the tag under cursor.
- [ ] Filter tasks due today.
- [ ] Create local (per project) todo files.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'cche/todo-txt.nvim',
    dependencies = {
        'hrsh7th/nvim-cmp'
        # or blink.cmp
        'saghen/blink.cmp
    },
    config = function()
        require('todo-txt').setup()
    end
}
```

## Configuration

The plugin comes with sensible defaults, but you can customize it to your needs:

```lua
require('todo-txt').setup({
    todo_file = vim.fn.expand("~/todo.txt"), -- Path to your todo.txt file
    done_file = vim.fn.expand("~/done.txt"), -- Optional: Path to your done.txt file (defaults to done.txt in the same directory as todo.txt)
    window = {
        width = 60,     -- Width of the floating window
        height = 10,    -- Height of the floating window
        border = "rounded", -- Border style of windows
    },
    -- Sorting configuration (order of criteria). Supported keys: 'priority', 'due'
    sort = {
        by = { 'priority', 'due' }, -- default order
    },
    disable_default_mappings = true -- Disable default key mappings
})
```

The floating window will cover 80% of the screen space by default, but you can adjust the width and height as needed.

In order to disable the default key mappings, you can pass `disable_default_mappings` to the setup function, and then define your own mappings:

```lua
require('todo-txt').setup({ disable_default_mappings = true })

-- Define your own key mappings (the default mappings are shown here)
vim.keymap.set("n", "<leader>tt", ":TodoList<CR>", { desc = "Todo List", noremap = true, silent = true })
vim.keymap.set("n", "<leader>ta", ":TodoAdd<CR>", { desc = "Add Todo", noremap = true, silent = true })
vim.keymap.set("n", "<leader>td", ":TodoDue<CR>", { desc = "Due Tasks", noremap = true, silent = true })
vim.keymap.set("n", "<leader>tz", ":TodoArchive<CR>", { desc = "Archive Done Tasks", noremap = true, silent = true })
```

### Completion

Completion can be configured for nvim-cmp or blink.cmp.

#### nvim-cmp

Add the source "todo" to the list of default sources and add the source to the providers

```lua
opts = {
    sources = {
        default = {"lsp", "path", "snippets", "buffer", "lazydev", "todo" },
        providers = {
            todo = { name = "todo-txt", module = "todo-cmp" },
        }
    }
}
```

#### blink.cmp

To show only todo completions in add/edit windows, use a dynamic `default` function:

```lua
opts = {
    sources = {
        default = function()
            local ui = require("todo-txt.ui")
            if ui.is_todo_input_window() then
                return { "todo" }
            else
                return { "lsp", "path", "snippets", "buffer", "lazydev", "todo" }
            end
        end,
        providers = {
            todo = { name = "todo-txt", module = "todo-blink" },
        }
    }
}
```

This ensures that only todo tag completions appear when adding or editing tasks, while normal completions work everywhere else.

## Usage

### Commands

The plugin provides several commands for managing your todos:

- `:TodoList` - Show all todo items in a floating window
- `:TodoAdd`  - Open a window to create a new todo item
- `:TodoDue`  - Show only due tasks in a floating window
- `:TodoArchive` - Move all completed tasks to done.txt

### Viewing and Adding tasks

The `:TodoList` command shows all your todo items in a floating window, with the ability to mark them as complete, edit existing entries, or add a priority.
The `:TodoDue` command shows only tasks with due dates (same as pressing 'd' in the todo list).
The `:TodoAdd` command will open a floating window to create a new todo item. You can also add a todo item by pressing 'a' in the todo list window.

When editing or adding a todo item, you can press `\<CR>` to save the changes.
When you press `\<Esc>` you will be in normal mode where `\<CR>` will save and pressing `\<Esc>` will cancel.

### Priorities

To add a priority when creating a todo item, you can start the todo item with a capital letter and a colon, i.e. "A: new task".

If the item already exists, you can press 'p' when on the task to assign a priority.
It has to be a capital letter between A-Z.

### Due Date Helpers

When adding or editing tasks, you can use convenient shortcuts that automatically expand to `due:YYYY-MM-DD` format:

**Common shortcuts:**

- `:today` - Today's date
- `:tomorrow` - Tomorrow's date
- `:nextweek` - 7 days from now

**Weekday shortcuts:**

- `:monday`, `:tuesday`, `:wednesday`, `:thursday`, `:friday`, `:saturday`, `:sunday` - Next occurrence of that weekday

**Relative shortcuts:**

- `:1d`, `:2d`, `:3d` - 1, 2, or 3 days from now
- `:1w`, `:2w` - 1 or 2 weeks from now
- `:1m` - 1 month (30 days) from now

**Example:**

Type `Buy groceries :tomorrow` and it will automatically expand to `Buy groceries due:2025-01-24` when you save.

These shortcuts also appear in completion suggestions (type `:` to see them). It will only appear when preceded by a space to avoid conflict with the priority syntax (`A:`).

### Tracking Tasks

Tasks in the task list are trackable. Pressing the keybinding `s` on the task you want to track will begin tracking and mark that task as being tracked. 

When you are finished tracking, pressing `s` on the task again will calculate the total time spent. You can track that same task again and the total time will 
continue to be added.

Marking a task as completed `<CR>` will also stop tracking and calculate the total time spent.

## Key Mappings

Default leader key mappings (can be disabled with `disable_default_mappings`):

- `<leader>tt` - Show todo list
- `<leader>ta` - Add new todo
- `<leader>td` - Show due tasks
- `<leader>tz` - Archive completed tasks

When in the todo list window:

- `<CR>` - Marks the selected todo item as complete (if item is being tracked, will stop tracking and calculate total time)
- `q`    - Close the window
- `e`    - Edit the selected item
- `a`    - Add a new todo item
- `p`    - Set priority for the selected item
- `f`    - Toggle filter by the @context or +project under cursor
- `d`    - Toggle due date filter (combines with tag filter if active)
- `s`    - Toggle tracking on/off (total is calculated when tracking is off)
- `r`    - Clear all filters and show complete list

**Cascading Filters:** Filters can be combined! For example:

1. Press `f` on a tag to filter by that tag (press `f` on same tag again to clear)
2. Press `d` to further filter to only due tasks with that tag
3. Press `d` again to show all tasks with that tag (due filter off)
4. Press `f` on the same tag to clear tag filter (keeps due filter if active)
5. Press `r` to clear all filters at once and return to the full list

When editing a todo item:

- `<CR>`  - Save changes
- `<Esc>` - Cancel editing

When setting priority:

- Enter a single capital letter (A-Z) and press `<CR>` to set the priority.
- Press `<Esc>` to cancel.
- To remove priority, press 'p' then press `<CR>` without entering a letter.

## Task Format

Tasks follow the [todo.txt format](http://todotxt.org/):

- Priority is indicated with capital letters in parentheses: `(A) High priority task`
- Creation date is automatically added: `2025-01-13 Do something`
- Due dates can be specified with `due:YYYY-MM-DD`

Example tasks:

```text
(A) 2025-01-13 High priority task due:2027-01-20
(B) 2025-01-13 Medium priority task with @context and +project
2025-01-13 No priority task
```

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

This plugin is based on the [todo.txt](http://todotxt.org/) format created by Gina Trapani.
This plugin was built while testing Cascade in Windsurf, an editor developed by [Windsurf](https://windsurf.com/).
