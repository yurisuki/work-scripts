# Neovim Configuration

A modern, lightweight Neovim configuration built from scratch using Lua and lazy.nvim.

## System Dependencies (Manjaro Linux)

Install the following packages using pacman:

```bash
sudo pacman -S neovim git nodejs npm python python-pip ripgrep fd unzip curl
```

### Language Server Formatters

Install these formatters for automatic code formatting:

```bash
# Lua
sudo pacman -S stylua

# Python (use pacman package instead of pip)
sudo pacman -S python-black

# Bash
sudo pacman -S shfmt

# C/C++
sudo pacman -S clang
```

**For JavaScript/TypeScript/JSON/YAML/Markdown formatting:**

If you encounter Node.js library errors (libada.so.4), use one of these alternatives:

**Option 1: Use nvm (Node Version Manager) - Recommended**
```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Reload shell or restart terminal
source ~/.zshrc

# Install latest Node.js
nvm install node
nvm use node

# Install prettier
npm install -g prettier prettierd
```

**Option 2: Install prettier from AUR (if using yay/paru)**
```bash
yay -S prettier prettierd
# or
paru -S prettier prettierd
```

**Option 3: Skip prettier for now**
The configuration will work without prettier - you just won't have auto-formatting for JS/TS/JSON/YAML files.

**If pacman database is locked:**
```bash
sudo rm /var/lib/pacman/db.lck
```

### Optional: Tree-sitter CLI (for debugging)

```bash
sudo pacman -S tree-sitter
```

## Installation

1. **Backup your existing configuration** (if you have one):
   ```bash
   mv ~/.config/nvim ~/.config/nvim.backup
   mv ~/.local/share/nvim ~/.local/share/nvim.backup
   ```

2. **The configuration is already in place** at `~/.config/nvim/`

3. **Launch Neovim**:
   ```bash
   nvim
   ```

4. **Lazy.nvim will automatically install all plugins** on first launch.

## Launching Neovim

Simply run:
```bash
nvim
```

Or open a specific file:
```bash
nvim filename.lua
```

## Clipboard Verification

The configuration uses `unnamedplus` which integrates yank/paste with the Wayland system clipboard (via `wl-clipboard`).

**To verify clipboard works:**

1. Open Neovim: `nvim`
2. Type some text and yank it with `yy`
3. Paste it outside Neovim (e.g., in Chrome, Discord, or Konsole) with `Ctrl+V`
4. Copy some text from outside Neovim (e.g., from a web browser)
5. Paste it in Neovim with `p`

**Explicit clipboard mappings are also available:**
- `<leader>y` - yank to system clipboard
- `<leader>p` - paste from system clipboard
- `<leader>Y` - yank line to system clipboard

## Language Server Management

Language servers are managed via Mason. The configuration automatically installs these servers:

- `lua_ls` - Lua
- `bashls` - Bash
- `pyright` - Python
- `jsonls` - JSON
- `yamlls` - YAML
- `ts_ls` - TypeScript/JavaScript
- `clangd` - C/C++

**To manage language servers manually:**

1. Open Mason: `:Mason`
2. Navigate with `j`/`k`
3. Press `i` to install a server
4. Press `u` to uninstall a server
5. Press `U` to update all servers

**To install additional language servers:**

```vim
:Mason
```

Then search for the server you want and install it.

## Plugin Management

Plugins are managed by lazy.nvim.

**Common lazy.nvim commands:**

- `:Lazy` - Open the lazy.nvim UI
- `:Lazy sync` - Sync all plugins (install/update)
- `:Lazy clean` - Clean unused plugins
- `:Lazy update` - Update all plugins
- `:Lazy install` - Install all plugins
- `:Lazy log` - View plugin update logs

## Important Keybindings

### File Operations
- `<leader>w` - Save file
- `<leader>q` - Quit
- `<leader>Q` - Quit all
- `<leader>e` - Toggle file explorer (Neo-tree)
- `<C-p>` - Find files (Telescope)
- `<C-f>` - Live grep (Telescope)

### Navigation
- `<S-h>` - Previous buffer
- `<S-l>` - Next buffer
- `<leader>bd` - Delete buffer
- `<C-h>` - Move to left window
- `<C-j>` - Move to bottom window
- `<C-k>` - Move to top window
- `<C-l>` - Move to right window

### LSP (Language Server Protocol)
- `gd` - Go to definition
- `gD` - Go to declaration
- `gr` - Find references
- `gi` - Go to implementation
- `K` - Hover documentation
- `<leader>rn` - Rename symbol
- `<leader>ca` - Code actions
- `<leader>f` - Format file

### Diagnostics
- `[d` - Previous diagnostic
- `]d` - Next diagnostic
- `<leader>e` - Open diagnostic float
- `<leader>q` - Open diagnostic list

### Git (Gitsigns)
- `]c` - Next git hunk
- `[c` - Previous git hunk
- `<leader>hs` - Stage hunk
- `<leader>hr` - Reset hunk
- `<leader>hp` - Preview hunk
- `<leader>hb` - Blame line
- `<leader>hd` - Diff this

