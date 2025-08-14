# todo-txt.nvim

A Neovim plugin for managing your todo.txt files directly from within Neovim. This plugin provides a clean and efficient interface for working with [todo.txt](http://todotxt.org/) format files, following the todo.txt format specification.

## Features

- Create and manage todo items with automatic date prefixing
- Add priority to the task at creation by starting with the priority and a colon "A: new task"
- Mark tasks as complete with completion dates
- Edit existing tasks through a floating window interface
- View all tasks in a sorted list
- Clean and minimal UI with customizable floating windows
- Native Neovim integration
- Archive completed tasks to a separate file
- Add or change task priorities

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'cche/todo-txt.nvim',
    dependencies = {
        'hrsh7th/nvim-cmp'
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
    disable_default_mappings = true -- Disable default key mappings
})
```

The floating window will cover 80% of the screen space by default, but you can adjust the width and height as needed.

In order to disable the default key mappings, you can pass `disable_default_mappings` to the setup function, and then define your own mappings:

```lua
require('todo-txt').setup({ disable_default_mappings = true })

-- Define your own key mappings
vim.keymap.set("n", "<leader>tt", ":TodoList<CR>", { desc = "Todo List", noremap = true, silent = true })
vim.keymap.set("n", "<leader>ta", ":TodoAdd<CR>", { desc = "Add Todo", noremap = true, silent = true })
vim.keymap.set("n", "<leader>td", ":TodoDue<CR>", { desc = "Due Tasks", noremap = true, silent = true })
vim.keymap.set("n", "<leader>tz", ":TodoArchive<CR>", { desc = "Archive Done Tasks", noremap = true, silent = true })
```

## Usage

### Commands

The plugin provides several commands for managing your todos:

- `:TodoList` - Show all todo items in a floating window
- `:TodoAdd`  - Open a window to create a new todo item
- `:TodoDue`  - Show only due tasks in a floating window
- `:TodoArchive` - Move all completed tasks to done.txt

### Viewing and Adding tasks

The :TodoList and :TodoDue will show a list of your todo items in a floating window, with the ability to mark them as complete, edit existing entries or add a priority.
The :TodoAdd command will open a floating window to create a new todo item. You can also add a todo item by pressing 'a' in the Todo or Due Tasks windows.

When editing or adding a todo item, you can press <enter> to save the changes.
When you press <esc> you will be in normal mode where <enter> will save and pressing <esc> will cancel.

### priorities

To add a priority to a todo item, you can start the item with a letter and a colon. If the item already exists, you can press 'p' when on the task to assign a priority. It has to be a capital letter between A-Z.

## Key Mappings

Default leader key mappings (can be disabled with `disable_default_mappings`):
- `<leader>tt` - Show todo list
- `<leader>ta` - Add new todo
- `<leader>td` - Show due tasks
- `<leader>tz` - Archive completed tasks

When in the todo list window:
- `<CR>` - Marks the selected todo item as complete
- `q`    - Close the window
- `e`    - Edit the selected item
- `a`    - Add a new todo item
- `p`    - Set priority for the selected item
- `f`    - Filters the tasks based on the @context or +project your cursor is on.
- `r`    - Return to the complete list when in the filtered list

When editing a todo item:
- `<CR>`  - Save changes
- `<Esc>` - Cancel editing

When setting priority:
- Enter a single capital letter (A-Z) and press `<CR>` to set the priority
- Press `<Esc>` to cancel
- To remove priority, press `<CR>` without entering a letter

## Task Format

Tasks follow the [todo.txt format](http://todotxt.org/):

- Priority is indicated with capital letters in parentheses: `(A) High priority task`
- Creation date is automatically added: `2025-01-13 Do something`
- Due dates can be specified with `due:YYYY-MM-DD`

Example tasks:
```
(A) 2025-01-13 High priority task due:2027-01-20
(B) 2025-01-13 Medium priority task with @context and +project
2025-01-13 Normal priority task
```

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

This plugin is inspired by the [todo.txt](http://todotxt.org/) format created by Gina Trapani.
This plugin was built while testing Cascade in Windsurf, an editor developed by [Codeium](https://codeium.com/).
