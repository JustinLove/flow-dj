local flowdj_default_config = {
	NumberOfStages = 16,
	StartScore = 85,
	MidScore = 70,
	ScoreWiggle = 5,
	PlayerOptions = "C250,FailOff,Overhead",
	SampleMusic = false,
}

flowdj_config = create_lua_config {
	name = "flowdj_config",
	file = "flowdj_config.lua",
	default = flowdj_default_config,
	use_alternate_config_prefix = nil,
	exceptions = {},
}

flowdj_config:load()
add_standard_lua_config_save_load_hooks(flowdj_config)

function FlowDJGetSetting(setting)
	return flowdj_config:get_data()[setting]
end

function FlowDJSetSetting(setting, value)
	flowdj_config:get_data()[setting] = value
	flowdj_config:set_dirty()
end

function CapturePlayerOptions()
	local pn = GAMESTATE:GetEnabledPlayers()[1]
	local player_state = GAMESTATE:GetPlayerState(pn)
	local player_options = player_state:GetPlayerOptionsString("ModsLevel_Current")
	FlowDJSetSetting("PlayerOptions", player_options)
end
