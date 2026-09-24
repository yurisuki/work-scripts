-- Neovim Configuration Entry Point
-- This file loads all configuration modules

-- Set leader keys BEFORE loading lazy.nvim
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Bootstrap lazy.nvim plugin manager
require("config.lazy")

-- Load basic options
require("config.options")

-- Load keybindings
require("config.keymaps")

-- Load plugins
require("plugins.theme")
require("plugins.navigation")
require("plugins.lsp")
require("plugins.completion")
require("plugins.treesitter")
require("plugins.git")
require("plugins.formatting")
require("plugins.ui")
require("plugins.terminal")
