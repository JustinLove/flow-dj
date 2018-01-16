function SelectMusicOrCourse()
	lua.ReportScriptError("Running custom select next")
	rec_print_table(envTable)
	if IsNetSMOnline() then
		return "ScreenNetSelectMusic"
	elseif GAMESTATE:IsCourseMode() then
		return "ScreenSelectCourse"
	elseif flow_dj_enabled == true then
		return "ScreenFlowDJPick"
	else
		return "ScreenSelectMusic"
	end
end

ModeIconColors["FlowDJ"] = color("#b4c3d2") -- steel
