local pn = GAMESTATE:GetEnabledPlayers()[1]

local function input()
	trans_new_screen("ScreenFlowDJPick")
end

return Def.ActorFrame{
	Def.ActorFrame{
		Name = "Bouncer", OnCommand = function(self)
			SCREENMAN:GetTopScreen():AddInputCallback(input)
		end,
	},
	Def.BitmapText{
		Name = "Notice", Font = "Common Normal", InitCommand = function(self)
			debug_text = self
			self:xy(_screen.cx, _screen.cy)
		end,
		OnCommand=function(self)
			local song = GAMESTATE:GetCurrentSong()
			local steps = GAMESTATE:GetCurrentSteps(pn)
			local stage = GAMESTATE:GetCurrentStageIndex()
			self:settext(
				song:GetMainTitle() .. "\n" ..
				steps:GetMeter() .. "\n" ..
				stage)
		end,
	},
}
