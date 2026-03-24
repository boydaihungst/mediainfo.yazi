--- @since 26.1.22

local M = {}
local is_yazi_nightly = ui.lines ~= nil
local const
local utils
local adobe
local audio
local image
local video

const = require(".const")
utils = require(".utils")

if is_yazi_nightly then
	ya.dbg("mediainfo", "Using yazi nightly")
	adobe = require(".adobe-nightly")
	audio = require(".audio-nightly")
	image = require(".image-nightly")
	video = require(".video-nightly")
else
	ya.dbg("mediainfo", "Using yazi stable")
	adobe = require(".adobe")
	audio = require(".audio")
	image = require(".image")
	video = require(".video")
end

function M:peek(job)
	-- debounce peek
	local start = os.clock()
	ya.sleep(math.max(0, rt.preview.image_delay / 1000 + start - os.clock()))

	-- Need mime to decide which module to use
	if not job.mime then
		return
	end

	local is_video = string.find(job.mime, "^video/")
	local is_audio = string.find(job.mime, "^audio/")
	local is_image = string.find(job.mime, "^image/")
	local is_adobe = const.seekable_mimes[job.mime]

	if is_adobe then
		return adobe:peek(job)
	elseif is_image then
		return image:peek(job)
	elseif is_video then
		return video:peek(job)
	elseif is_audio then
		return audio:peek(job)
	end
end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		utils.set_state(const.STATE_KEY.units, job.units)
		ya.emit("peek", {
			math.max(0, cx.active.preview.skip + job.units),
			only_if = job.file.url,
		})
	end
end
function M:preload(job)
	local cache_img_url = ya.file_cache({ file = job.file, skip = 0 })
	if not cache_img_url then
		ya.dbg("mediainfo", "Can't access yazi cache folder")
		return true
	end
	if not job.mime then
		return false
	end
	local is_video = string.find(job.mime, "^video/")
	local is_audio = string.find(job.mime, "^audio/")
	local is_image = string.find(job.mime, "^image/")
	local is_adobe = const.seekable_mimes[job.mime]

	if is_adobe then
		return adobe:preload(job)
	elseif is_image then
		return image:preload(job)
	elseif is_video then
		return video:preload(job)
	elseif is_audio then
		return audio:preload(job)
	end
end

function M:entry(job)
	local action = job.args[1]

	if action == const.ENTRY_ACTION.toggle_metadata then
		utils.set_state(const.STATE_KEY.hide_metadata, not utils.get_state(const.STATE_KEY.hide_metadata))
		ya.emit("peek", {
			force = true,
		})
	end
end

return M
