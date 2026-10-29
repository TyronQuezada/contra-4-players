-- Deterministic 2-player playthrough; dumps game state every frame.
-- Env: REGRESS_OUT = output log path, REGRESS_FRAMES = frame count
local outPath = os.getenv("REGRESS_OUT")
local frames = tonumber(os.getenv("REGRESS_FRAMES") or "20000")
local out = io.open(outPath, "w")
emu.speedmode("maximum")

local seed = 12345
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end

-- addresses unchanged by the 4-player RAM relocation
local watch = os.getenv("REGRESS_WIDE") and {
  {0x0010, 0x22}, {0x0035, 0x03}, {0x003a, 0x56}, {0x00dc, 0x15}, {0x00f3, 0x02}, {0x00f7, 0x02}, {0x00fb, 0x05},
  {0x0300, 0x400}, {0x07e0, 0x06}, {0x0200, 0x100},
} or {
  {0x001a, 1},  -- FRAME_COUNTER
  {0x0018, 2},  -- GAME_ROUTINE_INDEX
  {0x0090, 2},  -- PLAYER_STATE p1/p2
  {0x0300, 0x68}, -- sprite buffer: codes, Y, X, attrs (players, bullets, enemies)
  {0x07e2, 4},  -- scores
}

local function dump(f)
  local t = {}
  for _, w in ipairs(watch) do
    for a = w[1], w[1] + w[2] - 1 do t[#t + 1] = string.format("%02x", memory.readbyte(a)) end
  end
  out:write(f, " ", table.concat(t), " n=", emu.framecount(), "\n")
end

-- RANDOM_NUM ($34) is spun by the idle loop, so it depends on CPU cycles;
-- pin it at NMI entry so ROMs with different timing stay comparable
if os.getenv("REGRESS_PIN_RNG") then
  local nmi = memory.readbyte(0xfffa) + memory.readbyte(0xfffb) * 256
  memory.registerexec(nmi, function()
    if memory.readbyte(0x001b) == 0 then
      memory.writebyte(0x0034, (memory.readbyte(0x001a) * 37 + 11) % 256)
    end
  end)
end

local wlog
if os.getenv("REGRESS_WATCHW") then
  local wa = tonumber(os.getenv("REGRESS_WATCHW"), 16)
  wlog = io.open(outPath .. ".w", "w")
  memory.registerwrite(wa, 1, function(addr, size, val)
    wlog:write(string.format("fc=%02x pc=%04x a=%02x x=%02x y=%02x v=%02x\n", memory.readbyte(0x1a), memory.getregister("pc"), memory.getregister("a"), memory.getregister("x"), memory.getregister("y"), memory.readbyte(addr)))
  end)
end

local p = {{}, {}}
local ticks, last = 0, -1
for n = 1, frames do
  local fc = memory.readbyte(0x001a)
  local newtick = fc ~= last
  if newtick then ticks = ticks + 1; last = fc end
  local f = ticks
  local pad1, pad2 = {}, {}
  if f == 200 then pad1.select = true
  elseif f == 260 then pad1.start = true
  elseif f > 400 then
    for i, pad in ipairs({pad1, pad2}) do
      if newtick and f % 30 == 0 then p[i] = {right = rnd(10) < 7, left = rnd(10) < 1, up = rnd(10) < 2,
        down = rnd(10) < 2, A = rnd(10) < 3, B = rnd(10) < 6} end
      for k, v in pairs(p[i]) do pad[k] = v end
      if f % 600 == 0 then pad.start = true end -- keep starting/continuing
    end
  end
  joypad.set(1, pad1); joypad.set(2, pad2)
  emu.frameadvance()
  if memory.readbyte(0x001a) ~= fc then dump(f) end
  local stopAt = tonumber(os.getenv("REGRESS_RAMDUMP") or "-1")
  if f == stopAt and memory.readbyte(0x001a) ~= fc then
    local r = io.open(outPath .. ".ram", "wb")
    for a = 0, 0x7ff do r:write(string.char(memory.readbyte(a))) end
    r:close(); break
  end
end
out:close()
os.exit()
