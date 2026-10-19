# 東方鏡月譚

第七章战斗画面右下角使用繁体题字「東方鏡月譚」，米白书法配铜镜与弯月，适配塔内暗色背景。

- 原图：`output/imagegen/ch7/mirror-moon-logo-ai.png`
- 游戏贴图：`assets/images/ch7_mirror_moon_logo.png`
- 提示词：`output/imagegen/ch7/mirror-moon-logo-prompt.txt`
- 素材处理：`tools/prepare_ch7_logo.py`

沿用用户配置的生图接口，通过 imagegen 技能 CLI 调用 GPT-image-2 生成；保留生成结果的透明通道，裁切后放入战斗框外右下区域。Logo 不参与碰撞与战斗判定。

界面文字统一使用镜光与月华意象：苦无称为「镜棱」，米弹称为「流光」，大玉称为「月华珠」，残机称为「护魂灯」，火力称为「镜力」，符卡称为「镜阵」。帮助、阶段提示、灵物图例、战斗状态、奖励与失败提示同步更新。
