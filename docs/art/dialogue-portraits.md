# 对话回录与温师傅动作差分

对话时按 **H** 或点击左下角「对话历史」，可查看本次游戏已经读到的台词与选项。滚轮、方向键或翻页按钮切换记录，H / Esc 关闭。阅读历史时暂停打字和 Ctrl 快进；未读台词不会提前展示。

当前对话中已选的选项旁有「回到这个选择」按钮。返回后恢复选择前的剧情标记，移除放弃分支的记录，允许重新选择。对话结束、切换场景或触发剧情事件后，旧记录保留供阅读，避免再次发放物品或重复启动玩法。重新开始游戏会清空记录。

温师傅保持画面右侧，原立绘与全部动作差分均已左右镜像，朝画面内侧。

| 动作 | 对应素材 | 使用时机 |
| --- | --- | --- |
| 讲解、指引 | `npc_wen_explain.png` | 初见介绍、手记提示、去向说明、修复讲解 |
| 回忆、感慨 | `npc_wen_recall.png` | 先师旧碗、寻回碎片、修复后的告别 |
| 递灯、关切 | `npc_wen_offer.png` | 灯火熄灭后的寻片提示 |

差分以现有温师傅为参考，由 GPT-image2 生成，再抠图、统一尺寸并镜像。原始三联图与提示词保存在 `output/imagegen/wen-poses-sheet.png` 和 `output/imagegen/wen-poses-prompt.txt`，可通过 `tools/prepare_wen_poses.py` 重新处理。原立绘备份保存在 `output/imagegen/npc_wen-original.png`，重复运行不会再次翻转方向。

剧情条目的 `pose` 字段切换差分，未指定时显示原立绘。专项验证脚本为 `output/dialogue-tower-check/verify_dialogue_guide.gd`，实际按键、鼠标点击与截图保存在同一目录。
