local pn = GAMESTATE:GetEnabledPlayers()[1]

local function input(event)
	local pn= event.PlayerNumber
	if not pn then return end
	local button= event.GameButton
	if not button then return end
	if event.type == "InputEventType_Release" then return end
	if button == "Start" then
		trans_new_screen("ScreenFlowDJPick")
		return
	end
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
