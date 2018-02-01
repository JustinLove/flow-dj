local spacing = 60
local bar_height = 8
local bar_width = 45

return Def.ActorFrame {
	Name = "song list item", InitCommand = function(self)
			self.SetSelection = function(self, sel, n)
				self:xy(0, n*spacing)

				local x = 0
				local y = -spacing * 0.2

				local label = self:GetChild("label")
				label:settext(sel.song:GetDisplayMainTitle())
				label:xy(x, y)

				x = - (30 + bar_width + 40 + bar_width + 40 + bar_width)/2
				y = spacing * 0.2

				x = x + 30
				local meter_text = self:GetChild("meter text")
				meter_text:settext(sel.meter)
				meter_text:xy(x - meter_text:GetWidth()*0.5, y)

				x = x + 5 
				local meter_bar = self:GetChild("meter bar")
				meter_bar:setsize(sel.meter / 15 * bar_width, bar_height)
				meter_bar:xy(x + sel.meter / 15 * bar_width / 2, y)
				x = x + bar_width

				x = x + 40
				local nps_text = self:GetChild("nps text")
				nps_text:settextf("%0.1f", sel.nps)
				nps_text:xy(x - nps_text:GetWidth()*0.5, y)

				x = x + 5 
				local nps_bar = self:GetChild("nps bar")
				nps_bar:setsize(sel.nps / 10 * bar_width, bar_height)
				nps_bar:xy(x + sel.nps / 10 * bar_width / 2, y)
				x = x + bar_width

				x = x + 40
				local score_text = self:GetChild("score text")
				score_text:settextf("%2d", sel.effective_score * 100)
				score_text:xy(x - score_text:GetWidth()*0.5, y)

				x = x + 5 
				local score_bar = self:GetChild("score bar")
				score_bar:setsize(sel.effective_score * bar_width, bar_height)
				score_bar:xy(x + sel.effective_score * bar_width / 2, y)
				x = x + bar_width

			end
		end,
	Def.BitmapText{
		Name = "label", Font = "Common Normal", InitCommand = function(self)
		end,
	},
	Def.BitmapText{
		Name = "meter text", Font = "Common Normal", InitCommand = function(self)
		end,
	},
	Def.Quad{
		Name= "meter bar"
	},
	Def.BitmapText{
		Name = "nps text", Font = "Common Normal", InitCommand = function(self)
		end,
	},
	Def.Quad{
		Name= "nps bar"
	},
	Def.BitmapText{
		Name = "score text", Font = "Common Normal", InitCommand = function(self)
		end,
	},
	Def.Quad{
		Name= "score bar"
	},
}
