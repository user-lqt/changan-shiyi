# 第七章自机形象

采用已确认的简约苏晴设计：短发、米白工作服、深青色内搭，两侧配小铜镜。常态保留短尾迹；左右移动轻微倾斜；Shift 低速时铜镜收拢，判定点显示在弹幕上层。火力提高时铜镜稍微展开，受击时出现短暂碎光。

## 素材

- 概念图：`output/imagegen/ch7/player-concept-simple.png`
- 角色原图：`output/imagegen/ch7/player-sprite-keyed.png`
- 游戏透明贴图：`assets/images/player_su.png`（128 × 256，绘制尺寸 28 × 56）
- 原始提示词：`output/imagegen/ch7/player-sprite-prompt.txt`

通过用户已配置的 YosHub 接口调用 GPT-image-2，使用 imagegen 技能的 CLI 编辑模式，以概念图作为参考生成独立角色。生成结果已带透明通道，直接保留原始透明度。`tools/prepare_player_art.py` 清理分离杂点、裁切并缩放；铜镜、尾迹、倾斜与判定提示由 Godot 绘制。

角色贴图围绕原有 `player` 坐标绘制，倾斜与悬浮仅影响外观。移动速度、射击、受击及擦弹逻辑沿用现有规则。
