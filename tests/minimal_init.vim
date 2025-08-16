" Minimal init for testing
set rtp+=.
set rtp+=/tmp/plenary.nvim

runtime plugin/plenary.vim

" Print vim.notify messages in headless runs
lua << EOF
local orig_notify = vim.notify
vim.notify = function(msg, level, opts)
  local lvl_name = "INFO"
  for k, v in pairs(vim.log.levels) do
    if v == level then
      lvl_name = k
      break
    end
  end
  -- Ensure plain output for CI/headless
  print(string.format("NOTIFY[%s]: %s", tostring(lvl_name), tostring(msg)))
  if orig_notify then
    pcall(orig_notify, msg, level, opts)
  end
end
EOF
