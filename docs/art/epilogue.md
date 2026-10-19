# 尾声实验室素材

本次四张图片由 **GPT-image-2** 生成，使用 imagegen 技能的 CLI API 流程，沿用项目已配置的图像接口。生成原图保存在 `output/imagegen/epilogue/`，游戏素材保存在 `assets/images/lab/`。

| 游戏素材 | 用途 |
| --- | --- |
| `window-night.jpg` | 实验室窗外的现代西安、大雁塔与满月 |
| `archive-cabinet.jpg` | 实体三维档案柜的玻璃门、文物托盘及抽屉表面 |
| `scanner-fascia.jpg` | 扫描工作台正反两面的设备面板 |
| `conservation-board.jpg` | 文物照片、纹样与修补记录展板 |

夜景的完整提示词见 [lab-window-prompt.txt](../ai-records/v0.5/lab-window-prompt.txt)，三张室内素材的完整提示词见 [epilogue-lab-prompts.jsonl](epilogue-lab-prompts.jsonl)。室内素材按正面正交视图生成，贴入具有真实碰撞的三维模型表面；房间依然可以自由行走。

原始 PNG 转为游戏 JPG 的脚本为 `tools/prepare_lab_art.py`。莲纹碗与海兽葡萄纹铜镜沿用本轮已有三维模型；屏幕中的旋转模型使用独立三维视口。

尾声角色对白沿用苏晴现有火山引擎音色 `zh_female_liuchangnv_uranus_bigtts`，共 19 句，约 97 秒，24 kHz 单声道 MP3。语音文件按角色与原文的 MD5 自动匹配，见 `docs/ai-records/voice_lines.csv`。接口凭据不写入工程。

两段 AI 视频现已接入 `assets/videos/epilogue/return.ogv` 和 `assets/videos/epilogue/memory.ogv`，分别用于回到实验室与铜镜回忆。使用 2026-10-18 提供的 1080p 原片转码，保留画面比例与声音；完整说明见 [视频入口说明](../../assets/videos/epilogue/README.md)。
