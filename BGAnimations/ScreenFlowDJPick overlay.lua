local pn = GAMESTATE:GetEnabledPlayers()[1]
local stepstype = GAMESTATE:GetCurrentStyle(pn):GetStepsType()

setenv("FlowDJ", true)

local function SongDebug(song)
	return song:GetDisplayMainTitle() ..  " " ..
		song:GetDisplayBpms()[1] .. "-" ..
		song:GetDisplayBpms()[2]
end

local function SongsDebug(songs)
	local debug = {}
	for i,song in ipairs(songs) do
		debug[i] = SongDebug(song)
	end
	return table.concat(debug, "\n")
end

local function Truncate(table, to)
	local truncated = {}
	local length = math.min(to, #table)
	for i=1,length do
		truncated[i] = table[i]
	end
	return truncated
end

local function RemoveUnwantedGroups(songs)
	local filtered_songs = {}
	for i,song in ipairs(songs) do
		if song:GetGroupName() ~= "Muted" and song:GetGroupName() ~= "Impossible" then
			table.insert(filtered_songs, song)
		end
	end
	return filtered_songs
end

local debug_text = false

local function SetupNextGame()
	local all_songs = RemoveUnwantedGroups(SONGMAN:GetAllSongs())
	local song = all_songs[1]
	debug_text:settext(SongsDebug(Truncate(all_songs, 16)))
	local song_steps = song:GetStepsByStepsType(stepstype)
	local steps = song_steps[1]
	GAMESTATE:SetCurrentSong(song)
	GAMESTATE:SetCurrentSteps(pn, steps)
end

local runonce = false
local function update()
	SetupNextGame()
	--trans_new_screen("ScreenGameplay")
	if not runonce then
		runonce = true
		--SetupNextGame()
		--debug_text:settext(tries)
	end
end

return Def.ActorFrame{
	Def.ActorFrame{
		Name = "Picker", OnCommand = function(self)
			self:SetUpdateFunction(update)
		end,
		Def.BitmapText{
			Name = "Notice", Font = "Common Normal", InitCommand = function(self)
				debug_text = self
				self:maxwidth(SCREEN_HEIGHT)
				self:zoom(0.5)
				self:xy(_screen.cx, _screen.cy)
			end
		}
	}
}
