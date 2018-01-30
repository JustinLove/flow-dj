local stages = 16
local auto_start = false
local play_screen = "ScreenGameplay"
--local play_screen = "ScreenFlowDJBounce"

local pn = GAMESTATE:GetEnabledPlayers()[1]
local stepstype = GAMESTATE:GetCurrentStyle(pn):GetStepsType()
local profile = PROFILEMAN:GetMachineProfile()

local graph = false
local cost_quad = false
local center_text = false
local left_text = false
local right_text = false

local entering_song = false

lua.ReportScriptError('----------------' .. math.random())

FlowDJ.enabled = true

FlowDJ.stage = GAMESTATE:GetCurrentStageIndex()
if FlowDJ.stage == 0 then
	FlowDJ.offset = math.random(0,math.pi)
	FlowDJ.scale = math.random(1,3)
end

local function CopyTable(from)
	local to = {}
	for key,value in pairs(from) do
		to[key] = value
	end
	return to
end

local function GraphPredictions(steps, theta, color)
	for p,sel in ipairs(steps) do
		local prediction = 0
		for key,value in pairs(theta) do
			prediction = prediction + value * sel.factors[key]
		end
		graph:SetPoint(p, sel.score, prediction, color)
	end
end

local function PredictedScore(sel, theta)
	local prediction = 0
	for key,value in pairs(theta) do
		prediction = prediction + value * sel.factors[key]
	end
	return prediction
end

local function AssignScore(steps, theta)
	for p,sel in ipairs(steps) do
		if sel.score == 0.0 then
			local prediction = 0
			for key,value in pairs(theta) do
				prediction = prediction + value * sel.factors[key]
			end
			sel.effective_score = prediction
		else
			sel.effective_score = sel.score
		end
	end
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
	local score = sel.score
	if score == 0.0 then
		score = PredictedScore(sel, FlowDJ.theta)
	end
	return string.format("%s m%d %0.1fnps %0.2f",
		SongDebug(sel.song),
		sel.meter,
		sel.nps,
		score)
end

local function DisplayNextSong(sel)
	local score = sel.score
	if score == 0.0 then
		score = PredictedScore(sel, FlowDJ.theta)
	end
	return string.format("%s #%d\n%d-%d %0.1fnps\nm%d %0.2f",
		sel.song:GetDisplayMainTitle(),
		PROFILEMAN:GetSongNumTimesPlayed(sel.song, 'ProfileSlot_Machine'),
		sel.song:GetDisplayBpms()[1],
		sel.song:GetDisplayBpms()[2],
		sel.nps,
		sel.meter,
		score)
end

local function SelectionsDebug(selections)
	local debug = {}
	for i,item in ipairs(selections) do
		debug[i] = SelectionDebug(item)
	end
	return table.concat(debug, "\n")
end

local function ThetaDebug(theta)
	local names = {}
	for key,value in pairs(theta) do
		table.insert(names, key)
	end
	table.sort(names)

	local debug = {}
	for i,key in ipairs(names) do
		debug[i] = string.format("%40s %f", key, theta[key])
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

local function RecentSteps()
	local recent = {}
	for i = 1,STATSMAN:GetStagesPlayed() do
		local stats = STATSMAN:GetPlayedStageStats(i)
		local playerstats = stats:GetPlayerStageStats(pn)
		local steps = playerstats:GetPlayedSteps()
		recent[i] = steps[1]
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

function CountRadarUsage(steps)
	local counts = {}
	for c,category in ipairs(RadarCategory) do
		counts[category] = 0
	end
	for s,sel in ipairs(steps) do
		local radar = sel.steps:GetRadarValues(pn)
		for c,category in ipairs(RadarCategory) do
			if radar:GetValue(category) ~= 0 then
				counts[category] = counts[category] + 1
			end
		end
	end
	return counts
end

local function RemoveUnwantedGroups(songs)
	local filtered_songs = {}
	for i,song in ipairs(songs) do
		if song:GetGroupName() ~= "Muted" then
			table.insert(filtered_songs, song)
		end
	end
	return filtered_songs
end

local function SortByPlayCount(songs)
	table.sort(songs, function(a, b) return PROFILEMAN:GetSongNumTimesPlayed(a, 'ProfileSlot_Machine') < PROFILEMAN:GetSongNumTimesPlayed(b, 'ProfileSlot_Machine') end )
	return songs
end

local function Project(collection, dimension)
	local projection = {}
	for i,item in ipairs(collection) do
		projection[i] = item[dimension]
	end
	return projection
end

