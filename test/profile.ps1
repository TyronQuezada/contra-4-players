# CPU profile of contra4p.nes in 2-player and 4-player mode (same random input).
# Needs $env:FCEUX4P pointing to an FCEUX whose fceux.cfg has the Four Score attached.
param([int]$Frames = 6000, [int[]]$Presses = @(1, 3), [string]$Rom = "contra4p.nes", [string]$Dbg = "contra4p.dbg")
$root = Split-Path $PSScriptRoot -Parent
if (-not $env:FCEUX4P) { throw 'set FCEUX4P' }
$syms = @{}
foreach ($l in Get-Content "$root\$Dbg") {
    if ($l -match '^sym\t.*name="(\w+)".*val=0x([0-9A-F]+)') { $syms[$matches[1]] = $matches[2] }
}
foreach ($n in 'nmi_start', 'load_controller_state', 'set_frame_scroll_draw_player_bullets', 'load_bank_6_run_player_bullet_routines', 'draw_player_bullet_sprites', 'load_bank_3_handle_scroll',
    'load_bank_0_exe_all_enemy_routine', 'load_bank_2_load_screen_enemy_data', 'write_0_to_cpu_graphics_buffer') {
    if (-not $syms[$n]) { throw "symbol $n not found" }
    Set-Item "env:PROF_ADDR_$n" $syms[$n]
}
foreach ($p in $Presses) {
    $env:PROF_OUT = "$root\test\out_profile_$p.txt"; $env:PROF_FRAMES = "$Frames"; $env:PROF_PRESSES = "$p"
    $proc = Start-Process -FilePath $env:FCEUX4P -ArgumentList '-lua', "$root\test\profile.lua", "$root\$Rom" -PassThru
    if (-not $proc.WaitForExit(600000)) { $proc.Kill(); throw 'timeout' }
    "== $(if ($p -eq 1) { '2 players' } else { "$($p + 1) players" })"
    Get-Content $env:PROF_OUT
}
