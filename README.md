# todo-txt.nvim

A Neovim plugin for managing your todo.txt files directly from within Neovim. This plugin provides a clean and efficient interface for working with [todo.txt](http://todotxt.org/) format files, following the todo.txt format specification.

## Features

- Create and manage todo items with automatic date prefixing
- Mark tasks as complete with completion dates
- Edit existing tasks through a floating window interface
- View all tasks in a formatted list
- Clean and minimal UI with customizable floating windows
- Native Neovim integration

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'cche/todo-txt.nvim',
    dependencies = {
        'hrsh7th/nvim-cmp'
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
    window = {
        width = 60,     -- Width of the floating window
        height = 10,    -- Height of the floating window
        border = "rounded", -- Border style of windows
    },
})
```

The floating window will cover 80% of the screen space by default, but you can adjust the width and height as needed.

## Usage

The plugin provides several commands for managing your todos:

- `:TodoList` - Show all todo items in a floating window
- `:TodoAdd`  - Open a window to create a new todo item
- `:TodoDue`  - Show only due tasks in a floating window

## Key Mappings

When in the todo list window:
- `<CR>` - Mark the selected todo item as complete
- `q`    - Close the window
- `e`    - Edit the selected item
- `a`    - Add a new todo item

When editing a todo item:
- `<CR>`  - Save changes
- `<Esc>` - Cancel editing

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

This plugin is inspired by the [todo.txt](http://todotxt.org/) format created by Gina Trapani.
