# Assembles and links without re-extracting assets (run build.ps1 once first).
# Prints only assembler/linker errors and the segment usage table.
$root = Split-Path $PSScriptRoot -Parent
$bin = Join-Path $root 'tools-cc65\bin'
Push-Location $root
$ok = $true
foreach ($f in 'ram','constants','ines_header','bank0','bank1','bank2','bank3','bank4','bank5','bank6','bank7') {
    $o = & "$bin\ca65.exe" -D Contra --debug-info -o "obj\$f.o" "src\$f.asm" 2>&1
    if ($LASTEXITCODE -ne 0) { $ok = $false; $o | ForEach-Object { "$_" } }
}
if ($ok) {
    $objs = 'ram','constants','ines_header','bank0','bank1','bank2','bank3','bank4','bank5','bank6','bank7' | ForEach-Object { "obj\$_.o" }
    $o = & "$bin\ld65.exe" -C contra.cfg --dbgfile contra4p.dbg -m obj\contra4p.map @objs -o contra4p.nes 2>&1
    if ($LASTEXITCODE -ne 0) { $ok = $false; $o | ForEach-Object { "$_" } }
    else {
        (Get-Content obj\contra4p.map | Select-String '^(ZEROPAGE|RAM|BANK_\d)\s') | ForEach-Object { $_.Line }
        'built contra4p.nes'
    }
}
Pop-Location
if (-not $ok) { exit 1 }
