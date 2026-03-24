--- @since 26.1.22

local M = {}

function M.is_valid_utf8(str)
	return utf8.len(str) ~= nil
end

function M.utf8_sub(str, start_char, end_char)
	local start_byte = utf8.offset(str, start_char) -- Expects start_char to be a character index
	local end_byte = end_char and (utf8.offset(str, end_char + 1) or (#str + 1)) - 1 -- Expects end_char
	if not start_byte then
		return ""
	end
	return str:sub(start_byte, end_byte)
end
function M.is_literal_string(str)
	return str and str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end
function M.path_quote(path)
	if not path or tostring(path) == "" then
		return path
	end
	local result = "'" .. string.gsub(tostring(path), "'", "'\\''") .. "'"
	return result
end

function M.read_mediainfo_cached_file(file_path)
	-- Open the file in read mode
	local file = io.open(file_path, "r")

	if file then
		-- Read the entire file content
		local content = file:read("*all")
		file:close()
		return content
	end
end

M.force_render = ya.sync(function(_, _)
	(ui.render or ya.render)()
end)

M.set_state = ya.sync(function(state, key, value)
	state[key] = value
end)

M.get_state = ya.sync(function(state, key)
	return state[key]
end)

return M
