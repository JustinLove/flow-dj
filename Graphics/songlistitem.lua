local spacing = 60
local bar_height = 8
local bar_width = 45
local flow_height = 32
local flow_width = 400
local flow_mark = 8
local text_width = (30 + bar_width + 40 + bar_width + 40 + bar_width)

return Def.ActorFrame {
	Name = "song list item", InitCommand = function(self)
			self.SetSelection = function(self, sel, n, flow, range, current)
				self:xy(0, n*spacing)

				local brightness = 0.5
				if current then
					brightness = 1
				end
				local x = flow_width
				local y = -spacing * 0.2

				local label = self:GetChild("label")
				label:settext(sel.song:GetDisplayMainTitle())
				label:xy(x + text_width/2, y)

				y = spacing * 0.2

				x = x + 40
				local score_text = self:GetChild("score text")
				score_text:settextf("%2d", sel.effective_score * 100)
				score_text:xy(x - score_text:GetWidth()*0.5, y)

				x = x + 5 
				local score_bar = self:GetChild("score bar")
				score_bar:setsize(sel.effective_score * bar_width, bar_height)
				score_bar:xy(x + sel.effective_score * bar_width / 2, y)
				x = x + bar_width

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

				local flow_backdrop = self:GetChild("flow backdrop")
				flow_backdrop:setsize(flow_width, flow_height)
				flow_backdrop:diffuserightedge(Alpha(Color.Black, 0.5))
				flow_backdrop:diffuseleftedge(Alpha(Color.Black, 0.03))

				local flow_range = self:GetChild("flow range")
				flow_range:setsize(range * 2 * flow_width, flow_height)
				flow_range:xy(flow * flow_width, 0)
				flow_range:diffuse(Brightness(Color.White, 0.5 * brightness))
				if current then
					flow_range:glowshift()
					flow_range:effectcolor1(Brightness(Color.White, 0.6))
					flow_range:effectcolor2(Brightness(Color.White, 0.8))
					flow_range:effectperiod(2)
				end

				local predicted_score = self:GetChild("predicted score")
				predicted_score:setsize(flow_mark, flow_height)
				predicted_score:xy(sel.predicted_score * flow_width, 0)
				predicted_score:diffuse(Brightness(Color.Blue, brightness))
				if current then
					predicted_score:glowshift()
					predicted_score:effectcolor1(Brightness(Color.Blue, 0.8))
					predicted_score:effectcolor2(Brightness(Color.Blue, 1.0))
					predicted_score:effectperiod(2)
				end

				if sel.score ~= 0 then
					local actual_score = self:GetChild("actual score")
					actual_score:setsize(flow_mark, flow_height)
					actual_score:xy(sel.score * flow_width, 0)
					actual_score:diffuse(Brightness(Color.White, brightness))
					if current then
						actual_score:glowshift()
						actual_score:effectcolor1(Brightness(Color.White, 0.8))
						actual_score:effectcolor2(Brightness(Color.White, 1.0))
						actual_score:effectperiod(2)
					end
				end

			end
		end,
	Def.Quad{
		Name= "flow backdrop", InitCommand = cmd(setsize, 0, 0; xy, flow_width/2, 0),
	},
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
	Def.Quad{
		Name= "flow range"
	},
	Def.Quad{
		Name= "actual score"
	},
	Def.Quad{
		Name= "predicted score"
	},
}
