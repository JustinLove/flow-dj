local function OptionNameString(str)
	return THEME:GetString('OptionNames',str)
end

local stage_choices = {}
local stage_values = {}
for i = 1,100 do
	stage_choices[i] = ""..i
	stage_values[i] = i
end

local score_choices = {}
local score_values = {}
for i = 1,101 do
	score_choices[i] = ""..(i-1)
	score_values[i] = i-1
end

local Prefs =
{
	NumberOfStages =
	{
		Default = 16,
		Choices = stage_choices,
		Values = stage_values,
		SelectType = "ShowOneInRow",
	},
	StartScore =
	{
		Default = 85,
		Choices = score_choices,
		Values = score_values,
		SelectType = "ShowOneInRow",
	},
	MidScore =
	{
		Default = 70,
		Choices = score_choices,
		Values = score_values,
		SelectType = "ShowOneInRow",
	},
	ScoreWiggle =
	{
		Default = 5,
		Choices = score_choices,
		Values = score_values,
		SelectType = "ShowOneInRow",
	},
}

ThemePrefs.InitAll(Prefs)
