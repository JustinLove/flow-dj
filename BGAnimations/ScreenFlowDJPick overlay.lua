local pn = GAMESTATE:GetEnabledPlayers()[1]
local stepstype = GAMESTATE:GetCurrentStyle(pn):GetStepsType()
local profile = PROFILEMAN:GetMachineProfile()
local stages = 16

local graph = false
local left_text = false
local right_text = false
local timer_actor = false
local function get_screen_time()
	if timer_actor then
		return timer_actor:GetSecsIntoEffect()
	else
		return 0
	end
end

local entering_song = false

lua.ReportScriptError('----------------' .. math.random())

FlowDJ.enabled = true

FlowDJ.stage = GAMESTATE:GetCurrentStageIndex()
if FlowDJ.stage == 0 then
	FlowDJ.offset = math.random(0,math.pi)
	FlowDJ.scale = math.random(1,3)
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

local function GraphData(data)
	graph:Clear()
	graph:AddPoint(0, 0, Color.Black)
	local max = 0
	for i,item in ipairs(data) do
		max = math.max(max, item)
	end
	for i,item in ipairs(data) do
		graph:AddPoint(i/#data, item/max, Color.White)
	end
end

local function GraphWeight(weighted)
	graph:Clear()
	graph:AddPoint(0, 0, Color.Black)
	for i,item in ipairs(weighted) do
		graph:AddPoint(item.count / 30, item.weight, Color.White)
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
	graph:Clear()
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
			graph:AddPoint(nps/10, rating/20, color)
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

local function NormalizeFactors(steps)
	local range = {}
	local avg = {}
	for key,value in pairs(steps[1].factors) do
		local min = steps[1].factors[key]
		local max = steps[1].factors[key]
		for i,sel in ipairs(steps) do
			min = math.min(min, sel.factors[key])
			max = math.max(max, sel.factors[key])
		end
		range[key] = (max - min) + 1
		avg[key] = min + range[key]/2
	end

	for i,sel in ipairs(steps) do
		for key,value in pairs(sel.factors) do
			if key ~= 'c' then
				sel.factors[key] = (sel.factors[key] - avg[key]) / range[key]
			end
		end
		--rec_print_table(sel.factors)
	end
end

local initial_theta = {
	c = 0,
	meter = 0,
	meter2 = 0,
	nps = 0,
	nps2 = 0,
}

local function AddFactors(steps)
	for i,sel in ipairs(steps) do
		sel.factors = {
			c = 1,
			meter = sel.meter,
			meter2 = sel.meter * sel.meter,
			nps = sel.nps,
			nps2 = sel.nps * sel.nps,
		}
	end
	NormalizeFactors(steps)
end

local function ComputeCost(steps, theta)
	local cost = 0
	for p,sel in ipairs(steps) do
		local prediction = 0
		for key,value in pairs(theta) do
			prediction = prediction + value * sel.factors[key]
		end
		cost = cost + (prediction - sel.score) ^ 2
	end
	cost = cost / (2*#steps)
	--lua.ReportScriptError(cost)
	return cost
end

local function GradientDescent(steps, theta)
	local alpha = 0.03
	local cost_history = {}
	for i = 1,100 do
		local dtheta = {}
		for key,value in pairs(theta) do
			dtheta[key] = 0
		end
		for s,sel in ipairs(steps) do
			local prediction = 0
			for key,value in pairs(theta) do
				prediction = prediction + value * sel.factors[key]
			end
			local error = prediction - sel.score
			for key,value in pairs(dtheta) do
				dtheta[key] = dtheta[key] + error * sel.factors[key]
			end
		end
		for key,value in pairs(theta) do
			theta[key] = theta[key] - alpha * (dtheta[key] / #steps)
		end
		cost_history[i] = ComputeCost(steps, theta)
	end
	return theta, cost_history
end

local function GraphPredictions(steps, theta)
	graph:Clear()
	graph:AddPoint(0, 0, Color.Black)
	for p,sel in ipairs(steps) do
		local prediction = 0
		for key,value in pairs(theta) do
			prediction = prediction + value * sel.factors[key]
		end
		graph:AddPoint(sel.score, prediction, Color.White)
	end
end

local function PredictScore()
	local possible = PossibleSteps()
	AddFactors(possible)
	local training = {}
	for p,sel in ipairs(possible) do
		if sel.score ~= 0 then
			table.insert(training, sel)
		end
	end
	ComputeCost(training, initial_theta)
	local theta,history = GradientDescent(training, initial_theta)
	ComputeCost(training, theta)
	GraphPredictions(possible, theta)
	--GraphData(history)
	right_text:settext(rec_print_table_to_str(theta) .. "\n" .. history[#history])
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
		flow[i] = target + (math.sin(FlowDJ.scale*i + FlowDJ.offset) * scale)
	end
	return flow
end

local function SetupNextGame()
	local flow = WiggleFlow(ManualFlow(2, 7.7), 1)
	local selections = PickByMeter(flow)
	local sel = selections[FlowDJ.stage]
	if sel then
		GAMESTATE:SetCurrentSong(sel.song)
		GAMESTATE:SetCurrentSteps(pn, sel.steps)
		entering_song = get_screen_time() + 1.5
	else
		trans_new_screen("ScreenTitleMenu")
	end
end

local frame = 0
local function update()
	if entering_song then
		if get_screen_time() > entering_song then
			trans_new_screen("ScreenGameplay")
			--trans_new_screen("ScreenFlowDJBounce")
		end
	end
	frame = frame + 1
	if frame == 2 then
		--GraphSteps()
		local flow = WiggleFlow(ManualFlow(2, 7.7), 1)
		--GraphData(flow)
		local selections = PickByMeter(flow)
		--right_text:settext(SelectionsDebug(selections))
		left_text:settext(SongsDebug(RecentSongs()))
		--SetupNextGame()
		PredictScore()
	end
end

local function input(event)
	if WaitForStart(event) then
		if entering_song then
			trans_new_screen("ScreenPlayerOptions")
		else
			SetupNextGame()
		end
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
			local scale = math.min(SCREEN_WIDTH - 40, SCREEN_HEIGHT - 50)
			self:zoom(scale)

			self.AddPoint = function(self, x, y, color)
				local data = self:GetChild("data")
				data:AddChildFromPath(THEME:GetPathG("", "point.lua"))
				local points = data:GetChild("point")
				if points and #points > 0 then
					points[#points]:xy(x, 1 - y):diffuse(color)
				end
				--self:GetChild("background"):xy(0.5, 0.5):diffuse(color)
			end

			self.Clear = function(self)
				self:GetChild("data"):RemoveAllChildren()
			end
		end,
		Def.ActorFrame{
			Def.Quad{
				Name= "backdrop", InitCommand = cmd(setsize, 1, 1; xy, 0.5, 0.5),
				OnCommand = cmd(diffuse, Alpha(Color.Black, 0.5))
			},
			Name= "background", InitCommand= cmd(visible, true),
		},
		Def.ActorFrame{
			Name= "data", InitCommand= cmd(visible, true),
		},
	},
	Def.Actor{
		Name= "timer",
		InitCommand= function(self)
			self:effectperiod(2^16)
			timer_actor= self
		end,
	},
}
