# Runs hotspots.lua on the attract demo and aggregates executed instructions per routine
# (nearest preceding label from the ld65 debug file). Needs $env:FCEUX4P.
param([int]$Level = 2, [int]$Frames = 300, [int]$Top = 30, [string]$Rom = 'contra4p.nes', [string]$Dbg = 'contra4p.dbg', [switch]$NoRun)
$root = Split-Path $PSScriptRoot -Parent
$env:HOT_OUT = "$root\test\out_hotspots.txt"; $env:HOT_LEVEL = "$Level"; $env:HOT_FRAMES = "$Frames"
if (-not $NoRun) {
$p = Start-Process -FilePath $env:FCEUX4P -ArgumentList '-lua', "$root\test\hotspots.lua", "$root\$Rom" -PassThru
if (-not $p.WaitForExit(1800000)) { $p.Kill(); throw 'timeout' }
}

# segments: id -> bank number
$segBank = @{}
$labels = @{} # bank -> list of (addr, name)
$dbgLines = Get-Content "$root\$Dbg"
foreach ($l in $dbgLines) {
    if ($l -match '^seg\tid=(\d+),name="BANK_(\d)"') { $segBank[$matches[1]] = [int]$matches[2] }
}
foreach ($l in $dbgLines) {
    if ($l -match '^sym\t.*name="([^"]+)".*val=0x([0-9A-F]+),seg=(\d+),type=lab') {
        if ($segBank.ContainsKey($matches[3]) -and -not $matches[1].StartsWith('@')) {
            $bk = $segBank[$matches[3]]
            if (-not $labels.ContainsKey($bk)) { $labels[$bk] = New-Object System.Collections.Generic.List[object] }
            $labels[$bk].Add([pscustomobject]@{ A = [Convert]::ToInt32($matches[2], 16); N = $matches[1] })
        }
    }
}
foreach ($k in @($labels.Keys)) { $labels[$k] = @($labels[$k] | Sort-Object A) }
$agg = @{}; $total = 0
foreach ($l in Get-Content $env:HOT_OUT) {
    $bk, $pc, $c = $l -split ' '; $bk = [int]$bk; $pc = [Convert]::ToInt32($pc, 16); $c = [int]$c
    $total += $c
    $name = '?'
    $arr = $labels[$bk]; $lo = 0; $hi = $arr.Count - 1 # binary search: last label with address <= pc
    while ($lo -le $hi) { $mid = [int][Math]::Floor(($lo + $hi) / 2); if ($arr[$mid].A -le $pc) { $name = $arr[$mid].N; $lo = $mid + 1 } else { $hi = $mid - 1 } }
    $agg["$bk/$name"] = $agg["$bk/$name"] + $c
}
"instructions sampled: $total over $Frames frames ($([int]($total / $Frames)) per frame)"
$agg.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First $Top | ForEach-Object {
    '{0,7}  {1,5:N1}%  {2}' -f $_.Value, ($_.Value * 100 / $total), $_.Key
}
