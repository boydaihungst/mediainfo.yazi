# mediainfo.yazi

<!--toc:start-->

- [mediainfo.yazi](#mediainfo-yazi)
  - [Installation](#installation)
  <!--toc:end-->

This is a Yazi plugin for previewing media files. The preview shows thumbnail
using `ffmpeg` if available and media metadata using `mediainfo`.

> [!IMPORTANT]
> Minimum version: yazi v25.2.7.

## Preview

- Video

![video](assets/2025-02-15-09-15-39.png)

- Audio file with cover

![audio_with_cover_picture](assets/2025-02-15-09-14-23.png)

- Images

![image](assets/2025-02-15-16-52-39.png)

- Subtitle

![subrip](assets/2025-02-15-16-51-11.png)

- There are more extensions which are supported by mediainfo. Just add file's MIME type to `previewers`, `preloaders`.

## Installation

Install the plugin:

> [!IMPORTANT] 
> `mediainfo` use video, image, magick plugins behind the scene to render preview image, song cover.
> So you can remove those 3 plugins from `preloaders` and `previewers` sections in `yazi.coml`.

If you have cache problem, run this cmd, and follow the tips: `yazi --clear-cache`

```bash
ya pack -a boydaihungst/mediainfo
```

Config folder for each OS: https://yazi-rs.github.io/docs/configuration/overview
Create `.../yazi/yazi.toml` and add:

```toml
[plugin]
  prepend_preloaders = [
    # Replace magick, image, video with mediainfo
    { mime = "{audio,video,image}/*", run = "mediainfo" },
    { mime = "application/subrip", run = "mediainfo" },
  ]
  prepend_previewers = [
    # Replace magick, image, video with mediainfo
    { mime = "{audio,video,image}/*", run = "mediainfo"},
    { mime = "application/subrip", run = "mediainfo" },
  ]
```
