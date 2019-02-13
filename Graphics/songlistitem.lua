local spacing = 60
local bar_height = 8
local bar_width = 45
local flow_height = 48
local flow_width = 600
local flow_baseline = 600
local flow_scale = -0.09
local flow_mark = 12
local data_width = (30 + bar_width + 40 + bar_width)
local text_width = 300

return Def.ActorFrame {
	Name = "song list item", InitCommand = function(self)
			self.SetSelection = function(self, sel, n, flow, range, current)
				self:xy(0, n*spacing)
				self:visible(true)

				local brightness = 0.5
				if current then
					brightness = 1
				end

				local x = flow_width
				local y = -spacing * 0.2

				x = x + 30
				local meter_text = self:GetChild("meter text")
				meter_text:settext(sel.meter)
				meter_text:xy(x - meter_text:GetWidth()*0.5, y)

				x = x + 5 
				local meter_bar = self:GetChild("meter bar")
				meter_bar:setsize(sel.meter / 15 * bar_width, bar_height)
				meter_bar:xy(x + sel.meter / 15 * bar_width / 2, y)
				x = x + bar_width

				x = flow_width
				y = spacing * 0.2

				x = x + 55
				local nps_text = self:GetChild("nps text")
				nps_text:settextf("%0.1f", sel.nps)
				nps_text:xy(x - nps_text:GetWidth()*0.5, y)

				x = x + 5 
				local nps_bar = self:GetChild("nps bar")
				nps_bar:setsize(sel.nps / 10 * bar_width, bar_height)
				nps_bar:xy(x + sel.nps / 10 * bar_width / 2, y)
				x = x + bar_width

				x = 0
				y = -spacing * 0.2
				local title = self:GetChild("title")
				title:settext(sel.song:GetDisplayFullTitle())
				title:xy(x + 10 + title:GetWidth()*0.5, y)

				x = 10
				y = spacing * 0.2
				local artist = self:GetChild("artist")
				artist:settext(sel.song:GetDisplayArtist())
				artist:xy(x + 10 + artist:GetWidth()*0.5, y)

				x = -50
				y = -spacing * 0.2
				local group = self:GetChild("group")
				group:settext(sel.song:GetGroupName())
				group:xy(x + 10 - group:GetWidth()*0.5, y)

				x = -60
				y = spacing * 0.2
				local author = self:GetChild("step author")
				author:settext(sel.steps:GetAuthorCredit())
				author:xy(x + 10 - author:GetWidth()*0.5, y)

				local flow_backdrop = self:GetChild("flow backdrop")
				flow_backdrop:setsize(flow_width, flow_height)
				if SL then
					flow_backdrop:diffuserightedge(Alpha(Color.White, 0.4))
					flow_backdrop:diffuseleftedge(Alpha(Color.White, 0.1))
				else
					flow_backdrop:diffuserightedge(Alpha(Color.Black, 0.5))
					flow_backdrop:diffuseleftedge(Alpha(Color.Black, 0.1))
				end

				local group_backdrop = self:GetChild("group backdrop")
				group_backdrop:setsize(flow_width, flow_height)
				if SL then
					group_backdrop:diffuserightedge(Alpha(Color.Black, 0.4))
					group_backdrop:diffuseleftedge(Alpha(Color.Black, 0.00))
				else
					group_backdrop:diffuserightedge(Alpha(Color.Black, 0.5))
					group_backdrop:diffuseleftedge(Alpha(Color.Black, 0.00))
				end

				local flow_range = self:GetChild("flow range")
				flow_range:setsize(range * 2 * flow_width, flow_height)
				flow_range:xy(flow * flow_width * flow_scale + flow_baseline, 0)
				flow_range:diffuse(Brightness(Color.White, 0.5 * brightness))
				if current then
					flow_range:glowshift()
					flow_range:effectcolor1(Brightness(Color.White, 0.6))
					flow_range:effectcolor2(Brightness(Color.White, 0.8))
					flow_range:effectperiod(2)
				end

				local nps_mark = self:GetChild("nps mark")
				nps_mark:setsize(flow_mark, flow_height)
				nps_mark:xy(sel.nps * flow_width * flow_scale + flow_baseline, 0)
				nps_mark:diffuse(Brightness(Color.Red, brightness))
				if current then
					nps_mark:glowshift()
					nps_mark:effectcolor1(Brightness(Color.Red, 0.8))
					nps_mark:effectcolor2(Brightness(Color.Red, 1.0))
					nps_mark:effectperiod(2)
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

				local score_text = self:GetChild("score text")
				score_text:settextf("%2d", sel.effective_score * 100)
				score_text:xy(flow_width - 10 - score_text:GetWidth()*0.5, 0)

			end

			self.DifficultyArrowsOn = function(self, flow, range)
				local left_arrow = self:GetChild("left arrow")
				left_arrow:xy((flow * flow_scale + 1 - range * 2) * flow_width, 0)
				left_arrow:visible(true)
				local right_arrow = self:GetChild("right arrow")
				right_arrow:xy((flow * flow_scale + 1 + range * 2) * flow_width, 0)
				right_arrow:visible(true)
			end

			self.DifficultyArrowsOff = function(self)
				local left_arrow = self:GetChild("left arrow")
				left_arrow:visible(false)
				local right_arrow = self:GetChild("right arrow")
				right_arrow:visible(false)
			end

			self.StagesArrowsOn = function(self)
				local up_arrow = self:GetChild("up arrow")
				up_arrow:xy(flow_width, -spacing)
				up_arrow:visible(true)
				local down_arrow = self:GetChild("down arrow")
				down_arrow:xy(flow_width, spacing)
				down_arrow:visible(true)
			end

			self.StagesArrowsOff = function(self)
				local up_arrow = self:GetChild("up arrow")
				up_arrow:visible(false)
				local down_arrow = self:GetChild("down arrow")
				down_arrow:visible(false)
			end

		end,
	Def.Quad{
		Name= "flow backdrop", InitCommand = cmd(setsize, 0, 0; xy, flow_width/2, 0),
	},
	Def.Quad{
		Name= "group backdrop", InitCommand = cmd(setsize, 0, 0; xy, -flow_width/2 - 30, 0),
	},
	Def.BitmapText{
		Name = "up arrow", Font = "Common Normal", InitCommand = cmd(visible, false; settext, "&MENUUP;"; zoom, 2),
	},
	Def.BitmapText{
		Name = "down arrow", Font = "Common Normal", InitCommand = cmd(visible, false; settext, "&MENUDOWN;"; zoom, 2),
	},
	Def.Quad{
		Name= "flow range"
	},
	Def.BitmapText{
		Name = "left arrow", Font = "Common Normal", InitCommand = cmd(visible, false; settext, "&MENULEFT;"),
	},
	Def.BitmapText{
		Name = "right arrow", Font = "Common Normal", InitCommand = cmd(visible, false; settext, "&MENURIGHT;"),
	},
	Def.Quad{
		Name= "nps mark"
	},
	Def.Quad{
		Name= "predicted score"
	},
	Def.Quad{
		Name= "actual score"
	},
	Def.BitmapText{
		Name = "title", Font = "Common Normal"
	},
	Def.BitmapText{
		Name = "artist", Font = "Common Normal"
	},
	Def.BitmapText{
		Name = "group", Font = "Common Normal"
	},
	Def.BitmapText{
		Name = "step author", Font = "Common Normal"
	},
	Def.BitmapText{
		Name = "score text", Font = "Common Normal"
	},
	Def.BitmapText{
		Name = "meter text", Font = "Common Normal"
	},
	Def.Quad{
		Name= "meter bar"
	},
	Def.BitmapText{
		Name = "nps text", Font = "Common Normal"
	},
	Def.Quad{
		Name= "nps bar"
	},
}
