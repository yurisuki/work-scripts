# Violet Night Hyprland

See [README.md](README.md) for the current installation, dependencies, shortcuts,
backup/restore procedure and laptop-specific settings.

The supported entry points are `./install.sh` and `./postinstall.sh`. The old
`.scripts/install-hyprland.sh` delegates to the same installer when run from the
repository checkout.

In Superfile, press `Shift+W` (or `e`) on an image to set it as the wallpaper.
The focused file is passed to `~/.scripts/set-wallpaper.sh`, which also saves
the wallpaper path for Hyprlock. For non-image files, these keys open `$EDITOR`
(Neovim by default). `Enter` keeps its usual open-file behavior, and `:` opens
the command prompt. Restart Superfile after changing its configuration.
