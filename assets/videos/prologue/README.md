# 序章穿越视频入口

本视频在扫描异常对白结束之后、第一章镜坊旁白之前播放，画面从实验室经白光转入唐代镜坊。

制作素材与提示词：`deliverables/ai-video/序章穿越_AI视频素材包_20261018/`。

已接入原片 `video/e6d6a7456acbea6a464d47c9b65ccfba_raw.mp4`，时长 8.064 秒，1920×1080、16:9、24 fps，保留原片双声道音频。

使用 FFmpeg 7.1 转为本目录 `arrival.ogv`，经过完整解码校验。原片校验值与转换参数见 `output/video-integration/prologue-video.json`。

更新原片可运行 `python tools/prepare_story_videos.py --ffmpeg <FFmpeg7.1路径> --prologue-source <原片路径>`；仅转换序章，不影响其他视频。

视频完整显示、不裁切；播放期间暂停背景音乐，结束后恢复并进入第一章。空格、Enter、Esc、左键均可跳过。
