FlowDJ = {
	stage = 0,
	seed = math.random(),
	offset = math.random(0,math.pi),
	scale = math.random(1,3),
	theta = {},
	fake_play = false,
	manual_songs = {},
	flow_width = 600,
	NpsScale = function(x) return (x * -0.09 + 1) * FlowDJ.flow_width end,
}
