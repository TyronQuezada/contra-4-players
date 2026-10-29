# Builds an IPS patch from baserom.nes (Contra (USA)) to contra4p.nes and prints checksums.
# The iNES header is the same in both files, so the patch also works on ROMs with an NES 2.0 header.
param([string]$Out = 'release\Contra4P-by-Killerz.ips')
$root = Split-Path $PSScriptRoot -Parent
$src = [IO.File]::ReadAllBytes("$root\baserom.nes")
$dst = [IO.File]::ReadAllBytes("$root\contra4p.nes")
if ($src.Length -ne $dst.Length) { throw 'size mismatch' }
$ms = New-Object IO.MemoryStream
$w = { param([byte[]]$bytes) $ms.Write($bytes, 0, $bytes.Length) }
& $w ([Text.Encoding]::ASCII.GetBytes('PATCH'))
$i = 0
while ($i -lt $dst.Length) {
    if ($src[$i] -eq $dst[$i]) { $i++; continue }
    $start = $i
    # extend the record while bytes differ (or a short equal run sits between differences)
    $end = $i
    while ($end -lt $dst.Length -and ($end - $start) -lt 0xFFFF) {
        if ($src[$end] -ne $dst[$end]) { $end++; continue }
        $run = 0
        while (($end + $run) -lt $dst.Length -and $src[$end + $run] -eq $dst[$end + $run] -and $run -lt 6) { $run++ }
        if ($run -lt 6 -and ($end + $run) -lt $dst.Length) { $end += $run } else { break }
    }
    if ($start -eq 0x454F46) { $start--; } # 'EOF' offset is reserved
    $len = $end - $start
    & $w ([byte[]]@((($start -shr 16) -band 0xFF), (($start -shr 8) -band 0xFF), ($start -band 0xFF), (($len -shr 8) -band 0xFF), ($len -band 0xFF)))
    $chunk = New-Object byte[] $len; [Array]::Copy($dst, $start, $chunk, 0, $len); & $w $chunk
    $i = $end
}
& $w ([Text.Encoding]::ASCII.GetBytes('EOF'))
New-Item -ItemType Directory -Force (Split-Path "$root\$Out") | Out-Null
[IO.File]::WriteAllBytes("$root\$Out", $ms.ToArray())

# self-check: apply the patch to baserom.nes and compare with contra4p.nes
$p = [IO.File]::ReadAllBytes("$root\$Out"); $r = [byte[]]$src.Clone(); $k = 5
while ([Text.Encoding]::ASCII.GetString($p, $k, 3) -ne 'EOF') {
    $off = ([int]$p[$k] -shl 16) -bor ([int]$p[$k + 1] -shl 8) -bor [int]$p[$k + 2]; $len = ([int]$p[$k + 3] -shl 8) -bor [int]$p[$k + 4]; $k += 5
    if ($len -eq 0) { $rl = ([int]$p[$k] -shl 8) -bor [int]$p[$k + 1]; for ($j = 0; $j -lt $rl; $j++) { $r[$off + $j] = $p[$k + 2] }; $k += 3 }
    else { [Array]::Copy($p, $k, $r, $off, $len); $k += $len }
}
for ($j = 0; $j -lt $r.Length; $j++) { if ($r[$j] -ne $dst[$j]) { throw "patch self-check failed at $j" } }

function Crc32([byte[]]$data, [int]$offset) {
    $table = foreach ($n in 0..255) { $c = [uint32]$n; for ($k = 0; $k -lt 8; $k++) { if ($c -band 1) { $c = [uint32]3988292384 -bxor ($c -shr 1) } else { $c = $c -shr 1 } }; $c }
    $crc = [uint32]4294967295
    for ($j = $offset; $j -lt $data.Length; $j++) { $crc = $table[($crc -bxor $data[$j]) -band 0xFF] -bxor ($crc -shr 8) }
    '{0:X8}' -f ([uint32]($crc -bxor [uint32]4294967295))
}
$sha = [Security.Cryptography.SHA1]::Create()
"patch: $Out ($((Get-Item "$root\$Out").Length) bytes), self-check OK"
"source ROM (without header): CRC32 $(Crc32 $src 16)  SHA-1 $(([BitConverter]::ToString($sha.ComputeHash($src, 16, $src.Length - 16))) -replace '-','')"
"patched ROM (without header): CRC32 $(Crc32 $dst 16)  SHA-1 $(([BitConverter]::ToString($sha.ComputeHash($dst, 16, $dst.Length - 16))) -replace '-','')"
