-- Git configuration
-- This file configures Gitsigns for Git integration

return {
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "" },
          change = { text = "" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
          untracked = { text = "" },
        },
        signcolumn = true,
        numhl = false,
        linehl = false,
        word_diff = false,
        watch_gitdir = {
          interval = 1000,
          follow_files = true,
        },
        attach_to_untracked = true,
        current_line_blame = false,
        current_line_blame_opts = {
          virt_text = true,
          virt_text_pos = "eol",
          delay = 1000,
          ignore_whitespace = false,
        },
        current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
        sign_priority = 6,
        update_debounce = 100,
        status_formatter = nil,
        max_file_length = 40000,
        preview_config = {
          border = "rounded",
          style = "minimal",
          row = 0,
          col = 0,
        },
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local keymap = vim.keymap.set
          local opts = { noremap = true, silent = true, buffer = bufnr }

          -- Navigation
          keymap("n", "]c", function()
            if vim.wo.diff then
              return "]c"
            end
            vim.schedule(function()
              gs.next_hunk()
            end)
            return "<Ignore>"
          end, { expr = true, buffer = bufnr })

          keymap("n", "[c", function()
            if vim.wo.diff then
              return "[c"
            end
            vim.schedule(function()
              gs.prev_hunk()
            end)
            return "<Ignore>"
          end, { expr = true, buffer = bufnr })

          -- Actions
          keymap("n", "<leader>hs", gs.stage_hunk, opts)
          keymap("n", "<leader>hr", gs.reset_hunk, opts)
          keymap("v", "<leader>hs", function()
            gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
          end, opts)
          keymap("v", "<leader>hr", function()
            gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
          end, opts)
          keymap("n", "<leader>hS", gs.stage_buffer, opts)
          keymap("n", "<leader>hu", gs.undo_stage_hunk, opts)
          keymap("n", "<leader>hR", gs.reset_buffer, opts)
          keymap("n", "<leader>hp", gs.preview_hunk, opts)
          keymap("n", "<leader>hb", function()
            gs.blame_line({ full = true })
          end, opts)
          keymap("n", "<leader>tb", gs.toggle_current_line_blame, opts)
          keymap("n", "<leader>hd", gs.diffthis, opts)
          keymap("n", "<leader>hD", function()
            gs.diffthis("~")
          end, opts)
          keymap("n", "<leader>td", gs.toggle_deleted, opts)

          -- Text object
          keymap({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", opts)
        end,
      })
    end,
  },
}
