# 第二章 · 全屏对质演出

## 动画节奏

识破持续 3.2 秒：眼神横切、主角指证立绘滑入、手绘「识破！」爆字落下、证据对应关系浮现、退场后接剧情对白。

误判持续 2.7 秒：掌柜反驳立绘从另一侧入场、「驳回！」爆字、错误证据及信用 −1 提示，随后回到当前证言。最后一枚信用耗尽时，反驳结束后再进入送客对白。

演出超过 0.8 秒后，可按空格或 Enter 跳过；期间锁定底层证据、换句和帮助快捷键。图片由游戏实时分层动画驱动，人物、爆字、背景和证据提示分别运动。

## AI 资源与提示词

2026-10-17 使用用户提供的 YosHub 接口，通过 imagegen 技能的内置 CLI 调用 GPT-image-2；质量 high，原图 1536 × 1024。

| 资源 | 提示词 | 游戏文件 |
| --- | --- | --- |
| 苏晴指证立绘 | [ch2-cutin-su-prompt.txt](ch2-cutin-su-prompt.txt)，参考现有苏晴立绘编辑 | `assets/images/ch2_cutin_su.png` |
| 康掌柜反驳立绘 | [ch2-cutin-kang-prompt.txt](ch2-cutin-kang-prompt.txt)，参考现有掌柜立绘编辑 | `assets/images/ch2_cutin_kang.png` |
| 水墨与金箔背景 | [ch2-cutin-background-prompt.txt](ch2-cutin-background-prompt.txt) | `assets/images/ch2_cutin_background.png` |
| 识破爆字 | [ch2-cutin-title-prompt.txt](ch2-cutin-title-prompt.txt) | `assets/images/ch2_cutin_title.png` |
| 驳回爆字 | [ch2-cutin-retort-title-prompt.txt](ch2-cutin-retort-title-prompt.txt)，基于识破爆字编辑 | `assets/images/ch2_cutin_retort_title.png` |

生图原件保存在 `output/imagegen/ch2-cutin-*.png`。人物与爆字采用绿幕生图，经 `python tools/prepare_cutin_art.py` 在本地提取透明层并清理边缘。

## 预览

- 实机动画：`docs/screenshots/v0.4/ch2-success-preview.webp`、`ch2-retort-preview.webp`，另提供通用 GIF 版本。
- 实机截图：`docs/screenshots/v0.4/ch2_stamp-cinematic.png`、`ch2_error-cinematic.png`。
- 第二章试玩：`powershell -ExecutionPolicy Bypass -File tools/launch.ps1 -Market`。
- 动画预览由真实 Godot 视口录帧制作，脚本为 `tools/build_cutin_preview.py`。

## 验证

全流程逻辑检查 120 项通过，界面交互检查 35 项通过。新增检查覆盖演出期间锁定底层操作、隐藏全局按钮、空格跳过、自然结束后的单次轮次推进，以及最后一枚信用耗尽后的送客与重试。
