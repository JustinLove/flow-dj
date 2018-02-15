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
	elseif FlowDJ.enabled == true then
		if StagesRemaining() then
			return "ScreenFlowDJPick"
		else
			return GameOverOrContinue()
		end
	else
		return "ScreenSelectMusic"
	end
end

local BaseAfterGameplay = Branch.AfterGameplay
Branch.AfterGameplay = function()
	if FlowDJ.enabled == true and StagesRemaining() then
		return "ScreenFlowDJPick"
	else
		return BaseAfterGameplay()
	end
end

ModeIconColors["FlowDJ"] = color("#b4c3d2") -- steel
