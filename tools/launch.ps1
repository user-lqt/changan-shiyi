param([switch]$Editor, [switch]$Qujiang, [switch]$Market, [switch]$Workshop, [switch]$Tavern, [switch]$Night, [switch]$Prologue, [switch]$Tower, [switch]$Epilogue)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$candidates = @(
    $env:GODOT_PATH,
    'E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
    'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
)
$engine = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
if (-not $engine) {
    $found = Get-Command godot,godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $engine = $found.Source }
}
if (-not $engine) { throw 'Godot 4 was not found. Set GODOT_PATH to the engine executable.' }
$quotedRoot = '"' + $projectRoot + '"'
if ($Editor) {
    Start-Process -FilePath $engine -ArgumentList @('--editor','--path',$quotedRoot) -WorkingDirectory $projectRoot
} else {
    # Always refresh imports so new or regenerated images/audio are picked up (fast when nothing changed).
    $import = Start-Process -FilePath $engine -ArgumentList @('--headless','--editor','--path',$quotedRoot,'--import') -WindowStyle Hidden -Wait -PassThru
    if ($import.ExitCode -ne 0) { Write-Warning 'Godot asset import reported an error; trying to start anyway.' }
    $gameArgs = @('--path',$quotedRoot)
    if ($Qujiang) { $gameArgs += @('--','--preview=ch5') }
    elseif ($Market) { $gameArgs += @('--','--preview=ch2') }
    elseif ($Workshop) { $gameArgs += @('--','--preview=ch1') }
    elseif ($Tavern) { $gameArgs += @('--','--preview=ch3') }
    elseif ($Night) { $gameArgs += @('--','--preview=ch4') }
    elseif ($Prologue) { $gameArgs += @('--','--preview=prologue') }
    elseif ($Tower) { $gameArgs += @('--','--preview=ch6') }
	elseif ($Epilogue) { $gameArgs += @('--','--preview=epilogue') }
    $run = Start-Process -FilePath $engine -ArgumentList $gameArgs -WorkingDirectory $projectRoot -PassThru
    Write-Output ('Game started. PID=' + $run.Id)
}
