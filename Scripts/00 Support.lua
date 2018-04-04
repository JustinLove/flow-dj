-- Most of this is borrowed from kyzentun's consensual

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

function WaitForStart(event)
	local pn= event.PlayerNumber
	if not pn then return end
	local button= event.GameButton
	if not button then return end
	if event.type == "InputEventType_Release" then return end
	if button == "Start" then
		return true
	else
		return false
	end
end

function string_needs_escape(str)
	if str:match("^[a-zA-Z_][a-zA-Z_0-9]*$") then
		return false
	else
		return true
	end
end

function lua_table_to_string(t, indent, line_pos)
	indent= indent or ""
	line_pos= (line_pos or #indent) + 1
	local internal_indent= indent .. "  "
	local ret= "{"
	local has_table= false
	for k, v in pairs(t) do if type(v) == "table" then has_table= true end
	end
	if has_table then
		ret= "{\n" .. internal_indent
		line_pos= #internal_indent
	end
	local separator= ""
	local function do_value_for_key(k, v, need_key_str)
		if type(v) == "nil" then return end
		local k_str= k
		if type(k) == "number" then
			k_str= "[" .. k .. "]"
		else
			if string_needs_escape(k) then
				k_str= "[" .. ("%q"):format(k) .. "]"
			else
				k_str= k
			end
		end
		if need_key_str then
			k_str= k_str .. "= "
		else
			k_str= ""
		end
		local v_str= ""
		if type(v) == "table" then
			v_str= lua_table_to_string(v, internal_indent, line_pos + #k_str)
		elseif type(v) == "string" then
			v_str= ("%q"):format(v)
		elseif type(v) == "number" then
			if v ~= math.floor(v) then
				v_str= ("%.6f"):format(v)
				local last_nonz= v_str:reverse():find("[^0]")
				if last_nonz then
					v_str= v_str:sub(1, -last_nonz)
				end
			else
				v_str= tostring(v)
			end
		else
			v_str= tostring(v)
		end
		local to_add= k_str .. v_str
		if type(v) == "table" then
			if separator == "" then
				to_add= separator .. to_add
			else
				to_add= separator .."\n" .. internal_indent .. to_add
			end
		else
			if line_pos + #separator + #to_add > 80 then
				line_pos= #internal_indent + #to_add
				to_add= separator .. "\n" .. internal_indent .. to_add
			else
				to_add= separator .. to_add
				line_pos= line_pos + #to_add
			end
		end
		ret= ret .. to_add
		separator= ", "
	end
	-- do the integer indices from 0 to n first, in order.
	do_value_for_key(0, t[0], true)
	for n= 1, #t do
		do_value_for_key(n, t[n], false)
	end
	for k, v in pairs(t) do
		local is_integer_key= (type(k) == "number") and (k == math.floor(k)) and k >= 0 and k <= #t
		if not is_integer_key then
			do_value_for_key(k, v, true)
		end
	end
	ret= ret .. "}"
	return ret
end

function save_lua_table(fname, table)
	local file_handle= RageFileUtil.CreateRageFile()
	if not file_handle:Open(fname, 2) then
		Warn("Could not open '" .. fname .. "' to write a table.")
	else
		local output= "return " .. lua_table_to_string(table)
		file_handle:Write(output)
		file_handle:Close()
		file_handle:destroy()
	end
end

function load_config_lua(fname)
	local file= RageFileUtil.CreateRageFile()
	local ret= {}
	if file:Open(fname, 1) then
		local data= loadstring(file:Read())
		setfenv(data, {})
		local success, data_ret= pcall(data)
		if success then
			ret= data_ret
		end
		file:Close()
	end
	file:destroy()
	return ret
end

-- from default
if not scale_to_fit then
	function scale_to_fit(actor, width, height)
		local xscale= width / actor:GetWidth()
		local yscale= height / actor:GetHeight()
		actor:zoom(math.min(xscale, yscale))
	end
end