### Terminal
- `<leader>tt` - Toggle terminal (horizontal)
- `<leader>tv` - Toggle terminal (vertical)
- `<leader>tf` - Toggle terminal (float)
- `<Esc>` (in terminal mode) - Exit terminal mode

### Other
- `<leader>/` - Toggle comment
- `<leader>h` - Clear search highlighting
- `<leader>fm` - Format file/range

### Telescope
- `<leader>ff` - Find files
- `<leader>fg` - Live grep
- `<leader>fs` - Grep string under cursor
- `<leader>fb` - Find buffers
- `<leader>fr` - Recent files
- `<leader>fh` - Help tags
- `<leader>gf` - Git files

## Troubleshooting

### Plugins not installing

If plugins don't install automatically:

```bash
nvim --headless "+Lazy! sync" +qa
```

### Language servers not working

1. Check Mason: `:Mason`
2. Ensure the language server is installed
3. Check LSP logs: `:LspInfo`
4. Restart Neovim

### Clipboard not working

1. Verify `wl-clipboard` is installed: `pacman -Q wl-clipboard`
2. Check Neovim clipboard: `:echo has('clipboard')` should return `1`
3. If it returns `0`, you may need to install Neovim with clipboard support:
   ```bash
   sudo pacman -S neovim
   ```

### Treesitter not highlighting

1. Update Treesitter parsers: `:TSUpdate`
2. Check installed parsers: `:TSInstallInfo`
3. Restart Neovim

### Formatting not working

1. Ensure formatters are installed (see System Dependencies)
2. Check formatter status: `:ConformInfo`
3. Manually format: `<leader>fm`

### Performance issues

1. Disable plugins you don't need in the respective plugin files
2. Check plugin load time: `:Lazy profile`
3. Reduce the number of language servers installed

### Configuration errors

1. Check Neovim log: `:messages`
2. Check plugin logs: `:Lazy log`
3. Validate Lua syntax: `lua vim.cmd("luafile %")`

### Reset configuration

If you need to start fresh:

```bash
rm -rf ~/.config/nvim
rm -rf ~/.local/share/nvim
rm -rf ~/.local/state/nvim
rm -rf ~/.cache/nvim
```

Then restore from backup or reinstall.

## Configuration Structure

```
~/.config/nvim/
├── init.lua              # Entry point
├── README.md             # This file
├── lua/
│   ├── config/
│   │   ├── lazy.lua      # Plugin manager setup
│   │   ├── options.lua   # Basic Neovim options
│   │   └── keymaps.lua   # Keybindings
│   └── plugins/
│       ├── theme.lua     # Catppuccin colorscheme
│       ├── navigation.lua # Telescope and Neo-tree
│       ├── lsp.lua       # LSP and Mason
│       ├── completion.lua # nvim-cmp
│       ├── treesitter.lua # Syntax highlighting
│       ├── git.lua       # Gitsigns
│       ├── formatting.lua # Conform.nvim
│       ├── ui.lua        # Lualine, Which-key, etc.
│       └── terminal.lua  # Toggleterm
```

## Customization

### Changing the colorscheme

Edit `lua/plugins/theme.lua` and change the flavour:
- `"mocha"` (dark, default)
- `"latte"` (light)
- `"frappe"` (dark)
- `"macchiato"` (dark)

### Adding new plugins

Add a new file in `lua/plugins/` or add to an existing file following the lazy.nvim format.

### Modifying keybindings

Edit `lua/config/keymaps.lua` to add or modify keybindings.

### Adding new language servers

Edit `lua/plugins/lsp.lua` and add the server to the `ensure_installed` list and configure it.

## Features

- **Clipboard integration**: Seamless yank/paste with Wayland system clipboard
- **Modern completion**: nvim-cmp with LSP, buffer, path, and snippet completion
- **Fuzzy finding**: Telescope for files, grep, buffers, and more
- **File explorer**: Neo-tree with Git integration
- **LSP support**: Go to definition, references, hover, rename, code actions
- **Git integration**: Gitsigns for diff visualization and Git operations
- **Syntax highlighting**: Treesitter for accurate syntax highlighting
- **Auto-formatting**: Conform.nvim for automatic code formatting
- **Statusline**: Lualine with Git, diagnostics, and file info
- **Keybinding discovery**: Which-key for discovering available keybindings
- **Integrated terminal**: Toggleterm for running commands without leaving Neovim
- **Comment toggling**: Easy comment/uncomment with Comment.nvim
- **Indentation guides**: Visual indentation with indent-blankline

## Performance

This configuration is designed to be lightweight:
- Only essential plugins are included
- Lazy loading is used where appropriate
- No unnecessary features or bloat
- Fast startup time

## Support

For issues with specific plugins, refer to their respective GitHub repositories:
- lazy.nvim: https://github.com/folke/lazy.nvim
- nvim-cmp: https://github.com/hrsh7th/nvim-cmp
- Telescope: https://github.com/nvim-telescope/telescope.nvim
- Neo-tree: https://github.com/nvim-neo-tree/neo-tree.nvim
- And others...
