local pn = GAMESTATE:GetEnabledPlayers()[1]
local stepstype = GAMESTATE:GetCurrentStyle(pn):GetStepsType()

setenv("FlowDJ", true)

local function SetupNextGame()
	local all_songs = SONGMAN:GetAllSongs()
	local song = all_songs[1]
	local song_steps = song:GetStepsByStepsType(stepstype)
	local steps = song_steps[1]
	GAMESTATE:SetCurrentSong(song)
	GAMESTATE:SetCurrentSteps(pn, steps)
end

local function update()
	SetupNextGame()
	trans_new_screen("ScreenGameplay")
end

return Def.ActorFrame{
	Def.ActorFrame{
		Name = "Picker", OnCommand = function(self)
			self:SetUpdateFunction(update)
		end,
		Def.BitmapText{
			Name = "Notice", Font = "Common Normal", InitCommand = function(self)
				self:xy(_screen.cx, _screen.cy)
			end
		}
	}
}
