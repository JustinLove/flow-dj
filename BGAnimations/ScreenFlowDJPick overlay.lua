local fake_data = false
FlowDJ.fake_play = false
local stages = FlowDJGetSetting("NumberOfStages")
local mid_score = FlowDJGetSetting("MidScore")/100
local start_score = mid_score + (1.0 - mid_score)/2
local percent_wiggle = FlowDJGetSetting("PercentWiggle")/100
local sample_music = FlowDJGetSetting("SampleMusic")
local slowest_speed = FlowDJGetSetting("SlowestSpeed")
local maximum_cost = 0.0015
local minimum_iteration_per_stage = 200
local minimum_iteration = 1000
local maximum_iteration = 5000

local text_height = SCREEN_HEIGHT/48
local function SongListScale()
	return math.min(0.6 * text_height / stages, 0.12*SCREEN_WIDTH/240)
end

local pn = GAMESTATE:GetEnabledPlayers()[1]
--local currentstyle = GAMESTATE:GetCurrentStyle(pn)
--local stepstype = currentstyle:GetStepsType()
local stepstype = 'StepsType_Dance_Single'
local machine_profile = PROFILEMAN:GetMachineProfile()
local player_profile = PROFILEMAN:GetProfile(pn)
if player_profile:GetDisplayName() == "" then
	player_profile = machine_profile
end

local top_frame = false
local flow_frame = false
local model_frame = false
local graph = false
local cost_quad = false
local song_text = false
local banner_sprite = false
local stages_text = false
local settings_text = false
local song_list_overlay = false
local help_text = false
local center_text = false
local left_text = false
local right_text = false

local current_view = "model"
local current_controls = "default"
local entering_song = false
local show_score_settings = false

lua.ReportScriptError('----------------' .. math.random())

local player_state = GAMESTATE:GetPlayerState(pn)
local player_options = player_state:GetPlayerOptionsString("ModsLevel_Current")

if not FlowDJ.fake_play then
	FlowDJ.stage = GAMESTATE:GetCurrentStageIndex()
end
if FlowDJ.stage == 0 then
	FlowDJ.seed = GAMESTATE:GetGameSeed()
	FlowDJ.offset = math.random() * math.pi
	FlowDJ.scale = math.random() * 2 + 1
end

if FlowDJ.seed == 8365 then
	FlowDJ.seed = math.floor(math.random() * 32767)
end

lua.ReportScriptError('seed' .. FlowDJ.seed)

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
	return sel.song:GetDisplayMainTitle()
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

