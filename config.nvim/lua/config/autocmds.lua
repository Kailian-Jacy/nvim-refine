-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Load user commands and pickers
require("config.commands")
require("config.pickers")

-- Tab tracking
vim.api.nvim_create_autocmd("TabLeave", {
  pattern = "*",
  callback = function()
    if vim.g.pinned_tab == nil or vim.g.pinned_tab.id ~= vim.api.nvim_get_current_tabpage() then
      vim.g.last_tab = vim.api.nvim_get_current_tabpage()
    end
  end,
})

vim.api.nvim_create_autocmd("TabClosed", {
  pattern = "*",
  callback = function()
    local closed_tab = vim.fn.expand("<afile>")
    if vim.g.pinned_tab and closed_tab == vim.g.pinned_tab.id then
      vim.cmd("UnpinTab")
    end
    if vim.g.last_tab == closed_tab then
      vim.g.last_tab = nil
    end
  end,
})

-- Autoload files that have been changed externally. Triggers ":h autoread"
vim.api.nvim_create_autocmd("FocusGained", {
  pattern = "*",
  callback = function ()
    vim.cmd [[ checktime ]]
  end,
})

-- Yanky ring filter
if not vim.g.yanky_ring_accept_length then
  vim.notify("vim.g.yanky_ring_accept_length is not set. Default to be 10.")
  vim.g.yanky_ring_accept_length = 10
end
if not vim.g.yanky_ring_max_accept_length then
  vim.notify("vim.g.yanky_ring_max_accept_length is not set. Default to be 1000.")
  vim.g.yanky_ring_max_accept_length = 1000
end

---@param copied_content string
---@return string|nil
local _yanky_hook_before_copy_body = function(copied_content)
  if #vim.trim(copied_content) < vim.g.yanky_ring_accept_length then
    return nil
  end
  if #vim.trim(copied_content) > vim.g.yanky_ring_max_accept_length then
    return nil
  end
  return copied_content
end

local _yanky_hook_before_copy = function()
  local content = _yanky_hook_before_copy_body(vim.fn.getreg('"'))
  if content then
    require("yanky.history").push({
      regcontents = vim.trim(content),
      regtype = "y",
    })
  end
end

vim.api.nvim_create_autocmd("TextYankPost", {
  pattern = "*",
  callback = function()
    local reg = vim.v.event.regname
    if reg == nil or #reg == 0 then
      _yanky_hook_before_copy()
    end
  end,
})

-- Highlight related.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "*" },
  callback = function()
    if vim.tbl_contains(vim.g.use_treesitter_highlight, vim.bo.filetype) then
      vim.cmd([[ TSBufEnable highlight ]])
    else
      vim.bo.syntax = "on"
    end
  end,
})

-- Quickfix related - page closing
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "qf", "gitsigns-blame" },
  callback = function()
    vim.keymap.set(
      "n",
      "q",
      "<cmd>bd<cr>",
      { desc = "Using q to close quickfix page.", silent = true, buffer = true, noremap = false }
    )
  end,
})

-- Help page closing.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "help", "man" },
  callback = function()
    vim.keymap.set(
      "n",
      "q",
      "<c-w>c",
      { desc = "Using q to close help and man page.", silent = true, buffer = true, noremap = false }
    )
  end,
})

-- Highlight yanking
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("highlight_yank", {}),
  desc = "Hightlight selection on yank",
  pattern = "*",
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 100 })
  end,
})

-- Macro recording related.
local function _safe_lualine_refresh()
  local ok, lualine = pcall(require, "lualine")
  if ok then lualine.refresh() end
end

vim.api.nvim_create_autocmd("RecordingEnter", {
  callback = function()
    vim.g.recording_status = true
    _safe_lualine_refresh()
    vim.print_silent("Macro recording.")
  end,
})

vim.api.nvim_create_autocmd("RecordingLeave", {
  callback = function()
    vim.g.recording_status = false
    _safe_lualine_refresh()
    vim.print_silent("End recording.")
  end,
})

-- Start at the last place exited.
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.g.LAST_WORKING_DIRECTORY then
      vim.cmd("cd " .. (vim.g.LAST_WORKING_DIRECTORY or ""))
    end
  end,
})
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    vim.g.LAST_WORKING_DIRECTORY = vim.fn.getcwd()
  end,
})
vim.api.nvim_create_autocmd("VimLeave", {
  callback = function()
    -- Detach from tmux shell.
    local tmux_client_pid = vim.g.__tmux_get_current_attached_client_pid()
    if tmux_client_pid and #tmux_client_pid > 0 then
      for _, pid in ipairs(tmux_client_pid) do
        if #pid > 0 then
          vim.cmd("!kill -s SIGHUP " .. pid)
        end
      end
    else
      vim.cmd("!tmux detach -s " .. (vim.g.terminal_default_tmux_session_name or "nvim-attached"))
    end
    -- https://github.com/neovim/neovim/issues/21856
    vim.cmd("!tmux detach -s " .. (vim.g.terminal_default_tmux_session_name or "nvim-attached"))
    vim.cmd("sleep 10m")
  end,
})

-- keymap for markdown ft
local function is_obs_md(buf)
  if vim.bo[buf].filetype == "markdown" and vim.startswith(vim.fn.expand("%:p"), vim.g.obsidian_vault) then
    return true
  end
  return false
end

