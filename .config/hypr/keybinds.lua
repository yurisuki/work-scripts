-- Starter bindings; the final keymap is intentionally a separate follow-up.
local scripts = os.getenv("HOME") .. "/.scripts/"
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd(scripts .. "hypr-menu.sh browser"))
hl.bind("SUPER + W", hl.dsp.exec_cmd("nm-connection-editor"))
hl.bind("SUPER + D", hl.dsp.exec_cmd(scripts .. "hypr-menu.sh apps"))
hl.bind("SUPER + V", hl.dsp.exec_cmd(scripts .. "hypr-menu.sh clipboard"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind("SUPER + L", hl.dsp.exec_cmd(scripts .. "hypr-menu.sh lock"))
hl.bind("SUPER + Escape", hl.dsp.exec_cmd(scripts .. "hypr-menu.sh session"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
for _, direction in ipairs({ "left", "right", "up", "down" }) do
    hl.bind("SUPER + " .. direction, hl.dsp.focus({ direction = direction }))
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
