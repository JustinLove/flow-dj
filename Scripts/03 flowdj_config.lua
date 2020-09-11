local flowdj_default_config = {
	NumberOfStages = 16,
	StartScore = 85,
	MidScore = 60,
	PercentWiggle = 20,
	SampleMusic = false,
	SlowestSpeed = 3.5,
}

flowdj_config = create_lua_config {
	name = "flowdj_config",
	file = "flowdj_config.lua",
	default = flowdj_default_config,
	use_alternate_config_prefix = nil,
	exceptions = {},
}

flowdj_theta = create_lua_config {
	name = "flowdj_theta",
	file = "flowdj_theta.lua",
	default = {},
	match_depth = 0,
	use_alternate_config_prefix = nil,
	exceptions = {},
}

flowdj_config:load()
add_standard_lua_config_save_load_hooks(flowdj_config)
flowdj_theta:load()
add_standard_lua_config_save_load_hooks(flowdj_theta)

function FlowDJGetSetting(setting)
	return flowdj_config:get_data('PlayerNumber_P1')[setting] or flowdj_default_config[setting]
end

function FlowDJSetSetting(setting, value)
	flowdj_config:get_data('PlayerNumber_P1')[setting] = value
	flowdj_config:set_dirty('PlayerNumber_P1')
end

function FlowDJGetTheta(theta)
	--lua.ReportScriptError(rec_print_table_to_str(flowdj_theta:get_data('PlayerNumber_P1')))
	local loaded = flowdj_theta:get_data('PlayerNumber_P1')
	for key,value in pairs(theta) do
		theta[key] = loaded[key]
	end
end

function FlowDJSetTheta(theta)
	for key,value in pairs(FlowDJ.theta) do
		flowdj_theta:get_data('PlayerNumber_P1')[key] = value
	end
	flowdj_theta:set_dirty('PlayerNumber_P1')
end
