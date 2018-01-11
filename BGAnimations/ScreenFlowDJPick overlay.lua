local pn = GAMESTATE:GetEnabledPlayers()[1]
local stepstype = GAMESTATE:GetCurrentStyle(pn):GetStepsType()
local profile = PROFILEMAN:GetMachineProfile()

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

function calc_nps(pn, song_len, steps)
	local radar= steps:GetRadarValues(pn)
	local notes= radar:GetValue("RadarCategory_TapsAndHolds") +
		radar:GetValue("RadarCategory_Jumps") +
		radar:GetValue("RadarCategory_Hands")
	return notes / song_len
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

local graph = false
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

local function AddPoint(x, y, color)
	graph:AddChildFromPath(THEME:GetPathG("", "point.lua"))
	local points = graph:GetChild("point")
	if points and #points > 0 then
		points[#points]:xy(20 + x * 90, SCREEN_HEIGHT - 20 - y * 25):diffuse(color)
	end
end

local function GraphSteps()
	graph:RemoveAllChildren()
	local max_nps = 0
	local all_songs = RemoveUnwantedGroups(SONGMAN:GetAllSongs())
	for g, song in ipairs(all_songs) do
		local song_steps = song:GetStepsByStepsType(stepstype)
		local song_length = song:GetLastSecond() - song:GetFirstSecond()
		for t, steps in ipairs(song_steps) do
			--lua.ReportScriptError(steps:PredictMeter())
			local rating = steps:GetMeter()
			local nps = calc_nps(pn, song_length, steps)
			local high_score_list = profile:GetHighScoreListIfExists(song, steps)
			local color = Color.Black
			if high_score_list then
				color = Color.White
				local score = high_score_list:GetHighestScoreOfName("EVNT")
				if score then
					local best = score:GetPercentDP()
					best = (best - 0.6) * 3.0
					color = HSV(best * 120, 1, 1)
				end
			end
			AddPoint(nps, rating, color)
			max_nps = math.max(max_nps, nps)
		end
	end
	nps_text:settext(max_nps)
end

local frame = 0
local function update()
	--SetupNextGame()
	--trans_new_screen("ScreenGameplay")
	if frame == 1 then
		GraphSteps()
	end
	frame = frame + 1
end

return Def.ActorFrame{
	Def.ActorFrame{
		Name = "Picker", OnCommand = function(self)
			self:SetUpdateFunction(update)
		end,
	},
	Def.BitmapText{
		Name = "Notice", Font = "Common Normal", InitCommand = function(self)
			debug_text = self
			self:maxwidth(SCREEN_HEIGHT)
			self:zoom(0.5)
			self:xy(_screen.cx, _screen.cy)
		end
	},
	Def.BitmapText{
		Name = "NPS", Font = "Common Normal", InitCommand = function(self)
			nps_text = self
			self:maxwidth(SCREEN_HEIGHT)
			self:xy(SCREEN_WIDTH - 50, SCREEN_HEIGHT - 50)
		end
	},
	Def.ActorFrame{
		Name= "graph", InitCommand= function(self)
			graph = self
		end
	}
}
