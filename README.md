# mediainfo.yazi

<!--toc:start-->

- [mediainfo.yazi](#mediainfo-yazi)
  - [Installation](#installation)
  <!--toc:end-->

This is a Yazi plugin for previewing media files. The preview shows thumbnail
using `ffmpeg` if available and media metadata using `mediainfo`.

> [!IMPORTANT]
> Minimum version: yazi v25.2.7.

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
    # It's highly recommended to use "code" previewer instead of this plugin
    # { mime = "application/subrip", run = "mediainfo"},
]
```
