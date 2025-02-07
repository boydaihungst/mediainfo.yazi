# mediainfo.yazi

<!--toc:start-->

- [mediainfo.yazi](#mediainfo-yazi)
  - [Installation](#installation)
  <!--toc:end-->

This is a Yazi plugin for previewing media files. The preview shows thumbnail
using `ffmpeg` if available and media metadata using `mediainfo`.
Only for yazi stable.

## Installation

Install the plugin:

```bash
# delete the stable/shipped version if you already installed it
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
