-- Violet Night · Hyprland 0.55+ (Lua configuration).
-- Keep keyboard shortcuts separate so they can be refined later.

local home = os.getenv("HOME")

hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

hl.env("XCURSOR_THEME", "breeze_cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GTK_THEME", "VioletNight:dark")

-- qt6ct also accepts the qt5ct key, so both Qt generations use their palette.
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")

hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 12,
		border_size = 2,

		col = {
			active_border = {
				colors = {
					"rgba(cf5affff)",
					"rgba(a69bffff)",
				},
				angle = 45,
			},

			inactive_border = "rgba(493455ff)",
		},

		resize_on_border = true,
		layout = "dwindle",
	},

	decoration = {
		rounding = 14,

		shadow = {
			enabled = true,
			range = 18,
			render_power = 3,
			color = "rgba(100b18aa)",
		},

		blur = {
			enabled = true,
			size = 5,
			passes = 2,
		},
	},

	animations = {
		enabled = true,
	},

	input = {
		kb_layout = "cz",
		follow_mouse = 1,
		-- Allow focusing underlying apps outside scratchpad windows.
		special_fallthrough = true,

		touchpad = {
			natural_scroll = true,
		},
	},

	dwindle = {
		preserve_split = true,
	},

	misc = {
		disable_hyprland_logo = true,
		force_default_wallpaper = 0,
	},
})

hl.curve("violet", {
	type = "bezier",
	points = {
		{ 0.22, 1 },
		{ 0.36, 1 },
	},
})

hl.animation({
	leaf = "windows",
	enabled = true,
	speed = 4,
	bezier = "violet",
	style = "popin 96%",
})

hl.animation({
	leaf = "workspaces",
	enabled = true,
	speed = 3,
	bezier = "violet",
	style = "slide",
})

hl.animation({
	leaf = "fade",
	enabled = true,
	speed = 3,
	bezier = "violet",
})

hl.animation({
	leaf = "border",
	enabled = true,
	speed = 4,
	bezier = "violet",
})

-- Normal terminals join the tiling layout; the dropdown keeps its own class.
hl.window_rule({
	name = "kitty-tiled",
	match = { class = "^kitty$" },
	tile = true,
	suppress_event = "maximize fullscreen",
})

-- Super+R opens superfile in Kitty; keep the file manager slightly transparent.
hl.window_rule({
	name = "superfile-transparent",
	match = { title = "^superfile$" },
	opacity = "0.90 0.90",
})

hl.window_rule({
	name = "settings-dialogs",
	match = {
		class = "^(org.pulseaudio.pavucontrol|nm-connection-editor|nm-applet|qt6ct)$",
	},
	float = true,
	size = "900 650",
	center = true,
})

hl.window_rule({
	name = "dropdown-terminal",
	match = {
		class = "^dropdown-terminal$",
	},
	float = true,
	size = "80% 70%",
	center = true,
})

-- Compact weather panel below the right side of Waybar.
hl.window_rule({
    name = "weather-popup",
    match = { class = "^weather-popup$" },
    float = true,
    size = "1040 740",
    move = "(monitor_w-1060) 65",
})

hl.on("hyprland.start", function()
	hl.exec_cmd(home .. "/.scripts/hypr-session.sh")
end)

-- Reusable scratchpad: keep the process alive while its workspace is hidden.
-- In keybinds.lua: toggle_app({ name = "notes", class = "my-notes",
--     command = "my-notes", size = "900 650" })
-- Use tiled = true to use the special workspace's tiling layout instead.
-- Use close_on_toggle = true to close running windows instead of hiding them.
function toggle_app(opts)
    assert(opts.name:match("^[%w_-]+$"), "toggle_app: invalid name")
    local workspace = "special:toggle-" .. opts.name
    local class_pattern = "^" .. opts.class:gsub("([\\.^$|?*+()%[%]{}])", "\\%1") .. "$"
    local rule = {
        name = "toggle-" .. opts.name,
        match = { class = class_pattern },
        workspace = workspace .. " silent",
    }
    if opts.tiled then
        rule.tile = true
    else
        rule.float = true
        rule.size = opts.size or "900 650"
        rule.center = true
    end
    hl.window_rule(rule)

    local launch_time = 0
    local function focus_if_visible(window)
        local active = hl.get_active_special_workspace()
        if active and active.name == workspace then
            hl.dispatch(hl.dsp.focus({ window = "address:" .. window.address }))
        end
    end
    hl.on("window.open", function(window)
        if launch_time > 0 and (window.class == opts.class or window.initial_class == opts.class) then
            launch_time = 0
            focus_if_visible(window)
        end
    end)
    return function()
        if opts.close_on_toggle then
            local closed = false
            for _, window in ipairs(hl.get_windows()) do
                if window.mapped and (window.class == opts.class or window.initial_class == opts.class) then
                    hl.dispatch(hl.dsp.window.close({ window = "address:" .. window.address }))
                    closed = true
                end
            end
            if closed then
                launch_time = 0
                local active = hl.get_active_special_workspace()
                if active and active.name == workspace then
                    hl.dispatch(hl.dsp.workspace.toggle_special("toggle-" .. opts.name))
                end
                return
            end
        end
        local found = false
        local target_window
        for _, window in ipairs(hl.get_windows()) do
            if window.mapped and (window.class == opts.class or window.initial_class == opts.class) then
                found = true
                target_window = target_window or window
                launch_time = 0
                if not window.workspace or window.workspace.name ~= workspace then
                    hl.dispatch(hl.dsp.window.move({
                        window = "address:" .. window.address,
                        workspace = workspace,
                        follow = false,
                    }))
                    hl.dispatch(hl.dsp.window.float({
                        window = "address:" .. window.address,
                        action = opts.tiled and "unset" or "set",
                    }))
                    if not opts.tiled then
                        local width, height = (opts.size or "900 650"):match("^(%d+) (%d+)$")
                        if width then
                            hl.dispatch(hl.dsp.window.resize({
                                window = "address:" .. window.address,
                                x = tonumber(width), y = tonumber(height), relative = false,
                            }))
                        end
                        hl.dispatch(hl.dsp.window.center({ window = "address:" .. window.address }))
                    end
                end
            end
        end
        if not found then
            -- Avoid duplicate launches while a slow application is starting.
            if os.time() - launch_time < 10 then return end
            launch_time = os.time()
            hl.exec_cmd(opts.command)
        end
        hl.dispatch(hl.dsp.workspace.toggle_special("toggle-" .. opts.name))
        if target_window then focus_if_visible(target_window) end
    end
end

dofile(home .. "/.config/hypr/keybinds.lua")

-- Optional machine-specific monitor/input overrides, preserved by the installer.
local local_config = home .. "/.config/hypr/local.lua"

local f = io.open(local_config, "r")

if f then
	f:close()
	dofile(local_config)
end
