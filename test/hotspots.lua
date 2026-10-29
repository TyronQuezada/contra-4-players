-- Instruction-count profiler: counts executed instructions per (bank, pc) while the
-- attract demo plays a level. Env: HOT_OUT, HOT_LEVEL (demo level index), HOT_FRAMES (game frames to sample)
local outPath = os.getenv("HOT_OUT")
local level = tonumber(os.getenv("HOT_LEVEL") or "0")
local want = tonumber(os.getenv("HOT_FRAMES") or "300")
emu.speedmode("maximum")

local bank = 0
memory.registerwrite(0x8000, 0x8000, function(a, s, v) if v then bank = v % 8 end end) -- UxROM bank select
local counts, sampling, sampled = {}, false, 0
local function hook()
  if not sampling then return end
  local pc = memory.getregister("pc")
  local k = (pc >= 0xc000) and (7 * 65536 + pc) or (bank * 65536 + pc)
  counts[k] = (counts[k] or 0) + 1
end

for n = 1, 40000 do
  local inLevel = memory.readbyte(0x1c) == 1 and memory.readbyte(0x2c) == 4 and memory.readbyte(0x30) == level
  if inLevel and not sampling and sampled == 0 then
    -- skip the first 200 frames of the level, then sample
    for i = 1, 200 do emu.frameadvance() end
    sampling = true
    memory.registerexec(0x8000, 0x8000, hook)
  end
  emu.frameadvance()
  if sampling then
    sampled = sampled + 1
    if sampled >= want then break end
  end
end
memory.registerexec(0x8000, 0x8000, nil)
local f = io.open(outPath, "w")
for k, c in pairs(counts) do f:write(string.format("%d %04x %d\n", math.floor(k / 65536), k % 65536, c)) end
f:close()
os.exit()
