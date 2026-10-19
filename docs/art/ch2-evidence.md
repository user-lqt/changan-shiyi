# 第二章 · 西市对质美术

## 证据插画

- 模型：GPT-image-2；通过用户提供的 YosHub 接口调用 imagegen 技能的内置 CLI。
- 完整提示词：[ch2-evidence-prompt.txt](ch2-evidence-prompt.txt)。
- 生成原图：`output/imagegen/ch2-evidence-atlas.png`，1536 × 1024，四格构图。
- 游戏资源：`assets/images/evidence_shard.png`、`evidence_ledger.png`、`evidence_bundle.png`、`evidence_gong.png`，每张 768 × 512。
- 裁切工具：`python tools/split_evidence_art.py`。
- 插画呈现道具外观；证据文字由游戏界面绘制，判定沿用剧情数据。

## 界面与反馈

证据卡使用墨青底、旧金描边和朱印选中标记。出示时，道具卡沿弧线飞向矛盾词；识破与误判进入生图制作的全屏人物演出，并显示证据对应关系或信用扣除。信用使用方孔铜钱，三轮证言使用壹、贰、叁签条显示状态。全屏演出资源与提示词详见 [ch2-cinematic.md](ch2-cinematic.md)。

运行 `powershell -ExecutionPolicy Bypass -File tools/launch.ps1 -Market` 可直接预览第二章；预览使用临时进度。

## 验证

- 全流程逻辑：120 项通过。
- 界面交互覆盖证据卡、滚轮、快捷键、飞行时锁定选择、扣信用、轮次推进和全屏演出。
- 实机截图：`docs/screenshots/v0.4/ch2-art-*.png`，包含常态、识破、误判、第二轮、低信用和出示证据。
