--- @since 26.1.22

local M = {}

function M.is_valid_utf8(str)
	return utf8.len(str) ~= nil
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
