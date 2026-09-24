-- Terminal configuration
-- This file configures Toggleterm for integrated terminal

local M = {}

M.toggle = function()
  local Terminal = require("toggleterm.terminal").Terminal
  local term = Terminal:new({
    direction = "horizontal",
    close_on_exit = true,
    shell = vim.o.shell,
  })
  term:toggle()
end

return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        size = 20,
        open_mapping = [[<leader>tt]],
        hide_numbers = true,
        shade_terminals = true,
        start_in_insert = true,
        insert_mappings = true,
        persist_size = true,
        direction = "horizontal",
        close_on_exit = true,
        shell = vim.o.shell,
        float_opts = {
          border = "rounded",
        },
      })

      -- Terminal mode mappings
      local opts = { noremap = true, silent = true }

      -- Escape terminal mode
      vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], opts)
      vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
      vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
      vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
      vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)

      -- Toggle terminal
      vim.keymap.set("n", "<leader>tt", function()
        require("toggleterm").toggle()
      end, opts)

      -- Toggle terminal in vertical split
      vim.keymap.set("n", "<leader>tv", function()
        require("toggleterm").toggle(20, "vertical")
      end, opts)

      -- Toggle terminal in floating window
      vim.keymap.set("n", "<leader>tf", function()
        require("toggleterm").toggle(20, "float")
      end, opts)
    end,
  },
}
