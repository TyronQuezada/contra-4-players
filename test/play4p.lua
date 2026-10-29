-- 4-player smoke test (needs an FCEUX with the Four Score attached).
-- Env: PLAY_OUT = log path prefix, PLAY_FRAMES = emulator frames, PLAY_MODE_PRESSES = select presses (3 = 4 players)
local outPath = os.getenv("PLAY_OUT")
local frames = tonumber(os.getenv("PLAY_FRAMES") or "20000")
local presses = tonumber(os.getenv("PLAY_MODE_PRESSES") or "3")
local out = io.open(outPath .. ".log", "w")
emu.speedmode("maximum")

local function addr(name) return tonumber(os.getenv("ADDR_" .. name), 16) end
local LIVES, GO = addr("P1_NUM_LIVES"), addr("P1_GAME_OVER_STATUS")

local seed = tonumber(os.getenv("PLAY_SEED") or "777")
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end

local held = {{}, {}, {}, {}}
local maxgfx, restshot = 0, false
local p3writes, p3bullets = 0, 0
memory.registerwrite(0x07e6, 2, function() p3writes = p3writes + 1 end)
memory.registerwrite(0x0021, 1, function(a, s, v) if v and v > maxgfx then maxgfx = v end end)
local lastfc, still, shots = -1, 0, 0
for n = 1, frames do
  local pads = {{}, {}, {}, {}}
  if n >= 300 and n < 300 + presses * 20 and n % 20 == 0 then pads[1].select = true end
  if n == 400 then pads[1].start = true end
  if n > 600 then
    for i = 1, 4 do
      if n % 25 == i then held[i] = {right = rnd(10) < 7, left = rnd(10) < 1, up = rnd(10) < 2,
        down = rnd(10) < 2, A = rnd(10) < 3, B = rnd(10) < 7} end
      local only = tonumber(os.getenv("PLAY_ONLY") or "")
      if not only or only == i then for k, v in pairs(held[i]) do pads[i][k] = v end end
    end
    if n % 900 == 0 then pads[1].start = true; pads[1].A = false end -- continue after game over
  end
  local lvl = tonumber(os.getenv("PLAY_LEVEL") or "")
  if lvl and n > 400 and memory.readbyte(0x2c) == 0 then memory.writebyte(0x30, lvl) end -- start at another level (debug)
  for i = 1, 4 do joypad.set(i, pads[i]) end
  emu.frameadvance()

  local fc = memory.readbyte(0x1a)
  if fc == lastfc then still = still + 1 else still = 0 end
  lastfc = fc
  if still == 600 then out:write("HANG at frame ", n, "\n") end
  maxsc = maxsc or {0, 0, 0, 0}
  for p = 0, 3 do
    if memory.readbyte(0x18) ~= 5 or memory.readbyte(0x2c) ~= 4 then break end
    local v = memory.readbyte(0x07e2 + p * 2) + memory.readbyte(0x07e3 + p * 2) * 256
    if v > maxsc[p + 1] then maxsc[p + 1] = v end
  end
  for b = 0, 15 do if memory.readbyte(0x448 + b) == 2 and memory.readbyte(0x388 + b) ~= 0 then p3bullets = p3bullets + 1 end end
  if n % 60 == 0 then
    local t = {}
    for p = 0, 3 do
      t[#t + 1] = string.format("p%d st=%d x=%02x y=%02x lv=%d go=%d spr=%02x", p + 1,
        memory.readbyte(0x90 + p), memory.readbyte(0x0334 + p), memory.readbyte(0x031a + p),
        memory.readbyte(LIVES + p), memory.readbyte(GO + p), memory.readbyte(0x0300 + p))
    end
    out:write(string.format("n=%d lvl=%d mode=%d gri=%d lri=%d | %s\n", n, memory.readbyte(0x30),
      memory.readbyte(0x22), memory.readbyte(0x18), memory.readbyte(0x2c), table.concat(t, " | ")))
  end
  if memory.readbyte(0x2c) == 2 and memory.readbyte(0x18) == 5 then restframes = (restframes or 0) + 1 end
  if not restshot and (restframes or 0) == 90 then
    restshot = true; gui.savescreenshotas(outPath .. "_rest.png")
  end
  if n % 1500 == 0 and n >= 1500 then
    shots = shots + 1
    gui.savescreenshotas(string.format("%s_%02d.png", outPath, shots))
  end
end
local sc = {}
for p = 0, 3 do sc[#sc + 1] = string.format("p%d=%d", p + 1, memory.readbyte(0x07e2 + p * 2) + memory.readbyte(0x07e3 + p * 2) * 256) end
out:write("p3 score writes ", p3writes, " p3 bullet-frames ", p3bullets, " max scores ", table.concat(maxsc, " "), " final scores ", table.concat(sc, " "), " max_gfx_offset=", maxgfx, "\n")
out:close()
os.exit()