vim.api.nvim_create_autocmd("BufRead", {
  group = vim.api.nvim_create_augroup("markdown", { clear = true }),
  callback = function(opts)
    if is_obs_md(opts.buf) then
      vim.keymap.set({ "n", "v" }, "<leader>fd", "<cmd>ObsidianBridgeTelescopeCommand<CR>", { buffer = true })
      vim.keymap.set({ "n", "v" }, "gf", function()
        if require("obsidian").util.cursor_on_markdown_link() then
          return "<cmd>ObsidianFollowLink<CR>"
        else
          return "gf"
        end
      end, { buffer = true })
      vim.keymap.set(
        { "n", "v" },
        "<leader>pi",
        "<cmd>ObsidianPasteImg " .. os.date("%Y%m%d%H%M%S") .. "<cr>",
        { buffer = true }
      )
    else
      if vim.bo[opts.buf].filetype == "markdown" then
        vim.keymap.set({ "n", "v" }, "<leader>pi", "<cmd>PasteImage<cr>", { buffer = true })
      end
    end
  end,
})

-- Lint on save
vim.api.nvim_create_autocmd({ "BufWritePost" }, {
  callback = function()
    local ok, l = pcall(require, "lint")
    if ok then l.try_lint() end
  end,
})

-- DAP close float window on esc/q
vim.api.nvim_create_autocmd("FileType", {
  pattern = "dap-float",
  callback = function()
    vim.api.nvim_buf_set_keymap(0, "n", "<esc>", "<cmd>close!<CR>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(0, "n", "q", "<cmd>close!<CR>", { noremap = true, silent = true })
  end,
})

-- Set cursor
vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"
if vim.fn.has("nvim-0.11") == 1 then
  vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20,t:ver25"
end

-- Diagnostics configuration
vim.diagnostic.config({
  virtual_text = false,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    focusable = false,
    style = "minimal",
    border = "rounded",
    source = "always",
    header = "",
    prefix = "",
  },
})

-- Hex and binary autocmds.
if vim.g.read_binary_with_xxd or false then
  local before_open_hex = function()
    require("hex").dump()
  end
  vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = { "*.bin", "*.o", "*.exe", "*.a" },
    callback = function()
      vim.cmd("setfiletype xxd")
      before_open_hex()
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "xxd",
    callback = before_open_hex,
  })
end

-- OSC52 to sync remote to local clipboard.
local copy = function()
  if vim.v.event.operator == "y" then
    require("vim.ui.clipboard.osc52").copy('"')
  end
end

vim.api.nvim_create_autocmd("TextYankPost", { callback = copy })

-- barbecue.nvim removed: replaced with standalone nvim-navic (Issue #45)

-- Avante keymaps.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "Avante" },
  callback = function()
    vim.keymap.set(
      "n",
      "<c-c>",
      require("avante.api").stop,
      { desc = "Stop avante generation in avante window.", silent = true, buffer = true, noremap = false }
    )
  end,
})

-- GitInfo command: quick summary of current git state (Issue #13: scriptlize git info for workflow)
vim.api.nvim_create_user_command("GitInfo", function()
  local function run(cmd)
    return vim.fn.trim(vim.fn.system(cmd .. " 2>/dev/null"))
  end

  local branch = run("git rev-parse --abbrev-ref HEAD")
  if branch == "" or vim.v.shell_error ~= 0 then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return
  end

  local lines = { "Git Info:" }
  table.insert(lines, "  Branch: " .. branch)

  -- Ahead/behind upstream
  local ab = run("git rev-list --count --left-right @{upstream}...HEAD")
  if ab ~= "" then
    local behind, ahead = ab:match("(%d+)%s+(%d+)")
    if behind and ahead then
      table.insert(lines, "  Ahead: " .. ahead .. "  Behind: " .. behind)
    end
  end

  -- Stash count
  local stash = run("git stash list | wc -l")
  if stash ~= "" and stash ~= "0" then
    table.insert(lines, "  Stashes: " .. stash)
  end

  -- File status counts
  local status = run("git status --porcelain")
  if status ~= "" then
    local staged, unstaged, untracked = 0, 0, 0
    for line in status:gmatch("[^\n]+") do
      local x, y = line:sub(1, 1), line:sub(2, 2)
      if x == "?" then
        untracked = untracked + 1
      else
        if x ~= " " and x ~= "?" then staged = staged + 1 end
        if y ~= " " and y ~= "?" then unstaged = unstaged + 1 end
      end
    end
    table.insert(lines, "  Staged: " .. staged .. "  Unstaged: " .. unstaged .. "  Untracked: " .. untracked)
  else
    table.insert(lines, "  Working tree clean")
  end

  -- Merge/rebase/cherry-pick state
  local git_dir = run("git rev-parse --git-dir")
  if vim.fn.filereadable(git_dir .. "/MERGE_HEAD") == 1 then
    table.insert(lines, "  State: MERGING")
  elseif vim.fn.isdirectory(git_dir .. "/rebase-merge") == 1 or vim.fn.isdirectory(git_dir .. "/rebase-apply") == 1 then
    table.insert(lines, "  State: REBASING")
  elseif vim.fn.filereadable(git_dir .. "/CHERRY_PICK_HEAD") == 1 then
    table.insert(lines, "  State: CHERRY-PICKING")
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, { desc = "Show git repository status summary" })
