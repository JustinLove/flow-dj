local pn = GAMESTATE:GetEnabledPlayers()[1]
local stepstype = GAMESTATE:GetCurrentStyle(pn):GetStepsType()
local profile = PROFILEMAN:GetMachineProfile()
local stages = 16

lua.ReportScriptError('----------------' .. math.random())

setenv("FlowDJ", true)

local function SongDebug(song)
	return song:GetDisplayMainTitle() ..  " " ..
		song:GetDisplayBpms()[1] .. "-" ..
		song:GetDisplayBpms()[2] .. " " ..
		PROFILEMAN:GetSongNumTimesPlayed(song, 'ProfileSlot_Machine')
end

local function SongsDebug(songs)
	local debug = {}
	for i,song in ipairs(songs) do
		debug[i] = SongDebug(song)
	end
	return table.concat(debug, "\n")
end

local function StepsDebug(steps)
	local debug = {}
	for i,step in ipairs(steps) do
		debug[i] = SongDebug(SONGMAN:GetSongFromSteps(step))
	end
	return table.concat(debug, "\n")
end

local function SelectionsDebug(selections)
	local debug = {}
	for i,item in ipairs(selections) do
		debug[i] = SongDebug(item.song)
	end
	return table.concat(debug, "\n")
end

local function RecentSongs()
	local recent = {}
	for i = 1,STATSMAN:GetStagesPlayed() do
		local stats = STATSMAN:GetPlayedStageStats(i)
		local songs = stats:GetPlayedSongs()
		recent[i] = songs[1]
	end
	return recent
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
local left_text = false
local right_text = false

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
					best = (best - 0.6) * 5.0
					color = HSV(best * 120, 1, 1)
				end
			end
			graph:AddPoint(nps, rating, color)
			max_nps = math.max(max_nps, nps)
		end
	end
	nps_text:settext(max_nps)
end

local function BucketByMeter()
	local all_songs = RemoveUnwantedGroups(SONGMAN:GetAllSongs())
	local meters = {}
	for g, song in ipairs(all_songs) do
		local song_steps = song:GetStepsByStepsType(stepstype)
		local song_length = song:GetLastSecond() - song:GetFirstSecond()
		for t, steps in ipairs(song_steps) do
			--lua.ReportScriptError(steps:PredictMeter())
			local rating = steps:GetMeter()
			if not meters[rating] then
				meters[rating] = {}
			end
			table.insert(meters[rating], {
				steps = steps,
				song = song,
			})
		end
	end
	return meters
end

local function PickByMeter(flow)
	local meters = BucketByMeter()
	local selections = {}
	local picked = {}
	local recent = RecentSongs()
	for i,song in ipairs(recent) do
		picked[song:GetSongFilePath()] = true
	end
	for i,target in ipairs(flow) do
		for j,sel in ipairs(meters[math.floor(target)]) do
			local path = sel.song:GetSongFilePath()
			if not picked[path] then
				selections[i] = sel
				picked[path] = true
				break
			end
		end
		if not selections[i] then
			lua.ReportScriptError("missing " .. target)
		end
	end
	return selections
end

local function GraphFlow(flow)
	graph:RemoveAllChildren()
	graph:AddPoint(0, 0, Color.Black)
	for stage,target in ipairs(flow) do
		graph:AddPoint(stage, math.floor(target), Color.White)
	end
end

local function LinearFlow()
	local flow = {}
	for stage = 1,stages do
		flow[stage] = stage
	end
	return flow
end

local function BezierFlow()
	local flow = {}
	local p0 = 3
	local p1 = 10
	local p2 = 10
	local p3 = 3
	for stage = 1,stages do
		local t = stage/stages
		local it = 1 - t
		local meter = it*it*it*p0 + 3*it*it*t*p1 + 3*it*t*t*p2 + t*t*t*p3
		lua.ReportScriptError(meter)
		flow[stage] = meter
	end
	return flow
end

local function ManualFlow()
	local flow = {}
	local edges = math.floor(stages / 5)
	for stage = 1,edges do
		flow[stage] = stage * 2
		flow[stages+1-stage] = stage * 2
	end
	for stage = edges+1,stages-edges do
		flow[stage] = 7
	end
	return flow
end

local function WiggleFlow(flow)
	local offset = math.random(0,math.pi)
	local scale = math.random(1,3)
	for i,target in ipairs(flow) do
		flow[i] = target + math.sin(scale*i + offset)
	end
	return flow
end

local function SetupNextGame()
	local current_stage = (getenv("FlowDJStage") or 0) + 1
	setenv("FlowDJStage", current_stage)
	--local current_stage = GAMESTATE:GetCurrentStageIndex()+1
	local flow = WiggleFlow(ManualFlow())
	local selections = PickByMeter(flow)
	local sel = selections[current_stage]
	if sel then
		GAMESTATE:SetCurrentSong(sel.song)
		GAMESTATE:SetCurrentSteps(pn, sel.steps)
		--trans_new_screen("ScreenGameplay")
		trans_new_screen("ScreenFlowDJBounce")
	else
		trans_new_screen("ScreenTitleMenu")
	end
end

local frame = 0
local function update()
	--SetupNextGame()
	frame = frame + 1
	if frame == 2 then
		--GraphSteps()
		local flow = WiggleFlow(ManualFlow())
		GraphFlow(flow)
		local selections = PickByMeter(flow)
		left_text:settext(SelectionsDebug(selections))
		right_text:settext(SongsDebug(RecentSongs()))
	end
end

local function input(event)
	if WaitForStart(event) then
		SetupNextGame()
	end
end

return Def.ActorFrame{
	Def.ActorFrame{
		Name = "Picker", OnCommand = function(self)
			self:SetUpdateFunction(update)
			SCREENMAN:GetTopScreen():AddInputCallback(input)
		end,
	},
	Def.BitmapText{
		Name = "Left", Font = "Common Normal", InitCommand = function(self)
			left_text = self
			self:maxwidth(SCREEN_HEIGHT)
			self:zoom(0.5)
			self:xy(_screen.cx - SCREEN_WIDTH/4, _screen.cy)
		end
	},
	Def.BitmapText{
		Name = "Right", Font = "Common Normal", InitCommand = function(self)
			right_text = self
			self:maxwidth(SCREEN_HEIGHT)
			self:zoom(0.5)
			self:xy(_screen.cx + SCREEN_WIDTH/4, _screen.cy)
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
		Name = "graph", InitCommand = function(self)
			graph = self
			self:xy(20, 20)
			self:SetWidth(SCREEN_WIDTH - 40)
			self:SetHeight(SCREEN_HEIGHT - 40)

			self.AddPoint = function(self, x, y, color)
				self:AddChildFromPath(THEME:GetPathG("", "point.lua"))
				local points = self:GetChild("point")
				if points and #points > 0 then
					points[#points]:xy(x * 40, self:GetHeight() - y * 25):diffuse(color)
				end
			end
		end,
	}
}
