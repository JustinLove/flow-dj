local function StagesRemaining()
	if not FlowDJ.fake_play then
		FlowDJ.stage = GAMESTATE:GetCurrentStageIndex()
	end
	local stages = FlowDJGetSetting("NumberOfStages")
	return FlowDJ.stage < stages
end

function SelectMusicOrCourse()
	rec_print_table(envTable)
	if IsNetSMOnline() then
		return "ScreenNetSelectMusic"
	elseif GAMESTATE:IsCourseMode() then
		return "ScreenSelectCourse"
	else
		if StagesRemaining() then
			return "ScreenFlowDJPick"
		else
			return GameOverOrContinue()
		end
	end
end

local BaseAfterGameplay = Branch.AfterGameplay
Branch.AfterGameplay = function()
	CapturePlayerOptions()
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

ModeIconColors["FlowDJ"] = color("#b4c3d2") -- steel
