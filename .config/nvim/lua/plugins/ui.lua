-- UI configuration
-- This file configures Lualine, Which-key, and other UI components

return {
  -- Lualine - statusline
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local ok, lualine = pcall(require, "lualine")
      if not ok then
        return
      end
      lualine.setup({
        options = {
          theme = "auto",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          globalstatus = true,
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = {
            {
              "filename",
              file_status = true,
              path = 1,
              shorting_target = 40,
            },
          },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { "filename" },
          lualine_x = { "location" },
          lualine_y = {},
          lualine_z = {},
        },
        tabline = {},
        extensions = { "neo-tree", "fugitive" },
      })
    end,
  },

  -- Which-key - keybinding discovery
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("which-key").setup({
        preset = "modern",
        win = {
          border = "rounded",
        },
        spec = {
          { "<leader>e", group = "Explorer" },
          { "<leader>f", group = "Find" },
          { "<leader>g", group = "Git" },
          { "<leader>h", group = "Help" },
          { "<leader>l", group = "LSP" },
          { "<leader>t", group = "Terminal" },
          { "<leader>w", group = "Window" },
          { "<leader>b", group = "Buffer" },
          { "<leader>q", group = "Quit" },
        },
      })
    end,
  },

  -- nvim-web-devicons - icons
  {
    "nvim-tree/nvim-web-devicons",
    config = function()
      require("nvim-web-devicons").setup({
        default = true,
      })
    end,
  },

  -- Comment.nvim - comment toggling
  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup({
        toggler = {
          line = "<leader>/",
          block = "<leader>?",
        },
        opleader = {
          line = "<leader>/",
          block = "<leader>?",
        },
      })
    end,
  },

  -- Indent-blankline - indentation guides
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {
      indent = {
        char = "",
      },
      scope = {
        enabled = true,
      },
      exclude = {
        filetypes = {
          "help",
          "alpha",
          "dashboard",
          "neo-tree",
          "Trouble",
          "lazy",
          "mason",
          "notify",
          "toggleterm",
          "lazyterm",
        },
      },
    },
  },

  -- nvim-notify - better notifications
  {
    "rcarriga/nvim-notify",
    config = function()
      require("notify").setup({
        background_colour = "#000000",
        fps = 60,
        render = "compact",
        stages = "fade",
        timeout = 3000,
        top_down = true,
      })
      vim.notify = require("notify")
    end,
  },
}
