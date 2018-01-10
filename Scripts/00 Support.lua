function trans_new_screen(name)
	SCREENMAN:GetTopScreen():SetNextScreenName(name)
	SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen")
end

function rec_print_table_to_str(t, indent, depth_remaining)
	if not indent then indent= "" end
	if type(t) ~= "table" then
		return indent .. "rec_print_table passed a " .. type(t)
	end
	depth_remaining= depth_remaining or -1
	if depth_remaining == 0 then return "" end
	local lines= {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			table.insert(lines, indent .. k .. ": table")
			table.insert(lines, rec_print_table_to_str(
										 v, indent .. "  ", depth_remaining - 1))
		else
			table.insert(lines, indent .. "(" .. type(k) .. ")" .. k .. ": " ..
							"(" .. type(v) .. ")" .. tostring(v) .. "")
		end
	end
	table.insert(lines, indent .. "end")
	return table.concat(lines, "\n")
end
