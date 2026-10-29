# Runs FCEUX with a Lua script on a ROM and waits for it to exit.
param([string]$Script, [string]$Rom, [int]$TimeoutSec = 300)
$emu = if ($env:FCEUX) { $env:FCEUX } else { 'fceux64.exe' } # path to FCEUX, or on PATH
$p = Start-Process -FilePath $emu -ArgumentList '-lua', (Resolve-Path $Script), (Resolve-Path $Rom) -PassThru
if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill(); Write-Error "timeout: $Script $Rom"; exit 1 }
