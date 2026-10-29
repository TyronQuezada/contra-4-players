# Writes FCEUX (Windows) input config for gamepads 2-4, keeping gamepad 1 as is.
# P2: Xbox controller over Bluetooth (VID_045E&PID_0B13), both DirectInput instances known to Windows
# P3: keyboard W A S D, J fire (B), K jump (A), Q select, E start
# P4: keyboard arrows, Num1 fire (B), Num2 jump (A), Num+ select, NumEnter start
# Backs up fceux.cfg once (fceux.cfg.bak-4p). FCEUX must be closed (it rewrites fceux.cfg on exit).
# usage: fceux-input-4p.ps1 -Cfg <path to fceux.cfg>
param([Parameter(Mandatory = $true)][string]$Cfg)
if (Get-Process fceux64 -ErrorAction SilentlyContinue) { throw 'Close FCEUX first' }
if (-not (Test-Path "$Cfg.bak-4p")) { Copy-Item $Cfg "$Cfg.bak-4p" } # keep the first (original) backup
$lines = [IO.File]::ReadAllLines($Cfg)
$key = 'GamePadConfig_V2 base64:'
$idx = [Array]::FindIndex($lines, [Predicate[string]] { param($l) $l.StartsWith($key) })
$b = [Convert]::FromBase64String($lines[$idx].Substring($key.Length))
if ($b.Length -ne 4 * 12 * 92) { throw "unexpected GamePadConfig_V2 size $($b.Length)" }

$kbGuid = [guid]'6F1D2B61-D5A0-11CF-BFC7-444553540000' # GUID_SysKeyboard
# DirectInput instance GUIDs of the Bluetooth Xbox controller (registry DirectInput\VID_045E&PID_0B13\Calibration)
$diRoot = 'HKCU:\System\CurrentControlSet\Control\MediaProperties\PrivateProperties\DirectInput\VID_045E&PID_0B13\Calibration'
$padGuids = @(Get-ChildItem $diRoot | ForEach-Object { [guid]::new([byte[]](Get-ItemProperty $_.PSPath).GUID) })
if ($padGuids.Count -eq 0) { throw 'Bluetooth Xbox controller not found in DirectInput registry' }

# ButtonConfig (92 bytes): ButtType[4] (0 keyboard, 1 joystick), DeviceNum[4], ButtonNum[4] (uint32),
# NumC (uint32), DeviceInstance[4] (GUID). Joystick POV hat: 0x2000 + direction (0 up, 1 right, 2 down, 3 left)
function Set-Button($pad, $btn, $bindings) {
    $o = ($pad * 12 + $btn) * 92
    [Array]::Clear($b, $o, 92)
    $n = [Math]::Min(4, $bindings.Count)
    for ($k = 0; $k -lt $n; $k++) {
        $b[$o + $k] = $bindings[$k].Type
        [BitConverter]::GetBytes([uint32]$bindings[$k].Num).CopyTo($b, $o + 8 + 4 * $k)
        $bindings[$k].Guid.ToByteArray().CopyTo($b, $o + 28 + 16 * $k)
    }
    [BitConverter]::GetBytes([uint32]$n).CopyTo($b, $o + 24)
}
function Joy($nums) { foreach ($g in $padGuids) { foreach ($n in $nums) { @{ Type = 1; Num = $n; Guid = $g } } } }
function Key($scan) { , @(@{ Type = 0; Num = $scan; Guid = $kbGuid }) }

# button order per pad: A (jump), B (fire), Select, Start, Up, Down, Left, Right
$p2 = @((Joy 0), (Joy 1), (Joy 6, 10), (Joy 7, 11), (Joy 0x2000), (Joy 0x2002), (Joy 0x2003), (Joy 0x2001))
$p3 = @(0x25, 0x24, 0x10, 0x12, 0x11, 0x1F, 0x1E, 0x20) # K, J, Q, E, W, S, A, D
$p4 = @(0x50, 0x4F, 0x4E, 0x9C, 0xC8, 0xD0, 0xCB, 0xCD) # Num2, Num1, Num+, NumEnter, arrows
for ($btn = 0; $btn -lt 12; $btn++) {
    if ($btn -lt 8) {
        Set-Button 1 $btn @($p2[$btn])
        Set-Button 2 $btn (Key $p3[$btn])
        Set-Button 3 $btn (Key $p4[$btn])
    } else {
        foreach ($pad in 1, 2, 3) { Set-Button $pad $btn @() } # no turbo buttons
    }
}
$lines[$idx] = $key + [Convert]::ToBase64String($b)
[IO.File]::WriteAllLines($Cfg, $lines)

# verify
$b2 = [Convert]::FromBase64String(([IO.File]::ReadAllLines($Cfg) | Where-Object { $_.StartsWith($key) }).Substring($key.Length))
for ($i = 12; $i -lt 48; $i++) {
    $o = $i * 92
    $n = [BitConverter]::ToUInt32($b2, $o + 24)
    if ($n -gt 0) {
        $parts = for ($k = 0; $k -lt $n; $k++) { '{0}:0x{1:X}' -f $b2[$o + $k], [BitConverter]::ToUInt32($b2, $o + 8 + 4 * $k) }
        'pad{0} btn{1} {2}' -f ([Math]::Floor($i / 12) + 1), ($i % 12), ($parts -join ' ')
    }
}