local function GraphData(graph, data)
	graph:Clear()
	graph:AddPoint(0, 0, Color.Black)
	local max = 0
	for i,item in ipairs(data) do
		max = math.max(max, item)
	end
	for i,item in ipairs(data) do
		graph:AddPoint(i/(#data+1), item/max, Color.White)
	end
end

local function GraphDimensionOfSelections(graph, data, dimension)
	graph:Clear()
	graph:AddPoint(0, 0, Color.Black)
	local stage = FlowDJ.stage + 1
	local sorted = CopyTable(data)
	table.sort(sorted, function(a, b)
		return a[dimension] < b[dimension]
	end)
	local max = sorted[#sorted][dimension]
	for i,item in ipairs(sorted) do
		local x = i/(#sorted+1)
		local y = item[dimension]/max
		local point = graph:AddPoint(x, y, Color.White)
		if item.selected and point then
			point:xy(x, 1 - y/2):setsize(0.005, y):diffuse(Alpha(Color.White, 0.5))
			if item.stage == stage then
				point:diffuse(Color.Green):setsize(0.01, y)
			end
		end
	end
end

local function GraphFlow(graph, flow, selections, theta, range)
	graph:Clear()
	graph:AddPoint(0, 0, Color.Black)
	local stage = FlowDJ.stage + 1
	for i,item in ipairs(flow) do
		local alpha = 0.5
		if i == stage then
			alpha = 1
		end

		local x = i/(#flow+1)
		local flow_point = graph:AddPoint(x, item, Alpha(Color.White, alpha * 0.5))
		if flow_point then
			flow_point:setsize(0.03, range*2)
		end

		local sel = selections[i]

		local color = Color.White
		local y = PredictedScore(sel, theta)
		local predict_point = graph:AddPoint(x, y, Alpha(Color.Yellow, alpha))
		if predict_point then
			predict_point:setsize(0.05, 0.01)
		end

		if sel.score ~= 0.0 then
			local score_point = graph:AddPoint(x, sel.score, Alpha(Color.White, alpha))
			if score_point then
				score_point:setsize(0.05, 0.01)
			end
		end
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
	math.randomseed(GAMESTATE:GetGameSeed())
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
	math.randomseed(GetTimeSinceStart())
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
	center_text:settext(max_nps)
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
	--nps = 0,
	significant_timing_changes = 0,
	min_bpm = 0,
	max_bpm = 0,
}
for c,category in ipairs(RadarCategory) do
	initial_theta[category] = 0
end

local function Polynomial(factors, degree)
	local keys = {}
	for key,value in pairs(factors) do
		if key ~= 'c' and key ~= 'significant_timing_changes' then
			table.insert(keys, key)
		end
	end
	for d = 2,degree do
		for i,key in ipairs(keys) do
			factors[key..d] = factors[key] ^ d
		end
	end
end

local function Cross(factors)
	local keys = {}
	for key,value in pairs(factors) do
		if key ~= 'c' then
			table.insert(keys, key)
		end
	end
	for a,keya in ipairs(keys) do
		for b = 1,a do
			local keyb = keys[b]
			factors[keya..keyb] = factors[keya] * factors[keyb]
		end
	end
end

local poly = 2

Polynomial(initial_theta, poly)
--Cross(initial_theta)

if not FlowDJ.theta['c'] then
	FlowDJ.theta = CopyTable(initial_theta)
end

local function AddFactors(steps)
	for i,sel in ipairs(steps) do
		local bpms = sel.song:GetDisplayBpms()
		sel.factors = {
			c = 1,
			meter = sel.meter,
			--nps = sel.nps,
			min_bpm = bpms[1] or 0,
			max_bpm = bpms[2] or 120,
		}
		local radar = sel.steps:GetRadarValues(pn)
		for c,category in ipairs(RadarCategory) do
			local value = radar:GetValue(category)
			sel.factors[category] = value
		end
		Polynomial(sel.factors, poly)
		sel.factors['significant_timing_changes'] = 0
		if sel.steps:HasSignificantTimingChanges() then
			sel.factors['significant_timing_changes'] = 1
		end
		--Cross(sel.factors)
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

local function GradientDescent(steps, theta, cost_history)
	local alpha = 0.1
	local tick_start = GetTimeSinceStart()
	local crazy = 0
	if #cost_history == 0 then
		cost_history[1] = ComputeCost(steps, theta)
	end
	while GetTimeSinceStart() - tick_start < 0.02 and #cost_history < 5000 and crazy < 100 do
		crazy = crazy + 1
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
		cost_history[#cost_history+1] = ComputeCost(steps, theta)
	end
	return theta, cost_history
end

local function Scramble(list)
	for i = 1,#list do
		local j = math.random(#list)
		local temp = list[i]
		list[i] = list[j]
		list[j] = temp
	end
end

local function ScoredSteps(possible)
	local scored = {}
	for p,sel in ipairs(possible) do
		if sel.score ~= 0 then
			table.insert(scored, sel)
		end
	end
	return scored
end

local possible_steps = PossibleSteps()
AddFactors(possible_steps)
local scored_steps = ScoredSteps(possible_steps)

local function TrainingData(scored)
	Scramble(scored)
	local training_size = math.floor(#scored * 0.7)
	local training = {}
	for i = 1,training_size do
		training[i] = scored[i]
	end
	local test = {}
	for i = training_size+1,#scored do
		test[i-training_size] = scored[i]
	end
	lua.ReportScriptError(#training .. " " .. #test)
	return training,test
end

local function SamplePredictions(scored)
	local training, test = TrainingData(scored)
	lua.ReportScriptError(#training .. " " .. #test)
	local theta = CopyTable(initial_theta)
	local history = {}
	GradientDescent(training, theta, history)
	return history[#history], ComputeCost(test, theta)
end

local function MultipleTraining(possible)
	AddFactors(possible)
	local scored = ScoredSteps(possible)
	local training_history = {}
	local test_history = {}
	local total_training_cost = 0
	local total_test_cost = 0
	local rounds = 100
	for i = 1,rounds do
		local training_cost, test_cost = SamplePredictions(scored)
		total_training_cost = total_training_cost + training_cost
		total_test_cost = total_test_cost + test_cost
		training_history[i] = training_cost
		test_history[i] = test_cost
	end
	right_text:settext(
		(total_training_cost / rounds) .. "\n" ..
		(total_test_cost / rounds))
	GraphData(graph, training_history)
end

local function EvaluatePredictions(possible)
	AddFactors(possible)
	local scored = ScoredSteps(possible)
	local training, test = TrainingData(scored)
	lua.ReportScriptError(#training .. " " .. #test)
	local theta = CopyTable(initial_theta)
	local history = {}
	GradientDescent(training, theta, history)
	graph:Clear()
	graph:AddPoint(0, 0, Color.Black)
	GraphPredictions(training, theta, Color.Green)
	GraphPredictions(test, theta, Color.Yellow)
	--GraphData(graph, history)
	right_text:settext(ThetaDebug(theta) .. "\n" ..
		history[#history] .. "\n" ..
		ComputeCost(test, theta))
	lua.ReportScriptError(history[#history])
	right_text:zoom(0.30)
	--right_text:settext(rec_print_table_to_str(CountRadarUsage(possible)))
end

local function PickByMeter(flow)
	local selections = {}
	local picked = {}
	local recent = RecentSongs()
	for i,song in ipairs(recent) do
		picked[song:GetSongFilePath()] = true
	end
	for i,target in ipairs(flow) do
		local meter = math.floor(target)
		for j,sel in ipairs(possible_steps) do
			local path = sel.song:GetSongFilePath()
			if sel.meter == meter and not picked[path] then
				selections[i] = sel
				sel.selected = true
				sel.stage = i
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

local function PickByScore(flow, theta, range)
	local selections = {}
	local picked = {}
	local recent = RecentSteps()
	for i,step in ipairs(recent) do
		local song = SONGMAN:GetSongFromSteps(step)
		picked[song:GetSongFilePath()] = true
		for j,sel in ipairs(possible_steps) do
			if sel.steps == step then
				selections[i] = sel
				sel.selected = true
				sel.stage = i
			end
		end
	end
	for i,target in ipairs(flow) do
		if not selections[i] then
			local low = target - range
			local high = target + range
			for j,sel in ipairs(possible_steps) do
				local path = sel.song:GetSongFilePath()
				local score = sel.score
				if score == 0 then
					score = PredictedScore(sel, theta)
				end
				if low < score and score < high and not picked[path] then
					selections[i] = sel
					sel.selected = true
					sel.stage = i
					picked[path] = true
					break
				end
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

local function SetupNextGame(selections)
	local sel = selections[FlowDJ.stage + 1]
	if sel then
		GAMESTATE:SetCurrentSong(sel.song)
		GAMESTATE:SetCurrentSteps(pn, sel.steps)
		center_text:settext(DisplayNextSong(sel))
	else
		trans_new_screen("ScreenTitleMenu")
	end
end

local function StartNextGame(selections)
	local sel = selections[FlowDJ.stage + 1]
	if sel then
		entering_song = GetTimeSinceStart() + 1.5
	else
		trans_new_screen("ScreenTitleMenu")
	end
end

local incremental_history = {}
local incremental_step = 1
local current_flow = WiggleFlow(ManualFlow(0.85, 0.7), 0.05)
--local current_flow = WiggleFlow(ManualFlow(2, 7.7), 1)
local selection_range = 0.03
local selection_snapshot = {}

local function IncrementalGraphPredictions(steps, theta, color)
	for i = 1,10 do
		local prediction = 0
		local sel = steps[incremental_step]
		for key,value in pairs(theta) do
			prediction = prediction + value * sel.factors[key]
		end
		graph:SetPoint(incremental_step, sel.score, prediction, color)
		incremental_step = (incremental_step % #steps) + 1
	end
end

local function IncrementalUpdate()
	GradientDescent(scored_steps, FlowDJ.theta, incremental_history)
	IncrementalGraphPredictions(scored_steps, FlowDJ.theta, Color.White)
end

local frame = 0
local function update(self)
	if entering_song then
		if GetTimeSinceStart() > entering_song then
			trans_new_screen(play_screen)
		end
	end
	frame = frame + 1
	if frame == 2 then
		local screen = self:GetParent()
		graph = screen:GetChild("graph")
		--GraphSteps()
		--left_text:settext(SongsDebug(RecentSongs()))
		--left_text:settext(StepsDebug(RecentSteps()))
		--EvaluatePredictions(PossibleSteps())
		--MultipleTraining(PossibleSteps())
	end
	if frame >= 2 then

		IncrementalUpdate()
		left_text:settext(ThetaDebug(FlowDJ.theta) .. "\n" ..
			incremental_history[#incremental_history] .. "\n" ..
			#incremental_history)
		left_text:zoom(0.30)
		cost_quad:setsize(SCREEN_WIDTH * incremental_history[#incremental_history] / 0.005, 10)

		if #selection_snapshot == 0 and incremental_history[#incremental_history] < 0.003 then
			selection_snapshot = PickByScore(current_flow, FlowDJ.theta, selection_range)
			--selection_snapshot = PickByMeter(flow)
			right_text:settext(SelectionsDebug(selection_snapshot))
			SetupNextGame(selection_snapshot)

			local screen = self:GetParent()
			GraphFlow(screen:GetChild("flow graph"), current_flow, selection_snapshot, FlowDJ.theta, selection_range)
			AssignScore(possible_steps, FlowDJ.theta)
			GraphDimensionOfSelections(screen:GetChild("score graph"), possible_steps, "effective_score")
			GraphDimensionOfSelections(screen:GetChild("nps graph"), possible_steps, "nps")

		end

		if auto_start and not entering_song then
			StartNextGame(selection_snapshot)
		end
	end
end

local function input(event)
	local pn = event.PlayerNumber
	if not pn then return end
	local button = event.GameButton
	if not button then return end
	if event.type == "InputEventType_Release" then return end
	if button == "Start" then
		if entering_song then
			trans_new_screen("ScreenPlayerOptions")
			SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
		elseif #selection_snapshot > 0 then
			StartNextGame(selection_snapshot)
			SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
		end
	elseif button == "Back" then
		trans_new_screen("ScreenTitleMenu")
		SOUND:PlayOnce(THEME:GetPathS("Common", "cancel"))
	else
		lua.ReportScriptError(button)
	end
end

local function Graph(name, x, y, scale)
	return Def.ActorFrame{
		Name = name, InitCommand = function(self)
			self:xy(x, y)
			self:zoom(scale)

			self.AddPoint = function(self, x, y, color)
				local data = self:GetChild("data")
				data:AddChildFromPath(THEME:GetPathG("", "point.lua"))
				local points = data:GetChild("point")
				if points and #points > 0 then
					points[#points]:xy(x, 1 - y):diffuse(color)
					return points[#points]
				else
					return false
				end
			end

			self.SetPoint = function(self, n, x, y, color)
				local data = self:GetChild("data")
				local points = data:GetChild("point")
				if points and points[n] then
					points[n]:xy(x, 1 - y):diffuse(color)
				else
					data:AddChildFromPath(THEME:GetPathG("", "point.lua"))
				end
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
	}
end

local t = Def.ActorFrame{
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
	Graph("graph", 20, 20, math.min(SCREEN_WIDTH - 40, SCREEN_HEIGHT - 50)),
	Graph("score graph", 20, SCREEN_HEIGHT - 200, 100),
	Graph("nps graph", 140, SCREEN_HEIGHT - 200, 100),
	Graph("flow graph", 260, SCREEN_HEIGHT - 200, 100),
	Def.Quad{
		Name= "cost", InitCommand = function(self)
			cost_quad = self
			self:xy(_screen.cx, 40)
		end
	},
	Def.BitmapText{
		Name = "Center", Font = "Common Normal", InitCommand = function(self)
			center_text = self
			self:xy(_screen.cx, _screen.cy)
		end
	},
	Def.BitmapText{
		Name = "Stage", Font = "Common Normal", InitCommand = function(self)
			self:xy(_screen.cx, 20)
			self:settext(string.format("Stage %d", (STATSMAN:GetStagesPlayed() + 1)))
		end
	},
}

return t
