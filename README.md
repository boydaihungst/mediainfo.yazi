# mediainfo.yazi

<!--toc:start-->

- [mediainfo.yazi](#mediainfoyazi)
  - [Installation](#installation)
  <!--toc:end-->

This is a Yazi plugin for previewing media files. The preview shows thumbnail
using `ffmpeg` if available and media metadata using `mediainfo`.
Only for yazi stable/shipped version >= 0.4

> [!IMPORTANT]  
> For nightly version, use this repo:
> [mediainfo-nightly.yazi](https://github.com/boydaihungst/mediainfo-nightly.yazi)

## Installation

Install the plugin:

```bash
ya pack -a boydaihungst/mediainfo
```

Create `~/.config/yazi/yazi.toml` and add:

```toml
[plugin]
prepend_previewers = [
    { mime = "{image,audio,video}/*", run = "mediainfo"},
    { mime = "application/subrip", run = "mediainfo"},
]
```
