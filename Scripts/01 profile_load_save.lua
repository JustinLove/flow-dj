-- Having single LoadProfileCustom and SaveProfileCustom functions doesn't
-- extend very well when you have a bunch of custom things to save to the
-- profile and you just want to create callback functions for handling
-- loading/saving.
-- So this is a system for adding to a list of custom load/save functions.
-- -Kyz

if profile_load_callbacks then
	return
end

local profile_load_callbacks= {}
local profile_save_callbacks= {}

function add_profile_load_callback(func)
	table.insert(profile_load_callbacks, func)
end
function add_profile_save_callback(func)
	table.insert(profile_save_callbacks, func)
end

local PreviousLoadProfileCustom = LoadProfileCustom
function LoadProfileCustom(profile, dir, pn)
	--lua.ReportScriptError("LoadProfileCustom" .. dir .. (pn or ''))
	for i, callback in ipairs(profile_load_callbacks) do
		callback(profile, dir, pn)
	end
	if PreviousLoadProfileCustom then
		PreviousLoadProfileCustom(profile, dir, pn)
	end
end
local PreviousSaveProfileCustom = SaveProfileCustom
function SaveProfileCustom(profile, dir, pn)
	--lua.ReportScriptError("SaveProfileCustom" .. dir .. (pn or ''))
	for i, callback in ipairs(profile_save_callbacks) do
		callback(profile, dir, pn)
	end
	if PreviousSaveProfileCustom then
		PreviousSaveProfileCustom(profile, dir, pn)
	end
end

-- It's kinda like loading and saving profiles....
local gamestate_reset_callbacks= {}
function add_gamestate_reset_callback(func)
	table.insert(gamestate_reset_callbacks, func)
end

function GameStateResetCustom()
	--lua.ReportScriptError("GameStateResetCustom")
	for i, callback in ipairs(gamestate_reset_callbacks) do
		callback()
	end
end
