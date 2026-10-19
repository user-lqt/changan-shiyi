# 第四章 · 已确认 A 版人物

苏晴、阿拾、金吾卫的精致低多边形模型，包含修整后的斜肩衣袖、整体掌形、叠片肩甲。三个人物保留可活动的肢体节点。

本目录保存 Blender 编辑源文件与导出的原始 GLB。`.gdignore` 防止 Godot 将摄影棚、灯光和源文件直接导入游戏。

## 维护

1. 使用本机 `D:/steam/steamapps/common/Blender/blender.exe` 打开对应角色的 `.blend`。
2. 只选择角色层级，导出 GLB 到本目录的 `su.glb`、`ashi.glb` 或 `guard.glb`。保留原有的关节名称、层级和 +Z 正面方向。
3. 在项目根目录运行 `python tools/install_night_style_a.py`。脚本统一转换为游戏使用的 +X 正面方向，将比例缩放至街巷尺度，对齐脚底，并适配现有动作关节名称。
4. 双击 `试玩第四章.bat` 检查。常规 `启动游戏.bat` 也会使用同一套角色资源。

游戏加载 `assets/models/night_su.glb`、`night_ashi.glb`、`night_guard.glb`，不依赖预览工程。`tools/build_night_detail.py` 重建夜行场景时会复用本目录的人物源文件。

## 值夜寺僧

`A-寺僧.blend` 保存终点提灯僧人的可编辑模型，采用同一低多边形风格。`tools/blender/build_night_monk.py` 使用本机 Blender 重建源文件，并直接导出 `assets/models/night_monk.glb`，正面已为游戏使用的 +X 方向，无须运行三人模型适配脚本。

保留 `Body`、`Head`、`Arm_Left`、`Arm_Right`、`HandLantern` 节点及其局部枢轴。游戏在到达寺门后显示模型，并驱动头部与手灯的轻微待机动作。透明立绘位于 `assets/images/npc_seng.png`，提示词保存在 `docs/art/ch4-monk-portrait-prompt.txt`。
