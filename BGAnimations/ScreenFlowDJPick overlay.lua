local pn = GAMESTATE:GetEnabledPlayers()[1]
local stepstype = GAMESTATE:GetCurrentStyle(pn):GetStepsType()
local profile = PROFILEMAN:GetMachineProfile()
local stages = 16

local graph = false
local left_text = false
local right_text = false

lua.ReportScriptError('----------------' .. math.random())

flow_dj_enabled = true

if flow_dj_stage == 0 then
	flow_dj_offset = math.random(0,math.pi)
	flow_dj_scale = math.random(1,3)
end

local function SongDebug(song)
	return string.format("%40s %d-%d #%d",
	  song:GetDisplayMainTitle(),
		song:GetDisplayBpms()[1],
		song:GetDisplayBpms()[2],
		PROFILEMAN:GetSongNumTimesPlayed(song, 'ProfileSlot_Machine'))
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

local function SelectionDebug(sel)
	return string.format("%s m%d %0.1fnps %0.2f",
		SongDebug(sel.song),
		sel.meter,
		sel.nps,
		sel.score)
end

local function SelectionsDebug(selections)
	local debug = {}
	for i,item in ipairs(selections) do
		debug[i] = SelectionDebug(item)
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

local function SortByPlayCount(songs)
	table.sort(songs, function(a, b) return PROFILEMAN:GetSongNumTimesPlayed(a, 'ProfileSlot_Machine') < PROFILEMAN:GetSongNumTimesPlayed(b, 'ProfileSlot_Machine') end )
	return songs
end

local function GraphWeight(weighted)
	graph:RemoveAllChildren()
	graph:AddPoint(0, 0, Color.Black)
	for i,item in ipairs(weighted) do
		graph:AddPoint(item.count / 3, item.weight * 30, Color.White)
	end
end

local function WeightByPlayCount(songs)
	local weighted = {}
	local most = 0
	for i,song in ipairs(songs) do
		local count = PROFILEMAN:GetSongNumTimesPlayed(song, 'ProfileSlot_Machine')
		most = math.max(most, count)
		weighted[i] = {
			song = song,
			title = song:GetDisplayMainTitle(),
			count = count
		}
	end
	most = (most / 2) + 1
	local total = 0
	for i,item in ipairs(weighted) do
		weighted[i].weight = math.random() * (weighted[i].count + 1) / (weighted[i].count + most)
	end
	table.sort(weighted, function(a, b) return a.weight < b.weight end )
	--GraphWeight(weighted)
	local sorted = {}
	for i,item in ipairs(weighted) do
		sorted[i] = weighted[i].song
	end
	return sorted
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

local function GetScore(song, steps)
	local high_score_list = profile:GetHighScoreListIfExists(song, steps)
	if high_score_list then
		local score = high_score_list:GetHighestScoreOfName("EVNT")
		if score then
			return score:GetPercentDP()
		end
	end

	return 0
end

local function PossibleSteps()
	local all_songs = WeightByPlayCount(RemoveUnwantedGroups(SONGMAN:GetAllSongs()))
	local possible = {}
	for g, song in ipairs(all_songs) do
		local song_steps = song:GetStepsByStepsType(stepstype)
		local song_length = song:GetLastSecond() - song:GetFirstSecond()
		for t, steps in ipairs(song_steps) do
			--lua.ReportScriptError(steps:PredictMeter())
			table.insert(possible, {
				steps = steps,
				song = song,
				nps = calc_nps(pn, song_length, steps),
				meter = steps:GetMeter(),
				score = GetScore(song, steps),
			})
		end
	end
	return possible
end

local function PickByMeter(flow)
	local possible = PossibleSteps()
	local selections = {}
	local picked = {}
	local recent = RecentSongs()
	for i,song in ipairs(recent) do
		picked[song:GetSongFilePath()] = true
	end
	for i,target in ipairs(flow) do
		local meter = math.floor(target)
		for j,sel in ipairs(possible) do
			local path = sel.song:GetSongFilePath()
			if sel.meter == meter and not picked[path] then
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

local function GraphFlow(flow, scale)
	graph:RemoveAllChildren()
	graph:AddPoint(0, 0, Color.Black)
	for stage,target in ipairs(flow) do
		graph:AddPoint(stage, target*scale, Color.White)
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

local function ManualFlow(start, middle)
	local flow = {}
	local edges = math.floor(stages / 5)
	for stage = 1,edges do
		flow[stage] = start + (((stage-1) / edges) * (middle - start))
		flow[stages+1-stage] = start + ((stage-1) / edges) * (middle - start)
	end
	for stage = edges+1,stages-edges do
		flow[stage] = middle
	end
	return flow
end

local function WiggleFlow(flow, scale)
	for i,target in ipairs(flow) do
		flow[i] = target + (math.sin(flow_dj_scale*i + flow_dj_offset) * scale)
	end
	return flow
end

local function SetupNextGame()
	flow_dj_stage = flow_dj_stage + 1
	--local current_stage = flow_dj_stage
	local current_stage = GAMESTATE:GetCurrentStageIndex()+1
	local flow = WiggleFlow(ManualFlow(2, 7.7), 1)
	local selections = PickByMeter(flow)
	local sel = selections[current_stage]
	if sel then
		GAMESTATE:SetCurrentSong(sel.song)
		GAMESTATE:SetCurrentSteps(pn, sel.steps)
		trans_new_screen("ScreenGameplay")
		--trans_new_screen("ScreenFlowDJBounce")
	else
		trans_new_screen("ScreenTitleMenu")
	end
end

local frame = 0
local function update()
	frame = frame + 1
	if frame == 2 then
		--GraphSteps()
		local flow = WiggleFlow(ManualFlow(2, 7.7), 1)
		GraphFlow(flow, 1)
		local selections = PickByMeter(flow)
		right_text:settext(SelectionsDebug(selections))
		left_text:settext(SongsDebug(RecentSongs()))
		SetupNextGame()
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