local function FakeRecentSteps(pool)
	local recent = {}
	for i = 1,FlowDJ.stage do
		sel = pool[math.random(#pool)]
		if sel.score == 0 then
			sel.score = 1.0 - sel.meter * 0.05
		end
		recent[i] = sel
	end
	return recent
end

function play_sample_music(song)
	local fade_time = 1
	if song and sample_music then
		local song_dir= song:GetSongDir()
		local songpath= song:GetMusicPath()
		if song.GetPreviewMusicPath then
			songpath= song:GetPreviewMusicPath()
		end
		local sample_start= song:GetSampleStart()
		local sample_len= song:GetSampleLength()
		SOUND:PlayMusicPart(
			songpath, sample_start, sample_len, fade_time, fade_time, false, true)
	end
end

function stop_music()
	SOUND:PlayMusicPart("", 0, 0)
end

local function Truncate(table, to)
	local truncated = {}
	local length = math.min(to, #table)
	for i=1,length do
		truncated[i] = table[i]
	end
	return truncated
end

local function Scramble(list)
	for i = 1,#list do
		local j = math.random(#list)
		local temp = list[i]
		list[i] = list[j]
		list[j] = temp
	end
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
		if song:GetGroupName() ~= "Impossible" then
		--if song:GetGroupName() == "Muted" then
		--if song:GetGroupName() ~= "Muted" and song:GetGroupName() ~= "Impossible" then
			table.insert(filtered_songs, song)
		end
	end
	return filtered_songs
end

local function Project(collection, dimension)
	local projection = {}
	for i,item in ipairs(collection) do
		projection[i] = item[dimension]
	end
	return projection
end

local function GraphData(graph, data, max)
	graph:Clear()
	graph:AddPoint(0, 0, Color.Black)
	if not max then
		max = 0
		for i,item in ipairs(data) do
			max = math.max(max, item)
		end
	end
	for i,item in ipairs(data) do
		graph:AddPoint(i/(#data+1), item/max, Color.White)
	end
end

local function GraphDataOverlay(graph, data, max, color)
	for i,item in ipairs(data) do
		graph:AddPoint(i/(#data+1), item/max, color)
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
		local flow_point = graph:AddPoint(x, item, Brightness(Color.White, alpha * 0.5))
		if flow_point then
			flow_point:setsize(0.03, range*2)
			if i == stage then
				flow_point:glowshift()
				flow_point:effectcolor1(Brightness(Color.White, 0.6))
				flow_point:effectcolor2(Brightness(Color.White, 0.8))
				flow_point:effectperiod(2)
			end
		end

		local sel = selections[i]

		local color = Color.White
		local y = PredictedScore(sel, theta)
		local predict_point = graph:AddPoint(x, y, Brightness(Color.Blue, alpha))
		if predict_point then
			predict_point:setsize(0.05, 0.02)
			if i == stage then
				predict_point:glowshift()
				predict_point:effectcolor1(Brightness(Color.Blue, 0.8))
				predict_point:effectcolor2(Brightness(Color.Blue, 1.0))
				predict_point:effectperiod(2)
			end
		end

		if sel.score ~= 0.0 then
			local score_point = graph:AddPoint(x, sel.score, Brightness(Color.White, alpha))
			if score_point then
				score_point:setsize(0.05, 0.02)
				if i == stage then
					score_point:glowshift()
					score_point:effectcolor1(Brightness(Color.White, 0.8))
					score_point:effectcolor2(Brightness(Color.White, 1.0))
					score_point:effectperiod(2)
				end
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
	local manual = {}
	for i,item in ipairs(FlowDJ.manual_songs) do
		manual[item] = i
	end

	local weighted = {}
	local most = 0
	for i,song in ipairs(songs) do
		local count = PROFILEMAN:GetSongNumTimesPlayed(song, 'ProfileSlot_Machine')
		most = math.max(most, count)
		weighted[i] = {
			song = song,
			title = song:GetDisplayMainTitle(),
			count = count,
			manual = manual[song:GetMusicPath()],
		}
	end
	most = (most / 2) + 1

	for i,item in ipairs(weighted) do
		local rand = math.random()
		local play = (weighted[i].count + 1) / (weighted[i].count + most)
		--weighted[i].rand = rand
		--weighted[i].play = play
		weighted[i].weight = rand * play
	end

	table.sort(weighted, function(a, b)
		if a.manual and b.manual then
			return a.manual < b.manual
		elseif a.manual then
			return true
		elseif b.manual then
			return false
		else
			return a.weight < b.weight
		end
	end )

	--GraphWeight(weighted)
	local sorted = {}
	for i,item in ipairs(weighted) do
		sorted[i] = weighted[i].song
	end
	return sorted, weighted
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
			local high_score_list = machine_profile:GetHighScoreListIfExists(song, steps)
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
	local high_score_list = player_profile:GetHighScoreListIfExists(song, steps)
	if high_score_list then
		local scores = high_score_list:GetHighScores()
		local score = scores[1]
		if score then
			return score:GetPercentDP()
		end
	end

	return 0
end

local function PossibleSteps()
	math.randomseed(FlowDJ.seed)
	local all_songs, weighted = WeightByPlayCount(RemoveUnwantedGroups(SONGMAN:GetAllSongs()))
	local possible = {}
	for g, song in ipairs(all_songs) do
		local song_steps = song:GetStepsByStepsType(stepstype)
		Scramble(song_steps)
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
	math.randomseed(GetTimeSinceStart())
	return possible
end

local function ResetSelected(selections)
	for i,sel in ipairs(selections) do
		sel.selected = false
	end
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
	nps = 0,
	max_bpm = 0,
}
for c,category in ipairs(RadarCategory) do
	initial_theta[category] = 0
end

local function Polynomial(factors, degree)
	local keys = {}
	for key,value in pairs(factors) do
		if key ~= 'c' then
			table.insert(keys, key)
		end
	end
	for d = 2,degree do
		for i,key in ipairs(keys) do
			factors[key..d] = factors[key] ^ d
		end
	end
	--for i,key in ipairs(keys) do
		--factors[key.."root"] = math.sqrt(factors[key])
	--end
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

local theta_count = 0
for key,value in pairs(initial_theta) do
	theta_count = theta_count + 1
end

-- ~= nan check
if not FlowDJ.theta['c'] or FlowDJ.theta['c'] ~= FlowDJ.theta['c'] then
	lua.ReportScriptError("reset theta")
	FlowDJ.theta = CopyTable(initial_theta)
end

local function AddFactors(steps)
	for i,sel in ipairs(steps) do
		local bpms = sel.song:GetDisplayBpms()
		sel.factors = {
			c = 1,
			meter = sel.meter,
			nps = sel.nps,
			max_bpm = bpms[2] or 120,
		}
		local radar = sel.steps:GetRadarValues(pn)
		for c,category in ipairs(RadarCategory) do
			local value = radar:GetValue(category)
			sel.factors[category] = value
		end
		Polynomial(sel.factors, poly)
		--Cross(sel.factors)
	end
	NormalizeFactors(steps)
end

local function ComputeCost(steps, theta)
	if #steps < 1 then
		return 0
	end
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

local termerror = {}
local termcost = {}

local function TermCost(steps, theta)
	if #steps < 1 then
		return 0
	end
	for key,value in pairs(theta) do
		termerror[key] = 0
		termcost[key] = 0
	end
	for p,sel in ipairs(steps) do
		local prediction = 0
		for key,value in pairs(theta) do
			prediction = prediction + value * sel.factors[key]
		end
		local error = prediction - sel.score
		for key,value in pairs(termcost) do
			termerror[key] = termerror[key] + error * sel.factors[key]
			termcost[key] = termcost[key] + math.abs(error * sel.factors[key])
		end
	end
	for key,value in pairs(termcost) do
		termcost[key] = termcost[key] / #steps
	end
end

local function GradientDescent(steps, theta, cost_history)
	if #steps < 1 then
		cost_history[#cost_history+1] = 0
		return theta, cost_history
	end
	local alpha = 8/theta_count
	local tick_start = GetTimeSinceStart()
	local crazy = 0
	if #cost_history == 0 then
		cost_history[1] = ComputeCost(steps, theta)
	end
	while GetTimeSinceStart() - tick_start < 0.02 and #cost_history < maximum_iteration and crazy < 100 do
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
	TermCost(steps, theta)
	return theta, cost_history
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

local function WorstScore(selections)
	local worst = 1.0
	for i,sel in ipairs(selections) do
		if sel.score ~= 0.0 and sel.score < worst then
			worst = sel.score
		end
	end
	lua.ReportScriptError("worst " .. worst)
	return worst
end

local possible_steps = PossibleSteps()
AddFactors(possible_steps)

local fake_recent_steps = {}
if fake_data then
	fake_recent_steps = FakeRecentSteps(possible_steps)
end

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
	right_text:zoom(0.03*text_height)
	--right_text:settext(rec_print_table_to_str(CountRadarUsage(possible)))
end

local function StatsPickRecent()
	local selections = {}
	local picked = {}
	local recent
	if fake_data then
		recent = fake_recent_steps
	else
		recent = RecentSteps()
	end
	local stages = STATSMAN:GetStagesPlayed()
	for i = 1,stages do
		local stats = STATSMAN:GetPlayedStageStats(i)
		local playerstats = stats:GetPlayerStageStats(pn)
		local step = playerstats:GetPlayedSteps()[1]
		recent[i] = step
		local song = SONGMAN:GetSongFromSteps(step)
		picked[song:GetSongFilePath()] = true
		local stage = (stages-i)+1
		for j,sel in ipairs(possible_steps) do
			if sel.steps == step then
				selections[stage] = sel
				sel.selected = true
				sel.score = playerstats:GetPercentDancePoints()
				sel.stage = stage
			end
		end
	end
	return selections, picked
end

local function FakePickRecent()
	local selections = {}
	local picked = {}
	local recent = fake_recent_steps
	for i,sel in ipairs(recent) do
		picked[sel.song:GetSongFilePath()] = true
		local stage = (#recent-i)+1
		selections[stage] = sel
		sel.stage = stage
	end
	return selections, picked
end

local function PickRecent()
	if fake_data then
		return FakePickRecent()
	else
		return StatsPickRecent()
	end
end

local function PickByMeter(flow)
	local selections, picked = PickRecent()
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

local function PickByRate(flow, start_range)
	local selections, picked = PickRecent()
	for i,target in ipairs(flow) do
		local range = 0
		while not selections[i] and range < 2.0 do
			range = range + start_range
			local low = target - range
			local high = target + range
			for j,sel in ipairs(possible_steps) do
				local path = sel.song:GetSongFilePath()
				local nps = sel.nps
				if low < nps and nps < high and not picked[path] then
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

local function PickByRange(flow, theta)
	local selections, picked = PickRecent()
	local predictions = {}
	for i,min in ipairs(flow.score_bound) do
		local range = 0
		while not selections[i] and range < 2.0 do
			local bottom = flow.nps_upper_bound[i]
			local top = flow.nps_lower_bound[i]
			for j,sel in ipairs(possible_steps) do
				local path = sel.song:GetSongFilePath()
				local score = sel.score
				local nps = sel.nps
				if score == 0 then
					if not predictions[j] then
						predictions[j] = PredictedScore(sel, theta)
					end
					score = predictions[j]
				end
				if min < score and flow.nps_lower_bound[i] + flow.selection_range < nps and nps < flow.nps_upper_bound[i] - flow.selection_range and not picked[path] then
					if nps < bottom then
						bottom = nps
					end
					if nps > top then
						top = nps
					end
				end
			end
			range = range + flow.selection_range
			local target = bottom + (top - bottom)*flow.wiggle[i]
			local low = target - range
			local high = target + range
			for j,sel in ipairs(possible_steps) do
				local path = sel.song:GetSongFilePath()
				local score = sel.score
				local nps = sel.nps
				if score == 0 then
					if not predictions[j] then
						predictions[j] = PredictedScore(sel, theta)
					end
					score = predictions[j]
				end
				if min < score and low < nps and nps < high and not picked[path] then
					selections[i] = sel
					sel.selected = true
					sel.stage = i
					sel.nps_low = low
					sel.nps_high = high
					sel.nps_bottom = bottom - range
					sel.nps_top = top + range
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

local function PickByBounds(flow, theta)
	local selections, picked = PickRecent()
	local predictions = {}
	for i = 1,stages do
		local x = (i-1)/(stages-1)
		local min = flow.score_bound(x)
		local range = 0
		while not selections[i] and range < 2.0 do
			local top = flow.nps_upper_bound(x)
			local bottom = flow.nps_lower_bound(x)
			range = range + flow.selection_range
			local low = bottom - range
			local high = top + range
			for j,sel in ipairs(possible_steps) do
				local path = sel.song:GetSongFilePath()
				local score = sel.score
				local nps = sel.nps
				if score == 0 then
					if not predictions[j] then
						predictions[j] = PredictedScore(sel, theta)
					end
					score = predictions[j]
				end
				--[[lua.ReportScriptError(rec_print_table_to_str({
						min = min,
						score = score,
						bottom = bottom,
						nps = nps,
						top = top
					}))
					]]
				if min < score and bottom < nps and nps < top and not picked[path] then
					selections[i] = sel
					sel.selected = true
					sel.stage = i
					sel.nps_low = nps 
					sel.nps_high = nps
					sel.nps_bottom = bottom
					sel.nps_top = top
					picked[path] = true
					break
				end
			end
		end
		if not selections[i] then
			lua.ReportScriptError("missing " .. i)
		end
	end
	return selections
end

local function PickByScore(flow, theta)
	local selections, picked = PickRecent()
	for i = 1,stages do
		local x = (i-1)/(stages-1)
		local target = flow.score_bound(x)
		local range = 0
		while not selections[i] and range < 2.0 do
			range = range + 0.03
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

local function PickBootstrap()
	local selections, picked = PickRecent()
	for i = 1,stages do
		local range = 0
		while not selections[i] and range < 10 do
			local low = i - range
			local high = i + range
			for j,sel in ipairs(possible_steps) do
				local path = sel.song:GetSongFilePath()
				if low <= sel.meter and sel.meter <= high and not picked[path] then
					selections[i] = sel
					sel.selected = true
					sel.stage = i
					picked[path] = true
					break
				end
			end
			range = range + 1
		end
		if not selections[i] then
			lua.ReportScriptError("missing " .. i)
		end
	end
	return selections
end

local function ConstantFactor(c)
	return function(x)
		return c
	end
end

local function BezierFactor(p0, p1, p2, p3)
	return function(t)
		local it = 1 - t
		return it*it*it*p0 + 3*it*it*t*p1 + 3*it*t*t*p2 + t*t*t*p3
	end
end

local function BSpline(knots, levels, degree)
	return function(x)
		local index = (#knots - 1) - degree - 1
		for i = 1,(#knots-1) do
			if knots[i] <= x and x < knots[i+1] then
				index = i - 1
				break
			end
		end

		--lua.ReportScriptError("x " .. x .. ", index " .. index)

		local d = {}
		for i = 0,(degree+1) do
			d[1+i] = levels[1 + i + index - degree]
		end
		--lua.ReportScriptError(rec_print_table_to_str(d))

		for r = 1,(degree+1) do
			for j = degree,r,-1 do
				local from = knots[1 + j + index - degree]
				local to = knots[1 + j + 1 + index - r]
				local alpha = (x - from) / (to - from)
				--lua.ReportScriptError("r " .. r .. ", j " .. j .. ", from" .. from .. ", to " .. to .. "," .. alpha)
				local di = d[1+j]
				local dip = d[1+j-1]
				--lua.ReportScriptError(di .. "," .. dip)
				d[1+j] = ((1.0 - alpha) * d[1+j-1]) + (alpha * d[1+j])
			end
		end

		return d[1 + degree]
	end
end

local function ArcFactor(a)
	return function(x)
		return (x ^ (a-1)) * (1 - (x ^ a)) * (2.1 + (a - 1.5) * 0.5)
	end
end

local function Scaled(f, start, middle)
	return function(x)
		local factor = f(x)
		return start * (1-factor) + middle * factor
	end
end

local function WiggleFactor(x)
	return math.sin(FlowDJ.scale*(x*10) + FlowDJ.offset)
end

local function AddCurve(a, b)
	return function(x)
		return a(x) + b(x)
	end
end

local function MultiplyCurve(a, b)
	return function(x)
		return a(x) * b(x)
	end
end

local function ExponetialFactor(pow)
	return function(x)
		return 1 - (2 * (x - 0.5)) ^ pow
	end
end

local function ManualFlowFactor(edge)
	return function(x)
		local end_distance = math.min(x, 1 - x)
		local start_factor = 0
		local mid_factor = 1
		if end_distance < edge then
			mid_factor = end_distance / edge
		else
			mid_factor = 1
		end
		return mid_factor
	end
end

local function DistributionFactor(x)
	math.randomseed(FlowDJ.seed*x)
	local y = 1-(math.random() ^ 3)
	math.randomseed(GetTimeSinceStart())
	return y
end

local function EvalFlow(n, f)
	local flow = {}
	for i = 1,n do
		flow[i] = f((i-1)/(n-1))
	end
	return flow
end

local shape = BSpline({0,0 , 0 , 0.2 , 0.65, 0.8 , 1  , 1,1},
                         {0.0,0.6,  1.0 , 1.0 , 0.8, 0.0},2)

local function BuildFlow()
	--local shape = BSpline({0,0 , 0 , 0.2 , 0.65, 0.8 , 1  , 1,1},
	                         --{0.0,0.8,  1.0 , 1.0 , 0.8, 0.0},2)
	--local shape = ExponetialFactor(4)
	local base = Scaled(shape, 0, 1-percent_wiggle)
	local envelope = Scaled(shape, 0.5, 1)
	local range = MultiplyCurve(envelope, Scaled(WiggleFactor, 0, percent_wiggle))
	local wiggle = AddCurve(base, range)

	return {
		wiggle = wiggle,
		wiggle_base = Scaled(shape, start_score, mid_score),
		wiggle_range = Scaled(envelope, 0, percent_wiggle * mid_score * 2),
		--nps_lower_bound = ConstantFactor(slowest_speed),
		nps_lower_bound = Scaled(wiggle, slowest_speed/4, slowest_speed),
		--nps_upper_bound = Scaled(ExponetialFactor(2), 2, 10),
		nps_upper_bound = ConstantFactor(10),
		score_bound = Scaled(wiggle, start_score, mid_score),
		selection_range = 0.3,
	}

	--local current_flow = WiggleFlow(ManualFlow(1.5, 3.5), ManualFlow(0.2, 0.8))
	--local current_flow = WiggleFlow(ArcFlow(3, 1.5, 3.5), ManualFlow(0.2, 0.8))
	--local current_flow = WiggleFlow(ManualFlow(2, 7.7), ManualFlow(1, 1))
	--return WiggleFlow(ManualFlow(0.5, 0.5), ManualFlow(0.5, 0.5))
	--return WiggleFlow(ArcFlow(3, 1.3, 3.5), ArcFlow(3, 0.3, 1))
	--return WiggleFlow(ManualFlow(start_score, mid_score), ManualFlow(percent_wiggle * 0.5, percent_wiggle))
	--return WiggleFlow(ArcFlow(3, start_score, mid_score), ManualFlow(percent_wiggle * 0.5, percent_wiggle))
	--return ArcFlow(3, start_score, mid_score)
end

local function DisplaySelectionForCurrentStage(selections)
	local sel = selections[FlowDJ.stage + 1]
	if sel then
		song_text:settext(DisplayNextSong(sel))
		banner_sprite:playcommand("Set", sel)
		play_sample_music(sel.song)
	else
		stop_music()
		trans_new_screen("ScreenTitleMenu")
	end
end

local function SetupNextGame(selections)
	local sel = selections[FlowDJ.stage + 1]
	stop_music()
	if sel then
		GAMESTATE:SetCurrentSong(sel.song)
		GAMESTATE:SetCurrentSteps(pn, sel.steps)
	else
		trans_new_screen("ScreenTitleMenu")
	end
end

local function StartNextGame(selections)
	local sel = selections[FlowDJ.stage + 1]
	if sel then
		entering_song = GetTimeSinceStart() + 1.5
	else
		stop_music()
		trans_new_screen("ScreenTitleMenu")
	end
end

local incremental_history = {}
local incremental_step = 1
local current_flow = BuildFlow()
local selection_snapshot = {}

local function IncrementalGraphPredictions(steps, theta, color)
	if #steps < 1 then
		return
	end
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

local function SetControls(controls)
	current_controls = controls
	if controls == "wigglestages" then
		help_text:GetChild("training help text"):visible(false)
		help_text:GetChild("default help text"):visible(false)
		help_text:GetChild("wigglestages help text"):visible(true)
		help_text:GetChild("slowestspeed help text"):visible(false)
		help_text:GetChild("special help text"):visible(false)
		song_list_overlay:SetLineOff()
	elseif controls == "slowestspeed" then
		help_text:GetChild("training help text"):visible(false)
		help_text:GetChild("default help text"):visible(false)
		help_text:GetChild("wigglestages help text"):visible(false)
		help_text:GetChild("slowestspeed help text"):visible(true)
		help_text:GetChild("special help text"):visible(false)
		song_list_overlay:SetLineOn()
	elseif controls == "special" then
		help_text:GetChild("training help text"):visible(false)
		help_text:GetChild("default help text"):visible(false)
		help_text:GetChild("wigglestages help text"):visible(false)
		help_text:GetChild("slowestspeed help text"):visible(false)
		help_text:GetChild("special help text"):visible(true)
		song_list_overlay:SetLineOff()
	else
		if #selection_snapshot == 0 and FlowDJ.stage == 0 then
			help_text:GetChild("training help text"):visible(true)
			help_text:GetChild("default help text"):visible(false)
		else
			help_text:GetChild("training help text"):visible(false)
			help_text:GetChild("default help text"):visible(true)
		end
		help_text:GetChild("wigglestages help text"):visible(false)
		help_text:GetChild("slowestspeed help text"):visible(false)
		help_text:GetChild("special help text"):visible(false)
	end
	local song_list = flow_frame:GetChild("song list")
	song_list:SetSelections(selection_snapshot)
end

local function SwitchControls()
	show_score_settings = false
	if current_controls == "default" then
		SetControls("wigglestages")
	elseif current_controls == "wigglestages" then
		SetControls("slowestspeed")
	elseif current_controls == "slowestspeed" then
		SetControls("special")
	else
		SetControls("default")
	end
end

local function SetView(view)
	current_view = view
	local time = 0.5
	if view == "flow" then
		flow_frame:linear(time):xy(0, 0)
		model_frame:linear(time):xy(_screen.cx - 200, _screen.cy - SCREEN_HEIGHT)
	else
		flow_frame:linear(time):xy(0, SCREEN_HEIGHT)
		model_frame:linear(time):xy(_screen.cx - 200, _screen.cy)
	end
	SetControls(current_controls)
end

local function SwitchView()
	if current_view == "flow" then
		SetView("model")
	else
		SetView("flow")
	end
end


local function PerformPick(frame)
	ResetSelected(possible_steps)

	if #scored_steps <= stages and WorstScore(scored_steps) > 0.6 then
		selection_snapshot = PickBootstrap()
	else
		selection_snapshot = PickByBounds(current_flow, FlowDJ.theta)
		--selection_snapshot = PickByRange(current_flow, FlowDJ.theta)
		--selection_snapshot = PickByScore(current_flow, FlowDJ.theta)
		--selection_snapshot = PickByRate(current_flow.wiggle, 0.3)
	end
	--selection_snapshot = PickByMeter(current_flow.wiggle)
	--right_text:settext(SelectionsDebug(selection_snapshot))
	local song_list = frame:GetChild("song list")
	AssignScore(possible_steps, FlowDJ.theta)
	song_list:SetSelections(selection_snapshot)
	DisplaySelectionForCurrentStage(selection_snapshot)

	--local curve_graph = song_list_overlay:GetChild("curve graph")
	--curve_graph:baserotationz(90)
	--GraphData(curve_graph, EvalFlow(10, DistributionFactor), 1)
	--GraphData(curve_graph, EvalFlow(1000, current_flow.wiggle_base), 1)
	--GraphDataOverlay(curve_graph, EvalFlow(1000, AddCurve(ConstantFactor(10), Scaled(current_flow.nps_lower_bound, 0, -1))), 10, Color.Red)
	--GraphDataOverlay(curve_graph, EvalFlow(1000, current_flow.score_bound), 1, Color.Blue)
	--GraphData(curve_graph, EvalFlow(1000, current_flow.wiggle, 1))
	--GraphData(curve_graph, EvalFlow(1000, MultiplyCurve(shape, Scaled(WiggleFactor, percent_wiggle, 0))), 1)

	--local shape = BSpline({0,0,0,0.2,0.65,0.8,1,1,1}, {0,0.8,1,1,0.8,0},2)
	--local shape = ExponetialFactor(4)
	--local base = Scaled(shape, 0+percent_wiggle, 1-percent_wiggle)
	--local range = Scaled(WiggleFactor, percent_wiggle, 0)
	--local wiggle = EvalFlow(1000, AddCurve(base, range)),
	--GraphData(curve_graph, wiggle)
	--GraphData(curve_graph, EvalFlow(1000, BSpline({0,0,0,0.2,0.65,0.8,1,1,1}, {0,0.8,1,1,0.8,0},2)))
	--GraphData(curve_graph, EvalFlow(1000, BSpline({0,0.33,0.66,1}, {0,1,0},0)))
	--GraphData(curve_graph, EvalFlow(1000, BezierFactor(0, 1, 1, 0)))
	--GraphData(curve_graph, EvalFlow(1000, ExponetialFactor(4)))
	--GraphData(curve_graph, EvalFlow(1000, Scaled(ArcFactor(3), 0+percent_wiggle, 1-percent_wiggle, x)))
	--GraphData(curve_graph, EvalFlow(1000, WiggleFactor))
	--GraphData(curve_graph, EvalFlow(1000, ManualFlowFactor(0.2)))
	--GraphData(curve_graph, EvalFlow(1000, Scaled(ManualFlowFactor(0.2), 0+percent_wiggle, 1-percent_wiggle, x)))
	--GraphData(curve_graph, EvalFlow(1000,
		--AddCurve(
			--Scaled(ManualFlowFactor(0.2), 0+percent_wiggle, 1-percent_wiggle),
			--Scaled(WiggleFactor, 0, percent_wiggle))))
	--GraphData(curve_graph, EvalFlow(1000,
		--AddCurve(
			--Scaled(ArcFactor(3), 0+percent_wiggle, 1-percent_wiggle),
			--Scaled(WiggleFactor, 0, percent_wiggle))))

	SetView("flow")
end

local function BumpFlow(stage, by)
	mid_score = math.max(0.0, math.min(1.0, mid_score - 0.02 * by))
	start_score = mid_score + (1.0 - mid_score)/2

	FlowDJSetSetting("StartScore", math.floor(start_score * 100))
	FlowDJSetSetting("MidScore", math.floor(mid_score * 100))

	settings_text:settext(string.format("low: %d\nmid: %d", math.floor(start_score * 100), math.floor(mid_score * 100)))

	current_flow = BuildFlow()
	show_score_settings = true
	PerformPick(flow_frame)
	song_list_overlay:SetLineOn()
end

local function BumpWiggle(by)
	percent_wiggle = math.max(0.0, math.min(0.5, percent_wiggle + 0.01 * by))
	FlowDJSetSetting("PercentWiggle", math.floor(percent_wiggle * 100))
	settings_text:settext(string.format("wiggle: %d", math.floor(percent_wiggle * 100)))
	current_flow = BuildFlow()
	PerformPick(flow_frame)
end

local function BumpStages(by)
	stages = math.max(FlowDJ.stage + 1, math.min(100, stages + by))
	FlowDJSetSetting("NumberOfStages", stages)
	current_flow = BuildFlow()
	PerformPick(flow_frame)
	stages_text:settext(string.format("%d Stages", stages))
end

local function BumpSlowestSpeed(by)
	slowest_speed = math.max(0, math.min(10, slowest_speed + by))
	FlowDJSetSetting("SlowestSpeed", slowest_speed)
	current_flow = BuildFlow()
	PerformPick(flow_frame)
	settings_text:settext(string.format("slowest: %0.1f", slowest_speed))
end

local function ToggleSampleMusic()
	sample_music = not sample_music
	FlowDJSetSetting("SampleMusic", sample_music)
	if sample_music then
		local sel = selection_snapshot[FlowDJ.stage + 1]
		if sel then
			play_sample_music(sel.song)
		end
	else
		stop_music()
	end
end

local frame = 0
local function update(self)
	if entering_song then
		if GetTimeSinceStart() > entering_song then
			entering_song = false
			stop_music()
			SetupNextGame(selection_snapshot)
			if FlowDJ.fake_play then
				trans_new_screen("ScreenFlowDJBounce")
			else
				trans_new_screen("ScreenGameplay")
			end
		end
	end
	frame = frame + 1
	if frame == 2 then
		local screen = self:GetParent()
		graph = screen:GetChild("model"):GetChild("graph")
		--GraphSteps()
		--left_text:settext(SongsDebug(RecentSongs()))
		--left_text:settext(StepsDebug(RecentSteps()))
		--EvaluatePredictions(PossibleSteps())
		--MultipleTraining(PossibleSteps())
		song_text:settext("Modeling score of unplayed steps")
		SetControls(current_controls)
	end
	if frame >= 2 then

		IncrementalUpdate()
		--left_text:settext(ThetaDebug(FlowDJ.theta) .. "\n" ..
		--	incremental_history[#incremental_history] .. "\n" ..
		--	#incremental_history)
		--left_text:zoom(0.03*text_height)
		cost_quad:setsize(200 * incremental_history[#incremental_history] / 0.005, 10)
		graph:SetLabel(string.format("avg cost %0.8f", incremental_history[#incremental_history]))

		if #selection_snapshot == 0 then
			if #incremental_history >= maximum_iteration then
				PerformPick(flow_frame)
			elseif FlowDJ.stage > 0
				and #incremental_history > minimum_iteration_per_stage
				and (incremental_history[#incremental_history] < maximum_cost
					or #incremental_history > minimum_iteration) then
				PerformPick(flow_frame)
			end
		end
	end
end

local function DefaultControls(button)
	if button == "MenuRight" then
		SOUND:PlayOnce(THEME:GetPathS("MusicWheel", "change"))
		BumpFlow(FlowDJ.stage + 1, -1)
		return true
	elseif button == "MenuLeft" then
		SOUND:PlayOnce(THEME:GetPathS("MusicWheel", "change"))
		BumpFlow(FlowDJ.stage + 1, 1)
		return true
	elseif button == "MenuUp" then
		SOUND:PlayOnce(THEME:GetPathS("MusicWheel", "change"))
		trans_new_screen("ScreenSelectMusic")
		return true
	elseif button == "MenuDown" then
		if FlowDJ.stage > 0 then
			stop_music()
			trans_new_screen("ScreenEvaluationNormal")
			SOUND:PlayOnce(THEME:GetPathS("MusicWheel", "change"))
		else
			SOUND:PlayOnce(THEME:GetPathS("Common", "invalid"))
		end
		return true
	end
	return false
end

local function WiggleStagesControls(button)
	if button == "MenuRight" then
		SOUND:PlayOnce(THEME:GetPathS("MusicWheel", "change"))
		BumpWiggle(1)
		return true
	elseif button == "MenuLeft" then
		SOUND:PlayOnce(THEME:GetPathS("MusicWheel", "change"))
		BumpWiggle(-1)
		return true
	elseif button == "MenuUp" then
		SOUND:PlayOnce(THEME:GetPathS("MusicWheel", "change"))
		BumpStages(-1)
		return true
	elseif button == "MenuDown" then
		SOUND:PlayOnce(THEME:GetPathS("MusicWheel", "change"))
		BumpStages(1)
		return true
	end
	return false
end

local function SlowestSpeedControls(button)
	if button == "MenuRight" then
		SOUND:PlayOnce(THEME:GetPathS("MusicWheel", "change"))
		BumpSlowestSpeed(-0.1)
		return true
	elseif button == "MenuLeft" then
		SOUND:PlayOnce(THEME:GetPathS("MusicWheel", "change"))
		BumpSlowestSpeed(0.1)
		return true
	end
	return false
end

local function SpecialControls(button)
	if button == "MenuLeft" then
		ToggleSampleMusic()
		return true
	elseif button == "MenuUp" then
		SOUND:PlayOnce(THEME:GetPathS("MusicWheel", "change"))
		SwitchView()
		return true
	end
	return false
end

local function input(event)
	local pn = event.PlayerNumber
	if not pn then return end
	local button = event.GameButton
	if not button then return end
	if event.type == "InputEventType_Release" then return end
	--lua.ReportScriptError(rec_print_table_to_str(event))
	if button == "Start" then
		if entering_song then
			SetupNextGame(selection_snapshot)
			setenv("NewOptions","Main")
			trans_new_screen("ScreenPlayerOptions")
			SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
		elseif #selection_snapshot > 0 then
			flowdj_config:save()
			StartNextGame(selection_snapshot)
			SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
		else
			PerformPick(flow_frame)
			SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
		end
	elseif button == "Back" then
		FlowDJ.stage = 0
		stop_music()
		flowdj_config:save()
		trans_new_screen("ScreenTitleMenu")
		SOUND:PlayOnce(THEME:GetPathS("Common", "cancel"))
	elseif button == "Select" then
		SOUND:PlayOnce(THEME:GetPathS("MusicWheel", "change"))
		SwitchControls()
	elseif current_controls == "default" and DefaultControls(button) then
	elseif current_controls == "wigglestages" and WiggleStagesControls(button) then
	elseif current_controls == "slowestspeed" and SlowestSpeedControls(button) then
	elseif current_controls == "special" and SpecialControls(button) then
	else
		lua.ReportScriptError(button)
	end
end

local function Graph(name, x, y, scale)
	return Def.ActorFrame{
		Name = name, InitCommand = function(self)
			self:xy(x - scale/2, y)
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
					if n == #points then
						data:AddChildFromPath(THEME:GetPathG("", "point.lua"))
					end
				else
					data:AddChildFromPath(THEME:GetPathG("", "point.lua"))
					data:AddChildFromPath(THEME:GetPathG("", "point.lua"))
					points = data:GetChild("point")
					if points and points[n] then
						points[n]:xy(x, 1 - y):diffuse(color)
					end
				end
			end

			self.SetLabel = function(self, text)
				self:GetChild("label"):settext(text)
			end

			self.Clear = function(self)
				self:GetChild("data"):RemoveAllChildren()
			end
		end,
		Def.ActorFrame{
			Def.Quad{
				Name= "backdrop", InitCommand = function(self)
					self:setsize(1, 1)
					self:xy(0.5, 0.5)
				end,
				OnCommand = function(self)
					self:diffuse(Alpha(Color.Black, 0.5))
				end,
			},
			Name= "background", InitCommand= function(self)
				self:visible(true)
			end,
		},
		Def.ActorFrame{
			Name= "data", InitCommand= function(self)
				self:visible(true)
			end
		},
		Def.BitmapText{
			Name = "label", Font = "Common Normal", InitCommand = function(self)
				self:settext(name)
				self:zoom(0.05*text_height/scale)
				self:xy(0.5, 1.1)
			end,
		},
	}
end

local function ModelFactors(x, y, scale)
	local names = {}
	for key,value in pairs(initial_theta) do
		table.insert(names, key)
	end
	table.sort(names)

	local frame = Def.ActorFrame{
		Name = "factors", InitCommand = function(self)
			self:xy(x, y)
			self:zoom(scale)
			self:visible(true)
		end,
	}
	for i,key in ipairs(names) do
		frame[#frame+1] = Def.ActorFrame {
			Name = key, InitCommand = function(self)
					self:xy(0, i*5)
					self:SetUpdateFunction(function(self)
						local value = self:GetChild("value")
						local v = FlowDJ.theta[key] * 20
						value:setsize(math.abs(v), 3)
						value:xy(v / 2, 0)

						if termerror[key] then
							local error = self:GetChild("error")
							local e = termerror[key] * 20
							error:setsize(math.abs(e), 3)
							error:xy(e / 2 + 20, 0)
						end

						if termcost[key] then
							local cost = self:GetChild("cost")
							local c = termcost[key] * 400
							cost:setsize(math.abs(c), 3)
							cost:xy(c / 2 + 40, 0)
						end
					end)
				end,
			Def.BitmapText{
				Name = "label", Font = "Common Normal", InitCommand = function(self)
					local zoom = 0.25
					self:settext(key)
					self:zoom(zoom)
					self:xy(-20-self:GetWidth()*0.5*zoom, 0)
				end,
			},
			Def.Quad{
				Name= "value"
			},
			Def.Quad{
				Name= "error"
			},
			Def.Quad{
				Name= "cost"
			},
		}
	end
	return frame
end

local banner_column = SCREEN_WIDTH * 0.78
local song_list_column = SCREEN_WIDTH * 0.3

local t = Def.ActorFrame{
	OnCommand = function(self)
		top_frame = self
	end,
	Def.ActorFrame{
		Name = "Picker", OnCommand = function(self)
			self:SetUpdateFunction(update)
			SCREENMAN:GetTopScreen():AddInputCallback(input)
		end,
	},
	--Graph("graph", 20, 20, math.min(SCREEN_WIDTH - 40, SCREEN_HEIGHT - 50)),
	Def.ActorFrame {
		Name = "Flow Display", OnCommand = function(self)
			flow_frame = self
			self:xy(0, SCREEN_HEIGHT)
			self:visible(true)
		end,
		Def.Sprite {
			Name="Banner",
			InitCommand = function(self)
				banner_sprite = self
				self:xy(banner_column, SCREEN_HEIGHT * 0.26)
			end,
			OnCommand= function(self)
				self:playcommand("Set")
			end,
			CurrentSongChangedMessageCommand= function(self)
				self:playcommand("Set")
			end,
			SetCommand= function(self, sel)
				if sel and sel.song then
					if sel.song:HasBanner()then
						self:LoadBanner(sel.song:GetBannerPath())
						self:visible(true)
						scale_to_fit(self, SCREEN_HEIGHT * 0.5, SCREEN_HEIGHT * 0.2)
						song_text:settext("")
					else
						self:visible(false)
						song_text:settext(DisplayNextSong(sel))
					end
				else
					self:visible(false)
					song_text:settext("")
				end
			end
		},
		Def.BitmapText{
			Name = "Song", Font = "Common Normal", InitCommand = function(self)
				song_text = self
				self:zoom(0.15*text_height)
				self:xy(banner_column, SCREEN_HEIGHT * 0.26)
			end
		},
		Def.ActorFrame{
			Name = "song list", InitCommand = function(self)
				self:xy(song_list_column, _screen.cy)
				self:zoom(SongListScale())

				self.SetSelections = function(self, selections)
					if current_controls == "default" then
						song_list_overlay:ScoreLine(mid_score)
					elseif current_controls == "slowestspeed" then
						song_list_overlay:NpsLine(slowest_speed)
					end
					self:zoom(SongListScale())
					self:xy(song_list_column, SCREEN_HEIGHT * 0.14)

					local list = self:GetChild("list")
					local items = list:GetChild("song list item")
					local length = 0
					if items then
						length = #items
					end
					-- adds one extra to try and force loading to complete before we fetch the list of children below when few selections
					for i = length,#selections do
						list:AddChildFromPath(THEME:GetPathG("", "songlistitem.lua"))
					end
					items = list:GetChild("song list item")
					for i,sel in ipairs(selections) do
						if items and items[i] then
							sel.predicted_score = PredictedScore(sel, FlowDJ.theta)
							local current = (i == FlowDJ.stage+1)
							local x = (i-1)/(stages-1)
							items[i]:StagesArrowsOff()
							if current_controls == "wigglestages" then

								items[i]:WiggleArrowsOn(current_flow.wiggle_base(x) - percent_wiggle)
							else
								items[i]:WiggleArrowsOff()
							end
							if current_controls == "slowestspeed" then
								items[i]:SlowestArrowsOn()
							else
								items[i]:SlowestArrowsOff()
							end
							if show_score_settings == true then
								items[i]:ScoreMarkOn()
							else
								items[i]:ScoreMarkOff()
							end
							items[i]:SetSelection(sel, i, x, current_flow, current)
						end
					end
					if current_controls == "wigglestages" and items[#selections] then
						items[#selections]:StagesArrowsOn()
					end
					for i = #selections+1,#items do
						items[i]:visible(false)
					end
				end
			end,
			Def.ActorFrame{
				Name= "list", InitCommand= function(self)
					self:visible(true)
				end,
			},
		},
		Def.ActorFrame{
			Name= "song list overlays", InitCommand = function(self)
				song_list_overlay = self
				self:visible(true)
				self:xy(song_list_column, SCREEN_HEIGHT * 0.53)

				self.SetLineOn = function(self)
					local overlay_line = self:GetChild("overlay setting")
					overlay_line:visible(true)
				end
				self.SetLineOff = function(self)
					local overlay_line = self:GetChild("overlay setting")
					overlay_line:visible(false)
				end
				self.ScoreLine = function(self, score)
					local scale = SongListScale()

					local overlay_line = self:GetChild("overlay setting")
					overlay_line:xy(scale * 600 * score,0)
				end
				self.NpsLine = function(self, nps)
					local scale = SongListScale()

					local overlay_line = self:GetChild("overlay setting")
					overlay_line:xy(scale * FlowDJ.NpsScale(nps),0)
				end
			end,
			Def.BitmapText{
				Name = "settings text", Font = "Common Normal", InitCommand = function(self)
					self:xy(SCREEN_WIDTH * 0.35, 0)
					self:zoom(0.05*text_height)
					settings_text = self
				end
			},
			Def.ActorFrame{
				Name= "overlay setting", InitCommand= function(self)
					self:visible(false)
				end,
				Def.Quad{
					Name= "overlay line", InitCommand = function(self)
						self:setsize(2, 0.75*SCREEN_HEIGHT)
						self:diffusealpha(0.5)
					end
				},
				Def.BitmapText{
					Name = "left arrow", Font = "Common Normal", InitCommand = function(self)
						self:visible(true)
						self:xy(-20, 0)
						self:settext("&MENULEFT;")
					end,
				},
				Def.BitmapText{
					Name = "right arrow", Font = "Common Normal", InitCommand = function(self)
						self:visible(true)
						self:xy(20, 0)
						self:settext("&MENURIGHT;")
					end,
				},
			},
			--Graph("curve graph", 900*SongListScale(), -0.5*0.75*SCREEN_HEIGHT, 0.75*SCREEN_HEIGHT),
		},
	},
	Def.ActorFrame {
		Name = "model", InitCommand = function(self)
			model_frame = self
			self:xy(_screen.cx - SCREEN_WIDTH * 0.2, _screen.cy)
			self:visible(true)
		end,
		Graph("graph", SCREEN_WIDTH * 0.2, SCREEN_HEIGHT * -0.32, SCREEN_HEIGHT * 0.62),
		ModelFactors(SCREEN_WIDTH * -0.1, SCREEN_HEIGHT*-0.36, SCREEN_HEIGHT * 0.004),
		Def.Quad{
			Name= "cost", InitCommand = function(self)
				cost_quad = self
				self:xy(SCREEN_WIDTH * 0.2, SCREEN_HEIGHT * 0.4)
			end
		},
		Def.BitmapText{
			Name = "model x axis label", Font = "Common Normal", InitCommand = function(self)
				self:visible(true)
				self:xy(SCREEN_WIDTH * 0.2, SCREEN_HEIGHT * 0.32)
				self:settext("actual score")
			end,
		},
		Def.BitmapText{
			Name = "model y axis label", Font = "Common Normal", InitCommand = function(self)
				self:visible(true)
				self:xy(SCREEN_WIDTH * 0.015, 0)
				self:rotationz(270)
				self:settext("estimated score")
			end,
		},
	},
	Def.ActorFrame{
		Name = "help text", InitCommand = function(self)
			help_text = self
			self:zoom(0.07*text_height)
			self:xy(_screen.cx, SCREEN_HEIGHT - 30)
		end,
		Def.BitmapText{
			Name = "training help text", Font = "Common Normal", InitCommand = function(self)
				self:settext(Screen.String("TrainingHelpText"))
				self:visible(false)
			end,
		},
		Def.BitmapText{
			Name = "default help text", Font = "Common Normal", InitCommand = function(self)
				self:settext(Screen.String("DefaultHelpText"))
				self:visible(false)
			end,
		},
		Def.BitmapText{
			Name = "wigglestages help text", Font = "Common Normal", InitCommand = function(self)
				self:settext(Screen.String("WiggleStagesHelpText"))
				self:visible(false)
			end,
		},
		Def.BitmapText{
			Name = "slowestspeed help text", Font = "Common Normal", InitCommand = function(self)
				self:settext(Screen.String("SlowestSpeedHelpText"))
				self:visible(false)
			end,
		},
		Def.BitmapText{
			Name = "special help text", Font = "Common Normal", InitCommand = function(self)
				self:settext(Screen.String("SpecialHelpText"))
				self:visible(false)
			end,
		},
	},
	Def.BitmapText{
		Name = "Center", Font = "Common Normal", InitCommand = function(self)
			center_text = self
			self:zoom(0.15*text_height)
			self:xy(_screen.cx, _screen.cy)
		end
	},
	Def.BitmapText{
		Name = "Left", Font = "Common Normal", InitCommand = function(self)
			left_text = self
			self:maxwidth(SCREEN_HEIGHT)
			self:zoom(0.1*text_height)
			self:xy(_screen.cx - SCREEN_WIDTH/4, _screen.cy)
		end
	},
	Def.BitmapText{
		Name = "Right", Font = "Common Normal", InitCommand = function(self)
			right_text = self
			self:maxwidth(SCREEN_HEIGHT)
			self:zoom(0.1*text_height)
			self:xy(_screen.cx + SCREEN_WIDTH/4 + 50, _screen.cy)
		end
	},
	Def.BitmapText{
		Name = "Stage", Font = "Common Normal", InitCommand = function(self)
			self:xy(_screen.cx, 40)
			self:zoom(0.1*text_height)
			self:settext(string.format("Stage %d", (STATSMAN:GetStagesPlayed() + 1)))
		end
	},
	Def.BitmapText{
		Name = "Total Stages", Font = "Common Normal", InitCommand = function(self)
			self:xy(_screen.cx, 70)
			self:zoom(0.05*text_height)
			self:settext(string.format("%d Stages", stages))
			stages_text = self
		end
	},
	Def.BitmapText{
		Name = "Player Options", Font = "Common Normal", InitCommand = function(self)
			self:xy(300, 50)
			self:zoom(0.05*text_height)
			self:settext(player_options)
		end
	},
}

return t
