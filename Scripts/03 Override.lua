local function StagesRemaining()
	local stage = GAMESTATE:GetCurrentStageIndex()
	local stages = ThemePrefs.Get("NumberOfStages")
	return stage < stages
end

function SelectMusicOrCourse()
	lua.ReportScriptError("Running custom select next")
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
	if StagesRemaining() then
		return "ScreenFlowDJPick"
	else
		return BaseAfterGameplay()
	end
end

local BaseAfterSelectProfile = Branch.AfterSelectProfile
Branch.AfterSelectProfile = function()
	GAMESTATE:SetCurrentPlayMode('PlayMode_Regular')
	return "ScreenFlowDJPick"
end

local BaseAfterProfileLoad = Branch.AfterProfileLoad
Branch.AfterProfileLoad = function()
	GAMESTATE:SetCurrentPlayMode('PlayMode_Regular')
	return "ScreenFlowDJPick"
end

ModeIconColors["FlowDJ"] = color("#b4c3d2") -- steel
