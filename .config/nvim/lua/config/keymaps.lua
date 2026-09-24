-- Keybindings configuration
-- This file contains all custom keybindings

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Save and quit
keymap("n", "<leader>w", ":w<CR>", opts)
keymap("n", "<leader>q", ":q<CR>", opts)
keymap("n", "<leader>Q", ":qa<CR>", opts)

-- Buffer navigation
keymap("n", "<S-h>", ":bprevious<CR>", opts)
keymap("n", "<S-l>", ":bnext<CR>", opts)
keymap("n", "<leader>bd", ":bdelete<CR>", opts)

-- Window navigation
keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)

-- Window resizing
keymap("n", "<C-Up>", ":resize +2<CR>", opts)
keymap("n", "<C-Down>", ":resize -2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Clear search highlighting
keymap("n", "<leader>h", ":nohlsearch<CR>", opts)

-- Better indenting in visual mode
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- Move lines up and down
keymap("n", "<A-j>", ":m .+1<CR>==", opts)
keymap("n", "<A-k>", ":m .-2<CR>==", opts)
keymap("v", "<A-j>", ":m '>+1<CR>gv=gv", opts)
keymap("v", "<A-k>", ":m '<-2<CR>gv=gv", opts)

-- System clipboard explicit mappings (fallback if unnamedplus doesn't work)
keymap("n", "<leader>y", '"+y', opts)
keymap("v", "<leader>y", '"+y', opts)
keymap("n", "<leader>Y", '"+Y', opts)
keymap("n", "<leader>p", '"+p', opts)
keymap("n", "<leader>P", '"+P', opts)
keymap("v", "<leader>p", '"+p', opts)
keymap("v", "<leader>P", '"+P', opts)

-- Quick fix navigation
keymap("n", "[d", vim.diagnostic.goto_prev, opts)
keymap("n", "]d", vim.diagnostic.goto_next, opts)
keymap("n", "<leader>e", vim.diagnostic.open_float, opts)
keymap("n", "<leader>q", vim.diagnostic.setloclist, opts)

-- Toggle term (placeholder, will be configured in terminal.lua)
keymap("n", "<leader>tt", function()
  require("plugins.terminal").toggle()
end, opts)

-- Comment toggling (will be configured by comment.nvim plugin)
keymap("n", "<leader>/", function()
  return vim.fn.mode() == "n" and "gcc" or "gc"
end, { expr = true, noremap = true, silent = true })
keymap("v", "<leader>/", "gc", { noremap = true, silent = true })

-- File explorer (will be configured by neo-tree plugin)
keymap("n", "<leader>e", ":Neotree toggle<CR>", opts)

-- Telescope mappings (will be configured in navigation.lua)
keymap("n", "<C-p>", function()
  require("telescope.builtin").find_files()
end, opts)
keymap("n", "<C-f>", function()
  require("telescope.builtin").live_grep()
end, opts)

-- LSP keybindings are now configured in lsp.lua's on_attach function

-- Quick list navigation
keymap("n", "<leader>co", ":copen<CR>", opts)
keymap("n", "<leader>cc", ":cclose<CR>", opts)
keymap("n", "<leader>cn", ":cnext<CR>", opts)
keymap("n", "<leader>cp", ":cprev<CR>", opts)

-- Location list navigation
keymap("n", "<leader>lo", ":lopen<CR>", opts)
keymap("n", "<leader>lc", ":lclose<CR>", opts)
keymap("n", "<leader>ln", ":lnext<CR>", opts)
keymap("n", "<leader>lp", ":lprev<CR>", opts)
