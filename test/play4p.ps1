# Runs a 4-player smoke test on contra4p.nes with an FCEUX that has the Four Score attached.
# Writes test\out_4p.log and screenshots test\out_4p_NN.png
param([int]$Frames = 20000, [int]$Presses = 3)
$root = Split-Path $PSScriptRoot -Parent
$emu = $env:FCEUX4P
if (-not $emu) { throw 'set FCEUX4P to an fceux64.exe whose fceux.cfg has the Four Score attached' }
$map = Get-Content "$root\obj\contra4p.map"
foreach ($n in 'P1_NUM_LIVES', 'P1_GAME_OVER_STATUS') {
    $m = $map | Select-String "\b$n\s+0*(\w+)" | Select-Object -First 1
    Set-Item "env:ADDR_$n" $m.Matches[0].Groups[1].Value
}
$env:PLAY_OUT = "$root\test\out_4p"; $env:PLAY_FRAMES = "$Frames"; $env:PLAY_MODE_PRESSES = "$Presses"
Remove-Item "$root\test\out_4p.log", "$root\test\out_4p_*.png" -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $emu -ArgumentList '-lua', "$root\test\play4p.lua", "$root\contra4p.nes" -PassThru
if (-not $p.WaitForExit(500000)) { $p.Kill(); Write-Error 'timeout' }
