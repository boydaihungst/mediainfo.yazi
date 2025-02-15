--- @since 25.2.7

local skip_labels = {
	["Complete name"] = true,
	["CompleteName_Last"] = true,
	["Unique ID"] = true,
	["File size"] = true,
	["Format/Info"] = true,
	["Codec ID/Info"] = true,
	["MD5 of the unencoded content"] = true,
}

local magick_image_mimes = {
	avif = true,
	hei = true,
	heic = true,
	heif = true,
	["heif-sequence"] = true,
	["heic-sequence"] = true,
	jxl = true,
	svg = true,
	xml = true,
}

local M = {}
local suffix = "_mediainfo"

local function read_mediainfo_cached_file(file_path)
	-- Open the file in read mode
	local file = io.open(file_path, "r")

	if file then
		-- Read the entire file content
		local content = file:read("*all")
		file:close()
		return content
	end
end

function M:peek(job)
	local start = os.clock()
	local cache_img_url_no_skip = ya.file_cache({ file = job.file, skip = 0 })
	if not job.mime then
		return
	end
	local cache_img_url = (string.find(job.mime, "^video/") and ya.file_cache(job))
		or ((string.find(job.mime, "^audio/") or string.find(job.mime, "^image/")) and cache_img_url_no_skip)

	local ok, err = self:preload(job)
	if not ok or err then
		return
	end

	local cache_mediainfo_path = tostring(cache_img_url_no_skip) .. suffix
	ya.sleep(math.max(0, PREVIEW.image_delay / 1000 + start - os.clock()))
	local output = read_mediainfo_cached_file(cache_mediainfo_path)

	local lines = {}

	if output then
		local i = 0
		for str in output:gmatch("[^\n]*") do
			local label, value = str:match("(.*[^ ])  +: (.*)")
			local line

			if label then
				if not skip_labels[label] then
					line = ui.Line({
						ui.Span(label .. ": "):style(ui.Style():bold()),
						ui.Span(value):style(ui.Style():fg("blue")),
					})
				end
			elseif str ~= "General" then
				line = ui.Line({ ui.Span(str):style(ui.Style():fg("green")) })
			end

			if line then
				if i >= job.skip then
					table.insert(lines, line)
				end

				local max_width = math.max(1, job.area.w - 3)
				i = i + math.max(1, math.ceil(line:width() / max_width))
			end
		end
	end

	local rendered_img_rect = cache_img_url and ya.image_show(cache_img_url, job.area) or nil
	local image_height = rendered_img_rect and rendered_img_rect.h or 0
	ya.preview_widgets(job, {
		ui.Text(lines)
			:area(ui.Rect({
				x = job.area.x,
				y = job.area.y + image_height,
				w = job.area.w,
				h = job.area.h - image_height,
			}))
			:wrap(PREVIEW.wrap == "yes" and ui.Text.WRAP or ui.Text.WRAP_NO),
	})
end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		-- NOTE: Increase step by 10
		local step = cx.active.preview.skip + job.units + (job.units < 0 and -10 or 10)
		step = step > 95 and 95 or step
		ya.manager_emit("peek", {
			math.max(0, step),
			only_if = job.file.url,
		})
	end
end

function M:preload(job)
	local cache_img_url_no_skip = ya.file_cache({ file = job.file, skip = 0 })
	local cache_img_url_no_skip_cha = cache_img_url_no_skip and fs.cha(cache_img_url_no_skip)
	if not cache_img_url_no_skip then
		return true
	end
	local cache_mediainfo_url = Url(tostring(cache_img_url_no_skip) .. suffix)
	local err_msg = ""
	-- seekable mimetype
	if job.mime and string.find(job.mime, "^video/") then
		local video = require("video")
		-- video = ya.dict_merge(video, { skip = job.skip, file = job.file })
		local cache_img_status, video_preload_err = video:preload(job)
		if not cache_img_status and video_preload_err then
			err_msg = err_msg
				.. string.format("Failed to start `%s`, Do you have `%s` installed?\n", "ffmpeg", "ffmpeg")
		end
	end
	-- none-seekable mimetype
	if cache_img_url_no_skip and (not cache_img_url_no_skip_cha or cache_img_url_no_skip_cha.len <= 0) then
		-- audio
		if job.mime and string.find(job.mime, "^audio/") then
			local qv = 31 - math.floor(PREVIEW.image_quality * 0.3)
			local status, _ = Command("ffmpeg"):args({
				"-v",
				"quiet",
				"-threads",
				1,
				"-hwaccel",
				"auto",
				"-skip_frame",
				"nokey",
				"-an",
				"-sn",
				"-dn",
				"-i",
				tostring(job.file.url),
				"-vframes",
				1,
				"-q:v",
				qv,
				"-vf",
				string.format("scale=-1:'min(%d,ih)':flags=fast_bilinear", PREVIEW.max_height / 2),
				"-f",
				"image2",
				"-y",
				tostring(cache_img_url_no_skip),
			}):status()

			-- NOTE: Ignore this err msg because some audio types doesn't have cover image
			--
			-- if not status or not status.success then
			-- err_msg = err_msg
			-- 	.. string.format("Failed to start `%s`, Do you have `%s` installed?\n", "ffmpeg", "ffmpeg")
			-- end

			-- image
		elseif job.mime and string.find(job.mime, "^image/") then
			local mime = job.mime:match(".*/(.*)$")

			local image = magick_image_mimes[mime] and require("magick") or require("image")
			local no_skip_job = { skip = 0, file = job.file }
			-- image = ya.dict_merge(image, no_skip_job)
			local cache_img_status, image_preload_err = image:preload(no_skip_job)
			if not cache_img_status and image_preload_err then
				err_msg = err_msg .. "Failed to cache image , check cache folder permissions\n"
			end
		end
	end

	local cache_mediainfo_cha = fs.cha(cache_mediainfo_url)
	if cache_mediainfo_cha and cache_mediainfo_cha.len > 200 then
		return true
	end
	local cmd = "mediainfo"
	local output, err = Command(cmd):args({ tostring(job.file.url) }):stdout(Command.PIPED):output()
	if err then
		err_msg = err_msg .. string.format("Failed to start `%s`, Do you have `%s` installed?\n", cmd, cmd)
	end
	return fs.write(cache_mediainfo_url, err_msg .. (output and output.stdout or ""))
end

return M
