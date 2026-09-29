-- Starter bindings; the final keymap is intentionally a separate follow-up.
local scripts = os.getenv("HOME") .. "/.scripts/"
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(
	"SUPER + dead_acute",
	toggle_app({
		name = "dropdown-terminal",
		class = "dropdown-terminal",
		command = "kitty --class dropdown-terminal",
		size = "80% 70%",
	})
)
hl.bind("SUPER + R", hl.dsp.exec_cmd("gtk-launch superfile"))
hl.bind(
	"SUPER + C",
	toggle_app({
		name = "calculator",
		class = "io.github.Qalculate.qalculate-qt",
		command = "qalculate-qt",
		size = "720 600",
	})
)
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd(scripts .. "hypr-menu.sh browser"))
-- Settings open on the current workspace; repeated activation only focuses them.
local function settings_window(class, command)
    hl.window_rule({
        name = class,
        match = { class = "^" .. class .. "$" },
        float = true,
        size = "900 650",
        center = true,
    })
    local launched = 0
    return function()
        for _, window in ipairs(hl.get_windows()) do
            if window.mapped and window.class == class then
                local workspace = hl.get_active_workspace()
                if workspace then
                    hl.dispatch(hl.dsp.window.move({
                        window = "address:" .. window.address,
                        workspace = tostring(workspace.id),
                        follow = false,
                    }))
                end
                hl.dispatch(hl.dsp.focus({ window = "address:" .. window.address }))
                return
            end
        end
        if os.time() - launched < 2 then return end
        launched = os.time()
        hl.exec_cmd(command)
    end
end
open_network = settings_window("network-settings", "kitty --class network-settings -e nmtui")
open_audio = settings_window("audio-settings", "kitty --class audio-settings -e wiremix")
hl.bind("SUPER + W", open_network)

hl.bind("SUPER + B", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"))
hl.bind("SUPER + D", hl.dsp.exec_cmd(scripts .. "hypr-menu.sh apps"))
hl.bind("SUPER + G", hl.dsp.exec_cmd(scripts .. "hypr-largest.sh"))
hl.bind("SUPER + V", hl.dsp.exec_cmd(scripts .. "hypr-menu.sh clipboard"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind("SUPER + Y", hl.dsp.exec_cmd("$HOME/.scripts/move_and_open.sh"))
hl.bind("SUPER + X", hl.dsp.exec_cmd(scripts .. "hypr-menu.sh lock"))
hl.bind("SUPER + F", hl.dsp.window.fullscreen_state({ action = "toggle", internal = 2, client = 0 }))
hl.bind("SUPER + Escape", hl.dsp.exec_cmd(scripts .. "hypr-menu.sh session"))
hl.bind(
	"SUPER + SHIFT + Escape",
	toggle_app({
		name = "gotop",
		class = "gotop",
		command = "kitty --class gotop -e gotop",
		size = "1100 750",
	})
)
hl.bind(
	"SUPER + period",
	toggle_app({
		name = "chatgpt",
		class = "brave-chatgpt.com__-Profile_6",
		command = scripts .. "webapp.sh 'https://chatgpt.com'",
		size = "1200 850",
	})
)
hl.bind("ALT + Tab", hl.dsp.exec_cmd("snappy-switcher next --mod alt"))
--hl.bind("ALT + Tab", hl.dsp.window.cycle_next({ next = true }))
hl.bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))
hl.bind("SUPER + Tab", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + SHIFT + Tab", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
for _, direction in ipairs({ "left", "right", "up", "down" }) do
	hl.bind("SUPER + " .. direction, hl.dsp.focus({ direction = direction }))
	hl.bind("SUPER + SHIFT + " .. direction, hl.dsp.window.move({ direction = direction }))
end
-- Vim-style window movement: H left, J down, K up, L right.
for key, direction in pairs({ H = "left", J = "down", K = "up", L = "right" }) do
	hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }))
end
-- Vim-style focus: H left, J down, K up, L right.
for key, direction in pairs({ H = "left", J = "down", K = "up", L = "right" }) do
	hl.bind("SUPER + " .. key, hl.dsp.focus({ direction = direction }))
end
-- Resize the active window by 30 pixels; repeat while held.
for key, delta in pairs({
	H = { -30, 0 },
	left = { -30, 0 },
	J = { 0, 30 },
	down = { 0, 30 },
	K = { 0, -30 },
	up = { 0, -30 },
	L = { 30, 0 },
	right = { 30, 0 },
}) do
	hl.bind(
		"SUPER + ALT + " .. key,
		hl.dsp.window.resize({ x = delta[1], y = delta[2], relative = true }),
		{ repeating = true }
	)
end
-- Physical number-row keys also work with the Czech layout's accented letters.
for i = 1, 10 do
	local key = "code:" .. (i + 9)
	hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(scripts .. "hypr-brightness.sh up"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(scripts .. "hypr-brightness.sh down"), { repeating = true })
