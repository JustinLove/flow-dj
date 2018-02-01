local spacing = 25
local bar_height = 8
local bar_width = 3

return Def.ActorFrame {
	Name = "song list item", InitCommand = function(self)
			self.SetSelection = function(self, sel, n)
				self:xy(0, n*spacing)
				local label = self:GetChild("label")
				label:settext(sel.song:GetDisplayMainTitle())
				label:xy(-20-label:GetWidth()*0.5, 0)
				local value = self:GetChild("value")
				value:setsize(sel.meter * bar_width, bar_height)
				value:xy(sel.meter * bar_width / 2, 0)
			end
		end,
	Def.BitmapText{
		Name = "label", Font = "Common Normal", InitCommand = function(self)
		end,
	},
	Def.Quad{
		Name= "value"
	},
}
