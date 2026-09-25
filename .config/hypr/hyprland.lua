-- Violet Night · Hyprland 0.55+ (Lua configuration).
-- Keep keyboard shortcuts separate so they can be refined later.
local home = os.getenv("HOME")
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
hl.env("XCURSOR_THEME", "breeze_cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GTK_THEME", "VioletNight:dark")
-- qt6ct also accepts the qt5ct key, so both Qt generations use their palette.
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.config({
    general = {
        gaps_in = 5, gaps_out = 12, border_size = 2,
        col = {
            active_border = { colors = { "rgba(cf5affff)", "rgba(a69bffff)" }, angle = 45 },
            inactive_border = "rgba(493455ff)",
        },
        resize_on_border = true, layout = "dwindle",
    },
    decoration = {
        rounding = 14,
        shadow = { enabled = true, range = 18, render_power = 3, color = "rgba(100b18aa)" },
        blur = { enabled = true, size = 5, passes = 2 },
    },
    animations = { enabled = true },
    input = {
        kb_layout = "cz", follow_mouse = 1,
        touchpad = { natural_scroll = true },
    },
    dwindle = { preserve_split = true },
    misc = { disable_hyprland_logo = true, force_default_wallpaper = 0 },
})
hl.curve("violet", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "violet", style = "popin 96%" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "violet", style = "slide" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "violet" })
hl.animation({ leaf = "border", enabled = true, speed = 4, bezier = "violet" })
hl.window_rule({
    name = "settings-dialogs",
    match = { class = "^(org.pulseaudio.pavucontrol|nm-connection-editor|nm-applet|qt6ct)$" },
    float = true, size = "900 650", center = true,
})
hl.window_rule({
    name = "dropdown-terminal",
    match = { class = "^dropdown-terminal$" },
    float = true, size = "80% 70%", center = true,
})
hl.on("hyprland.start", function()
    hl.exec_cmd(home .. "/.scripts/hypr-session.sh")
end)
dofile(home .. "/.config/hypr/keybinds.lua")
-- Optional machine-specific monitor/input overrides, preserved by the installer.
local local_config = home .. "/.config/hypr/local.lua"
local f = io.open(local_config, "r")
if f then f:close(); dofile(local_config) end
