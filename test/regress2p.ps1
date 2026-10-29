# Runs the 2-player regression (wide RAM compare, pinned RNG) on baserom vs contra4p.
param([int]$Frames = 20000)
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
$env:REGRESS_WIDE = '1'; $env:REGRESS_PIN_RNG = '1'; $env:REGRESS_FRAMES = "$Frames"
foreach ($r in 'baserom', 'contra4p') {
    $env:REGRESS_OUT = "$root\test\out_$r.log"
    if ($r -eq 'baserom' -and (Test-Path "$root\test\out_baserom.log") -and ((Get-Content "$root\test\out_baserom.log" | Measure-Object).Count -gt $Frames - 200)) { continue }
    & "$root\test\run-lua.ps1" test\regress2p.lua "$r.nes" 600
}
$a = Get-Content test\out_baserom.log; $b = Get-Content test\out_contra4p.log
$ranges = @(@(0x10,0x22),@(0x35,3),@(0x3a,0x56),@(0xdc,0x15),@(0xf3,2),@(0xf7,2),@(0xfb,5),@(0x300,0x400),@(0x7e0,6),@(0x200,0x100))
$addr = @(); foreach ($r in $ranges) { for ($k = 0; $k -lt $r[1]; $k++) { $addr += $r[0] + $k } }
# p3/p4 weapon temps at level change, sound engine temps (pointers into moved data), REST loop index, old extra life score bytes, code pointers, lag flag, graphics buffer offset (lag-only) and bank temps differ by design
$ign = @(0x12,0x13,0x1e,0xe0,0xe1,0xe2,0xe3,0xe4,0xe5,0xe6,0xe7,0xe8,0xe9,0xea,0xeb,0xec,0xed,0xee,0xef,0x3c,0x3d,0x3e,0x3f,0x1b,0x21,0x80,0x81,0xf7,0xf3,0x8c,0x8d)
$n = 0
for ($i = 0; $i -lt [Math]::Min($a.Count, $b.Count); $i++) {
    $x = ($a[$i] -split ' ')[1]; $y = ($b[$i] -split ' ')[1]
    if ($x -ne $y) {
        $d = @(); for ($k = 0; $k -lt $x.Length / 2; $k++) { if ($x.Substring($k*2,2) -ne $y.Substring($k*2,2) -and ($ign -notcontains $addr[$k])) { $d += ('${0:X4} {1}/{2}' -f $addr[$k], $x.Substring($k*2,2), $y.Substring($k*2,2)) } }
        if ($d.Count) { "DIFF tick line $i : $($d -join ', ')"; $n++; if ($n -ge 3) { break } }
    }
}
"compared $([Math]::Min($a.Count, $b.Count)) ticks; diffs: $n"
Pop-Location
