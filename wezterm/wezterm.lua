local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

-- config.font = wezterm.font("MesloLGS Nerd Font Mono")

config.font_size = 10
-- config.color_scheme = "Batman"

config.enable_tab_bar = false
-- config.window_decorations = "RESIZE"
config.window_decorations = "TITLE | RESIZE"

config.colors = {
	foreground = "#CBE0F0",
	background = "#011423",
	cursor_bg = "#47FF9C",
	cursor_fg = "#011423",
  cursor_border = "#47FF9C",
	selection_bg = "#033259",
	selection_fg = "#CBE0F0",
	ansi = { "#214969", "#E52E2E", "#44FFB1", "#FFE073", "#0FC5ED", "#a277ff", "#24EAF7", "#24EAF7" },
	brights = { "#214969", "#E52E2E", "#44FFB1", "#FFE073", "#A277FF", "#a277ff", "#24EAF7", "#24EAF7" },
}

config.window_background_opacity = 0.9
config.macos_window_background_blur = 10
config.show_tabs_in_tab_bar = true

config.use_dead_keys = false
config.use_ime = false
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = true
config.treat_left_ctrlalt_as_altgr = true

-- Event handler so Wezterm works with ZEN_MODE in NeoVim
wezterm.on("user-var-changed", function(window, pane, name, value)
	local overrides = window:get_config_overrides() or {}
	if name == "ZEN_MODE" then
		local incremental = value:find("+")
		local number_value = tonumber(value)
		if incremental ~= nil then
			while number_value > 0 do
				window:perform_action(wezterm.action.IncreaseFontSize, pane)
				number_value = number_value - 1
			end
			overrides.enable_tab_bar = false
    elseif number_value < 0 then
      window:perform_action(wezterm.action.ResetFontSize, pane)
      overrides.font_size = nil
      overrides.enable_tab_bar = true
		else
			overrides.font_size = number_value
			overrides.enable_tab_bar = false
		end
	end
	window:set_config_overrides(overrides)
end)

config.keys = {
	{
		key = "J",
		mods = "CTRL",
		action = act.ActivatePaneDirection("Down"),
	},
	{
		key = "K",
		mods = "CTRL",
		action = act.ActivatePaneDirection("Up"),
	},
	-- {
	-- 	{
	-- 		key = "raw:34",
	-- 		action = wezterm.action_callback(function(window, pane)
	-- 			local process_name = pane:get_foreground_process_name()
	-- 			if process_name and process_name:match("nvim") then
	-- 				window:perform_action(act.SendKey({ key = "[" }), pane)
	-- 			else
	-- 				window:perform_action(act.SendKey({ key = "å" }), pane)
	-- 			end
	-- 		end),
	-- 	},
	-- 	{
	-- 		key = "raw:34",
	-- 		mods = "ALT",
	-- 		action = wezterm.action_callback(function(window, pane)
	-- 			local process_name = pane:get_foreground_process_name()
	-- 			if process_name and process_name:match("nvim") then
	-- 				window:perform_action(act.SendKey({ key = "å" }), pane)
	-- 			else
	-- 				window:perform_action(act.SendKey({ key = "[" }), pane)
	-- 			end
	-- 		end),
	-- 	},
	-- },
	-- {
	-- 	key = "´",
	-- 	action = act.SendKey({
	-- 		key = "]",
	-- 	}),
	-- },
	-- {
	-- 	key = "raw:35",
	--    mods = "",
	-- 	action = wezterm.action_callback(function(window, pane)
	-- 		local process_name = pane:get_foreground_process_name()
	-- 		if process_name and process_name:match("nvim") then
	-- 			window:perform_action(act.SendKey({ key = "]" }), pane)
	-- 		end
	-- 	end),
	-- },
	-- {
	-- 	key = "raw:35",
	-- 	mods = "ALT_R",
	-- 	action = wezterm.action_callback(function(window, pane)
	-- 		local process_name = pane:get_foreground_process_name()
	-- 		if process_name and process_name:match("nvim") then
	-- 			window:perform_action(act.SendKey({ key = "´" }), pane)
	-- 		end
	-- 	end),
	-- },
	-- {
	-- 	key = "å",
	-- 	mods = "ALT",
	-- 	action = act.SendKey({
	-- 		key = "[",
	-- 	}),
	-- },
	-- {
	-- 	key = "raw:35",
	-- 	mods = "",
	-- 	action = wezterm.action_callback(function(window, pane)
	-- 		local process_name = pane:get_foreground_process_name()
	-- 		if process_name and process_name:match("nvim") then
	-- 			window:perform_action(act.SendKey({ key = "]" }), pane)
	-- 		end
	-- 	end),
	-- },
}

local launch_menu = {}

if wezterm.target_triple == "x86_64-pc-windows-msvc" then
    table.insert(launch_menu, {
        label = "PowerShell",
        args = { "pwsh.exe", "-nol" },
      })
    table.insert(launch_menu, {
        label = "MSYS UCRT64",
        args = { "cmd.exe ", "/k", "C:\\msys64\\msys2_shell.cmd -defterm -here -no-start -ucrt64 -shell bash" },
      })
    config.default_prog = { "pwsh", "-nol" }
end

config.launch_menu = launch_menu

-- The filled in variant of the < symbol
local SOLID_LEFT_ARROW = wezterm.nerdfonts.pl_right_hard_divider

-- The filled in variant of the > symbol
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.pl_left_hard_divider

config.tab_bar_style = {
	-- active_tab_left = wezterm.format {
	--   { Background = { Color = '#0b0022' } },
	--   { Foreground = { Color = '#2b2042' } },
	--   { Text = SOLID_LEFT_ARROW },
	-- },
	-- active_tab_right = wezterm.format {
	--   { Background = { Color = '#0b0022' } },
	--   { Foreground = { Color = '#2b2042' } },
	--   { Text = SOLID_RIGHT_ARROW },
	-- },
	-- inactive_tab_left = wezterm.format {
	--   { Background = { Color = '#0b0022' } },
	--   { Foreground = { Color = '#1b1032' } },
	--   { Text = SOLID_LEFT_ARROW },
	-- },
	-- inactive_tab_right = wezterm.format {
	--   { Background = { Color = '#0b0022' } },
	--   { Foreground = { Color = '#1b1032' } },
	--   { Text = SOLID_RIGHT_ARROW },
	-- },
}

--[[ config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

config.keys = {
  {
    key = '|',
    mods = 'LEADER|SHIFT',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = '-',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
} ]]

-- config.front_end = "WebGpu"
-- config.front_end = "OpenGL"
-- config.front_end = "Software"

return config
