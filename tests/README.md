# 验证与历史产物

实际检查代码位于 `scripts/core/tests.gd`，通过游戏命令行参数运行：

```text
godot --headless --path . -- --self-test
godot --path . -- --ui-test
godot --path . -- --ui-test-navigation
```

第一条覆盖关卡逻辑，第二条检查实际视口交互，第三条检查导航、重玩和设置。使用本机 Godot 可执行文件替换 `godot`；验证模式使用临时进度。

历史产物归入：

- [artifacts/logs/](artifacts/logs/)：原先散放在 `tests/` 的日志。
- [artifacts/screenshots/](artifacts/screenshots/)：原先的测试截图及导入元数据。

10 月 19 日已有日志归入 `tmp/logs/2026-10-19/`。用于报告展示的截图仍保存在 `docs/screenshots/`。
