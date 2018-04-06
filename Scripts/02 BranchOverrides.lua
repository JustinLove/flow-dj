local function StagesRemaining()
	if not FlowDJ.fake_play then
		FlowDJ.stage = GAMESTATE:GetCurrentStageIndex()
	end
	local stages = FlowDJGetSetting("NumberOfStages")
	return FlowDJ.stage < stages
end

local BaseSelectMusicOrCourse = SelectMusicOrCourse
function SelectMusicOrCourse()
	if IsNetSMOnline() then
		return BaseSelectMusicOrCourse()
	elseif GAMESTATE:IsCourseMode() then
		return BaseSelectMusicOrCourse()
	else
		if StagesRemaining() then
			return "ScreenFlowDJPick"
		else
			return GameOverOrContinue()
		end
	end
end

local BasePlayerOptions = Branch.PlayerOptions
Branch.PlayerOptions = function()
	song = GAMESTATE:GetCurrentSong()
	table.insert(FlowDJ.manual_songs, song:GetMusicPath())
	return "ScreenFlowDJPick"
end

local BaseAfterGameplay = Branch.AfterGameplay
Branch.AfterGameplay = function()
	if StagesRemaining() then
		return "ScreenProfileSave"
	else
		return Branch.EvaluationScreen()
	end
end

local BaseAfterProfileSave = Branch.AfterProfileSave
Branch.AfterProfileSave = function()
	if StagesRemaining() then
		return "ScreenFlowDJPick"
	else
		return "ScreenEvaluationSummary"
	end
end

local BaseAfterSelectProfile = Branch.AfterSelectProfile
Branch.AfterSelectProfile = function()
	GAMESTATE:SetCurrentPlayMode('PlayMode_Regular')
	FlowDJ.stage = 0
	return SelectMusicOrCourse()
end

local BaseAfterProfileLoad = Branch.AfterProfileLoad
Branch.AfterProfileLoad = function()
	GAMESTATE:SetCurrentPlayMode('PlayMode_Regular')
	FlowDJ.stage = 0
	return SelectMusicOrCourse()
end

local BaseAfterScreenSelectColor = Branch.AfterScreenSelectColor
Branch.AfterScreenSelectColor = function()
	GAMESTATE:SetCurrentPlayMode('PlayMode_Regular')
	FlowDJ.stage = 0
	BaseAfterScreenSelectColor()
	return "ScreenFlowDJPick"
end

ModeIconColors["FlowDJ"] = color("#b4c3d2") -- steel
