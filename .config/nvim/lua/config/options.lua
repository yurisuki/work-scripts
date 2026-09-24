-- Basic Neovim options and settings
-- This file contains core Neovim configuration

-- Clipboard integration with Wayland
-- This makes y/p use the system clipboard by default
vim.opt.clipboard = "unnamedplus"

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Cursor line highlighting
vim.opt.cursorline = true

-- Indentation
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.autoindent = true

-- Search settings
vim.opt.incsearch = true
vim.opt.hlsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Scrolling
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.signcolumn = "yes"

-- Split behavior
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Mouse support
vim.opt.mouse = "a"

-- Persistent undo
vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath("data") .. "/undo"

-- Better display
vim.opt.wrap = false
vim.opt.linebreak = true
vim.opt.breakindent = true

-- Performance
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300

-- Completion
vim.opt.completeopt = { "menu", "menuone", "noselect" }

-- File encoding
vim.opt.fileencoding = "utf-8"

-- Backups and swap files
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false

-- Command line height
vim.opt.cmdheight = 1

-- Show mode in statusline instead of command line
vim.opt.showmode = false

-- Hide buffers instead of closing them
vim.opt.hidden = true

-- Reduce command line height for completion
vim.opt.pumheight = 10

-- Wildmenu settings
vim.opt.wildmenu = true
vim.opt.wildmode = "longest:full,full"

-- Fillchars
vim.opt.fillchars = {
  fold = " ",
  eob = " ",
}

-- Fold settings (will be set by treesitter when loaded)
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
