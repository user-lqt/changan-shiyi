param([string]$GodotPath = $env:GODOT_PATH)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$candidates = @(
    $GodotPath,
    'E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
    'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
)
$engine = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
if (-not $engine) {
    $found = Get-Command godot,godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $engine = $found.Source }
}
if (-not $engine) { throw 'Godot 4 was not found. Set GODOT_PATH to the engine executable.' }
$targetDir = Join-Path $projectRoot 'build\长安拾遗_Windows'
$logDir = Join-Path $projectRoot 'tmp\windows-export'
New-Item -ItemType Directory -Path $targetDir,$logDir -Force | Out-Null
$target = Join-Path $targetDir '长安拾遗.exe'
$quotedRoot = '"' + $projectRoot + '"'
foreach ($step in @('import','export')) {
    $argsForEngine = @('--headless','--editor','--path',$quotedRoot)
    if ($step -eq 'import') { $argsForEngine += '--import' }
    else { $argsForEngine += @('--export-release','"Windows 独立版"','"' + $target + '"') }
    $outLog = Join-Path $logDir ($step + '.log')
    $errLog = Join-Path $logDir ($step + '.err.log')
    $process = Start-Process -FilePath $engine -ArgumentList $argsForEngine -WorkingDirectory $projectRoot -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $outLog -RedirectStandardError $errLog
    if ($process.ExitCode -ne 0) { throw "Godot $step failed ($($process.ExitCode)). See $outLog and $errLog." }
    if ($step -eq 'export' -and -not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Export did not create $target. See $outLog and $errLog." }
}
$instructions = @'
长安拾遗 · 镜照工坊 / Windows 独立运行版

双击“长安拾遗.exe”启动游戏，在标题页选择“开始”。
本文件已内嵌游戏资源，不需要安装 Godot、Steam、Python，也无需联网。
适用于 Windows 10/11 64 位电脑。

常用操作：鼠标点击调查，空格 / Enter 推进对白，对话时 H 查看历史并重听已配音台词，非对话时 H 查看提示，J 查看手记，Esc 打开菜单。
暂停菜单的“重新开始本关”可从本关开头重新游玩，保留进入本关前的进度。
标题页“继续旅程”接续最近自动存档；标题页与暂停菜单的“行旅存档 / 保存 / 读取”可管理一个手动存档。
存档位于 Windows 用户数据目录；对话和演出从最近操作节点继续，击鼓与战斗从准备阶段或当前阶段起点继续。
第四章：Z 撤回一步（可连续撤回），R 回检查点。绿色藏身处会显示附近守卫下一步的位置。
第五章：结算展示完毕后点击“继续”或按 Enter / 空格关闭；展示中按一次仅加速显示。
关卡内依次输入 S K I P（每个字母间隔不超过 1.5 秒）可直接通关，奖励与解锁同步记录。
长安舆图界面按 F9 可解锁各章节。
第一人称章节：WASD 移动，鼠标观察，Shift 快跑；第六章可按 Tab 自动登塔。
第三章可启用自动演奏；具体操作以各章界面提示为准。
正常游玩会自动保存进度。随附说明和许可文件不影响 EXE 独立运行。

本版已内嵌序章、登塔和尾声的五段 AI 视频。通关尾声后，标题页可进入“长安拾遗录”人物与文化图鉴。
'@
Set-Content -LiteralPath (Join-Path $targetDir '使用说明.txt') -Value $instructions -Encoding UTF8
$notice = @(
    '长安拾遗使用 Godot Engine，以及工程内附的字体和模型素材。',
    'Godot 完整许可与第三方组件信息：https://godotengine.org/license/',
    '演示流云楷为现有书法字体；Noto 字体许可及 KayKit 模型许可见下文。'
)
$engineDir = Split-Path -Parent $engine
$licenseSources = @(
    (Join-Path $engineDir 'LICENSE.txt'),
    (Join-Path $engineDir 'COPYRIGHT.txt'),
    (Join-Path $projectRoot 'assets\fonts\notosanssc-OFL.txt'),
    (Join-Path $projectRoot 'assets\fonts\notoserifsc-OFL.txt'),
    (Join-Path $projectRoot 'assets\models\tower_kaykit\LICENSE.txt')
)
foreach ($license in $licenseSources) {
    if (Test-Path -LiteralPath $license -PathType Leaf) {
        $notice += "`r`n----- $(Split-Path -Leaf $license) -----`r`n"
        $notice += Get-Content -LiteralPath $license -Raw -Encoding UTF8
    }
}
Set-Content -LiteralPath (Join-Path $targetDir '第三方许可说明.txt') -Value $notice -Encoding UTF8
Get-Item -LiteralPath $target | Select-Object FullName,Length,LastWriteTime
