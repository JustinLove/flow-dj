## Todo

- make branches behave better when stacked
- separate saved settings to separate stackable theme
- bug? current song selecting by estimated rather than acutal
- try with different themes?
- profiles?
  - what happens with no data?
    - help text for bootstrap mode
  - multiple players?
    - prefs for multiple players?
- more selection factors ?
- actual score reaction ?
- More config?

## General

ctrl+F2 to reload scripts
F3 - debug overlay
SCREENMAN:SystemMessage("") - transient, top of screen
Trace("")
lua.ReportScriptError("")
rec_print_table()

https://dguzek.github.io/Lua-For-SM5/

consensual has persistent mods


## Solved

Branch in scripts controls most transitions
Can overwrite members of Branch
Can overwrite global functions
Gamecommands do not see my custom functions and overrides
Gamecommand setenv does not seem to work
Global variables defined in Scripts will persist, variables in BGAanimations will not
No apparant way to add new PlayMode

ScreenSelectPlayMode has screen transitions in each option
ScreenSelectPlayMode acccepts custom options
ScreenSelectPlayMode needs additional config for highlight graphics - see error messages
SelectMusicOrCourse - entry point when returning
drunken uses a extra pick screen to do selection logic, probably needed for select play mode transitions to skip select music

Button text at bottom of screen is HelpText in language files for that screen

Some objects are not available at actor init, must wait until oncommand
Def.Actor\* does not return the actual actor, it is not available until provided in self later






		Def.ActorFrame{
			Name= "line frame", InitCommand= cmd(visible, true),
			Def.ActorMultiVertex{
				Name= "line", InitCommand = function(self)
					graph_line = self
					graph_line:SetDrawState({Mode="DrawMode_LineStrip"})
					graph_line:SetLineWidth(2)
					graph_line:SetVertices(i, {
							{{sel.nps/10, 1-score, 0}, Alpha(Color.White, i/10)},
						})
					graph_line:SetNumVertices(#selections)
				end,
				OnCommand = cmd(diffuse, Color.White)
			},
		},




local DetermineThemePath = function()
	local theme = THEME:GetCurThemeName()
	--lua.ReportScriptError(theme)

	local themePath = {theme}

	while theme ~= "_fallback" and theme ~= nil do
		local metrics = IniFile.ReadFile("Themes/" .. theme .. "/metrics.ini")
		--lua.ReportScriptError(rec_print_table_to_str(metrics))
		if metrics and metrics.Global then
			theme = metrics.Global.FallbackTheme
			if theme then
				themePath[#themePath+1] = theme
			end
		else
			theme = nil
		end
	end

	return themePath
end

--DetermineThemePath()

