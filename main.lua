--- @since 25.5.31

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
	xml = true,
	["svg+xml"] = true,
}

local M = {}
local suffix = "_mediainfo"
local SHELL = os.getenv("SHELL") or ""

local function is_valid_utf8(str)
	return utf8.len(str) ~= nil
end

local function path_quote(path)
	if not path or tostring(path) == "" then
		return path
	end
	local result = "'" .. string.gsub(tostring(path), "'", "'\\''") .. "'"
	return result
end

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

local force_render = ya.sync(function(_, _)
	ya.render()
end)

function M:peek(job)
	local start = os.clock()
	local cache_img_url_no_skip = ya.file_cache({ file = job.file, skip = 0 })
	if not job.mime then
		return
	end
	local is_video = string.find(job.mime, "^video/")
	local is_audio = string.find(job.mime, "^audio/")
	local is_image = string.find(job.mime, "^image/")
	local cache_img_url = (is_audio or is_image) and cache_img_url_no_skip

	if is_video then
		cache_img_url = ya.file_cache(job)
	end
	local ok, err = self:preload(job)
	if not ok or err then
		return
	end
	ya.sleep(math.max(0, rt.preview.image_delay / 1000 + start - os.clock()))
	local cache_mediainfo_path = tostring(cache_img_url_no_skip) .. suffix
	local output = read_mediainfo_cached_file(cache_mediainfo_path)

	local lines = {}
	local max_lines = math.floor(job.area.h / 2)
	local last_line = 0
	local is_wrap = rt.preview.wrap == "yes"

	if output then
		local max_width = math.max(1, job.area.w)
		if output:match("^Error:") then
			job.args.force_reload_mediainfo = true
			local _ok, _err = self:preload(job)
			if not _ok or _err then
				return
			end
			output = read_mediainfo_cached_file(cache_mediainfo_path)
		end

		for str in output:gsub("\n+$", ""):gmatch("[^\n]*") do
			local label, value = str:match("(.*[^ ])  +: (.*)")
			local line
			if label then
				if not skip_labels[label] then
					line = ui.Line({
						ui.Span(label .. ": "):style(ui.Style():fg("reset"):bold()),
						ui.Span(value):style(th.spot.tbl_col or ui.Style():fg("blue")),
					})
				end
			elseif str ~= "General" then
				line = ui.Line({ ui.Span(str):style(th.spot.title or ui.Style():fg("green")) })
			end

			if line then
				local line_height = math.max(1, is_wrap and math.ceil(line:width() / max_width) or 1)
				if (last_line + line_height) > job.skip then
					table.insert(lines, line)
				end
				if (last_line + line_height) >= job.skip + max_lines then
					last_line = job.skip + max_lines
					break
				end
				last_line = last_line + line_height
			end
		end
	end
	local mediainfo_height = math.min(max_lines, last_line)

	if (job.skip > 0 and #lines == 0) and (not is_video or (is_video and job.skip >= 90)) then
		ya.emit("peek", { math.max(0, job.skip - max_lines), only_if = job.file.url, upper_bound = false })
		return
	end
	force_render()
	local rendered_img_rect = fs.cha(cache_img_url)
			and ya.image_show(
				cache_img_url,
				ui.Rect({
					x = job.area.x,
					y = job.area.y,
					w = job.area.w,
					h = job.area.h - mediainfo_height,
				})
			)
		or nil

	local image_height = rendered_img_rect and rendered_img_rect.h or 0

	-- NOTE: Workaround case audio has no cover image. Prevent regenerate preview image
	if is_audio and image_height == 1 then
		local info = ya.image_info(cache_img_url)
		if not info or (info.w == 1 and info.h == 1) then
			image_height = 0
		end
	end

	-- NOTE: Workaround case video.lua doesn't doesn't generate preview image because of `skip` overflow video duration
	if is_video and not rendered_img_rect then
		image_height = math.max(job.area.h - mediainfo_height, 0)
	end

	ya.preview_widget(job, {
		ui.Text(lines)
			:area(ui.Rect({
				x = job.area.x,
				y = job.area.y + image_height,
				w = job.area.w,
				h = job.area.h - image_height,
			}))
			:wrap(is_wrap and ui.Wrap.YES or ui.Wrap.NO),
	})
end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		ya.emit("peek", {
			math.max(0, cx.active.preview.skip + job.units),
			only_if = job.file.url,
		})
	end
end

function M:preload(job)
	local cache_img_url_no_skip = ya.file_cache({ file = job.file, skip = 0 })
	local cache_img_url_no_skip_cha = cache_img_url_no_skip and fs.cha(cache_img_url_no_skip)
	local cache_mediainfo_url = Url(tostring(cache_img_url_no_skip) .. suffix)
	local err_msg = ""
	local is_valid_utf8_path = is_valid_utf8(tostring(job.file.url))
	-- seekable mimetype
	if job.mime and string.find(job.mime, "^video/") then
		local cache_img_status, video_preload_err = require("video"):preload(job)
		if not cache_img_status and video_preload_err then
			err_msg = err_msg
				.. string.format("Failed to start `%s`, Do you have `%s` installed?\n", "ffmpeg", "ffmpeg")
		end
	end
	if not cache_img_url_no_skip then
		return true
	end
	-- none-seekable mimetype
	if cache_img_url_no_skip and (not cache_img_url_no_skip_cha or cache_img_url_no_skip_cha.len <= 0) then
		-- audio
		if job.mime and string.find(job.mime, "^audio/") then
			local qv = 31 - math.floor(rt.preview.image_quality * 0.3)
			local audio_preload_output, audio_preload_err = Command("ffmpeg"):arg({
				"-v",
				"error",
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
				string.format("scale=-1:'min(%d,ih)':flags=fast_bilinear", rt.preview.max_height / 2),
				"-f",
				"image2",
				"-y",
				tostring(cache_img_url_no_skip),
			}):output()
			-- NOTE: Some audio types doesn't have cover image -> error ""
			if (audio_preload_output.stderr ~= nil and audio_preload_output.stderr ~= "") or audio_preload_err then
				err_msg = err_msg
					.. string.format("Failed to start `%s`, Do you have `%s` installed?\n", "ffmpeg", "ffmpeg")
			else
				cache_img_url_no_skip_cha = fs.cha(cache_img_url_no_skip)
				if not cache_img_url_no_skip_cha then
					-- NOTE: Workaround case audio has no cover image. Prevent regenerate preview image
					audio_preload_output, audio_preload_err = require("magick")
						.with_limit()
						:arg({
							"-size",
							"1x1",
							"canvas:none",
							string.format("PNG32:%s", cache_img_url_no_skip),
						})
						:output()
					if audio_preload_output.stderr or audio_preload_err then
						err_msg = err_msg
							.. string.format("Failed to start `%s`, Do you have `%s` installed?\n", "magick", "magick")
					end
				end
			end
			-- image
		elseif job.mime and string.find(job.mime, "^image/") then
			local svg_plugin_ok, svg_plugin = pcall(require, "svg")
			local _, magick_plugin = pcall(require, "magick")
			local mime = job.mime:match(".*/(.*)$")

			local image_plugin = magick_image_mimes[mime]
					and ((mime == "svg+xml" and svg_plugin_ok) and svg_plugin or magick_plugin)
				or require("image")

			local cache_img_status, image_preload_err
			if mime == "svg+xml" and not is_valid_utf8_path then
				cache_img_status, image_preload_err = magick_plugin
					.with_limit()
					:arg({
						"-background",
						"none",
						tostring(job.file.url),
						"-auto-orient",
						"-strip",
						"-flatten",
						"-resize",
						string.format("%dx%d>", rt.preview.max_width, rt.preview.max_height),
						"-quality",
						rt.preview.image_quality,
						string.format("PNG32:%s", cache_img_url_no_skip),
					})
					:status()
			else
				local no_skip_job = { skip = 0, file = job.file, args = {} }
				cache_img_status, image_preload_err = image_plugin:preload(no_skip_job)
			end
			if not cache_img_status then
				err_msg = err_msg
					.. "Failed to cache image\n"
					.. (image_preload_err and (":" .. image_preload_err) or "")
			end
		end
	end

	local cache_mediainfo_cha = fs.cha(cache_mediainfo_url)
	if cache_mediainfo_cha and not job.args.force_reload_mediainfo then
		return true
	end
	local cmd = "mediainfo"
	local output, err
	if is_valid_utf8_path then
		output, err = Command(cmd):arg({ tostring(job.file.url) }):output()
	else
		cmd = "cd "
			.. path_quote(job.file.url.parent)
			.. " && "
			.. cmd
			.. " "
			.. path_quote(tostring(job.file.url.name))
		output, err = Command(SHELL):arg({ "-c", cmd }):arg({ tostring(job.file.url) }):output()
	end
	if err then
		err_msg = err_msg .. string.format("Failed to start `%s`, Do you have `%s` installed?\n", cmd, cmd)
	end
	return fs.write(
		cache_mediainfo_url,
		(err_msg ~= "" and "Error: " .. err_msg or "") .. (output and output.stdout or "")
	)
end

return M
