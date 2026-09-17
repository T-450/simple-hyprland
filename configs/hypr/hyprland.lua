-- Simple Hyprland: minimal, hardware-neutral defaults for Hyprland 0.55+.
-- Add machine-specific changes to ~/.config/hypr/local.lua.

local terminal = "foot"
local file_manager = "thunar"
local browser = "brave"
local browser_fallback = "firefox"
local main_mod = "SUPER"

hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

hl.env("XCURSOR_SIZE", "22")
hl.env("HYPRCURSOR_SIZE", "22")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

hl.on("hyprland.start", function()
	local commands = {
		"systemctl --user start hyprpolkitagent.service",
		"uwsm app -- dunst",
		"uwsm app -- waybar",
		"uwsm app -- hyprpaper",
		"uwsm app -- hypridle",
		"uwsm app -- wl-paste --type text --watch cliphist store",
		"uwsm app -- wl-paste --type image --watch cliphist store",
	}

	for _, command in ipairs(commands) do
		hl.exec_cmd(command)
	end
end)

hl.config({
	general = {
		gaps_in = 0,
		gaps_out = 0,
		border_size = 2,
		col = {
			active_border = {
				colors = { "rgb(6688ff)", "rgb(b1a0f8)", "rgb(21edba)" },
				angle = 45,
			},
			inactive_border = "rgb(353535)",
		},
		resize_on_border = true,
		allow_tearing = false,
		layout = "master",
	},

	decoration = {
		rounding = 0,
		rounding_power = 2,
		active_opacity = 1.0,
		inactive_opacity = 0.94,
		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = 0xdd121212,
		},
		blur = {
			enabled = true,
			size = 3,
			passes = 2,
			vibrancy = 0.1696,
		},
	},

	animations = {
		enabled = true,
	},
	dwindle = {
		preserve_split = true,
	},
	master = {
		-- # Give the master/editor most of the screen
		mfact = 0.60,

		-- # New applications go into the slave stack
		new_status = "slave",

		-- # Put new windows after the currently focused window
		new_on_active = "after",

		-- # Don't force new windows to the top of the stack
		new_on_top = false,

		-- # Editor/master on the left, supporting windows on the right
		orientation = "left",

		-- # Easier mouse-based resizing
		smart_resizing = true,

		-- # Dropping a window puts it where you dropped it
		drop_at_cursor = true,

		-- # Keep the master in place when the stack becomes empty
		always_keep_position = false,

		-- # Keep focus on the window that becomes relevant after closing
		focus_master_on_close = false,
	},

	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		vrr = 0,
	},

	input = {
		kb_layout = "us",
		follow_mouse = 1,
		sensitivity = 0,
		touchpad = {
			natural_scroll = true,
		},
	},
})

hl.curve("snappy", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.curve("swift", { type = "bezier", points = { { 0.4, 0 }, { 0.2, 1 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 1.8, bezier = "snappy", style = "slide" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.8, bezier = "snappy", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "swift", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 1.5, bezier = "snappy", style = "slide" })
hl.animation({ leaf = "layers", enabled = true, speed = 1.5, bezier = "snappy", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 1, bezier = "swift" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.2, bezier = "swift" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "snappy", style = "slidefade 15%" })

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

hl.bind(main_mod .. " + Return", hl.dsp.exec_cmd("uwsm app -- " .. terminal))
local browser_command = "if command -v " .. browser .. " >/dev/null 2>&1; then exec uwsm app -- "
	.. browser
	.. "; else exec uwsm app -- "
	.. browser_fallback
	.. "; fi"

hl.bind(main_mod .. " + B", hl.dsp.exec_cmd(browser_command))
hl.bind(main_mod .. " + E", hl.dsp.exec_cmd("uwsm app -- " .. file_manager))
hl.bind(main_mod .. " + D", hl.dsp.exec_cmd("rofi -show drun"))
hl.bind(main_mod .. " + Q", hl.dsp.window.close())
hl.bind(main_mod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprshutdown"))
hl.bind(main_mod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(main_mod .. " + SHIFT + V", hl.dsp.layout("togglesplit"))
hl.bind("ALT + TAB", hl.dsp.window.cycle_next({ tiled = true }))

local direction_bindings = {
	{ key = "H", direction = "left" },
	{ key = "J", direction = "down" },
	{ key = "K", direction = "up" },
	{ key = "L", direction = "right" },
}

for _, binding in ipairs(direction_bindings) do
	local key = binding.key
	local direction = binding.direction
	hl.bind(main_mod .. " + " .. key, hl.dsp.focus({ direction = direction }))
	hl.bind(main_mod .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = direction }))
end

local resize_step = 40
local resize_bindings = {
	{ bind = "CTRL + ALT + bracketleft", x = -resize_step, y = 0 },
	{ bind = "CTRL + ALT + bracketright", x = resize_step, y = 0 },
	{ bind = "CTRL + ALT + minus", x = 0, y = -resize_step },
	{ bind = "CTRL + ALT + plus", x = 0, y = resize_step },
}

for _, binding in ipairs(resize_bindings) do
	hl.bind(
		binding.bind,
		hl.dsp.window.resize({ x = binding.x, y = binding.y, relative = true }),
		{ repeating = true }
	)
end

hl.bind(main_mod .. " + TAB", function()
	local layouts = { "master", "dwindle", "scrolling", "monocle" }
	local workspace = hl.get_active_special_workspace() or hl.get_active_workspace()
	if not workspace then
		return
	end

	local next_layout = layouts[1]
	for index, layout in ipairs(layouts) do
		if layout == workspace.tiled_layout then
			next_layout = layouts[(index % #layouts) + 1]
			break
		end
	end

	if not workspace.config_name then
		return
	end

	hl.workspace_rule({ workspace = workspace.config_name, layout = next_layout })
end)

for workspace = 1, 10 do
	local key = workspace % 10
	hl.bind(main_mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
	hl.bind(main_mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(main_mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(main_mod .. " + V", hl.dsp.exec_cmd("cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"))
hl.bind(main_mod .. " + P", hl.dsp.exec_cmd("hyprpicker | wl-copy"))
hl.bind(main_mod .. " + CTRL + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(main_mod .. " + ESCAPE", hl.dsp.exec_cmd("hyprshutdown"))
hl.bind("CTRL + ESCAPE", hl.dsp.exec_cmd("pkill waybar || uwsm app -- waybar"))

hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m output -m active --clipboard-only"))
hl.bind(main_mod .. " + Print", hl.dsp.exec_cmd("hyprshot -m window -m active --clipboard-only"))
hl.bind(main_mod .. " + SHIFT + Print", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"))

hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local local_config = config_home .. "/hypr/local.lua"
local local_file = io.open(local_config, "r")
if local_file then
	local_file:close()
	dofile(local_config)
end
