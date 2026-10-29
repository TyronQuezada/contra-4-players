-- CPU profile of the NMI game loop (needs an FCEUX with the Four Score attached).
-- Env: PROF_OUT = output file, PROF_FRAMES, PROF_PRESSES (select presses: 1 = 2P, 3 = 4P),
--      PROF_ADDR_<label> = hex address of each label below (filled by profile.ps1)
local out = io.open(os.getenv("PROF_OUT"), "w")
local frames = tonumber(os.getenv("PROF_FRAMES") or "6000")
local presses = tonumber(os.getenv("PROF_PRESSES") or "3")
emu.speedmode("maximum")

local function a(name) return tonumber(os.getenv("PROF_ADDR_" .. name), 16) end
-- consecutive checkpoints of one game frame; section i = checkpoint i -> i+1
local points = {"load_controller_state", "set_frame_scroll_draw_player_bullets", "load_bank_6_run_player_bullet_routines", "draw_player_bullet_sprites", "load_bank_3_handle_scroll",
  "load_bank_0_exe_all_enemy_routine", "load_bank_2_load_screen_enemy_data", "write_0_to_cpu_graphics_buffer"}
local names = {"input", "players", "bullet routines", "bullet sprites", "scroll", "enemies+collisions", "soldiers+sprites"}
local stamp, sum, peak, count = {}, {}, {}, 0
for i = 1, #names do sum[i] = 0; peak[i] = 0 end
local playing = false
for i, p in ipairs(points) do
  memory.registerexec(a(p), function() stamp[i] = debugger.getcyclescount() end)
end
memory.registerexec(a("write_0_to_cpu_graphics_buffer"), function()
  stamp[#points] = debugger.getcyclescount()
  if not playing then return end
  local ok = true
  for i = 1, #points do if not stamp[i] then ok = false end end
  if ok then
    local tot = stamp[#points] - stamp[1]
    local objs = 0
    for sl = 0, 25 do if memory.readbyte(0x0300 + sl) ~= 0 then objs = objs + 1 end end
    for sl = 0, 15 do if memory.readbyte(0x0388 + sl) ~= 0 then objs = objs + 1 end end
    objhist = objhist or {}
    local key = objs
    objhist[key] = objhist[key] or {0, 0}
    objhist[key][1] = objhist[key][1] + 1
    if tot > 24000 then objhist[key][2] = objhist[key][2] + 1 end
    if tot > 24000 then
      heavy = (heavy or 0) + 1
      heavySum = heavySum or {}
      for i = 1, #names do heavySum[i] = (heavySum[i] or 0) + stamp[i + 1] - stamp[i] end
    end
    count = count + 1
    for i = 1, #names do
      local d = stamp[i + 1] - stamp[i]
      sum[i] = sum[i] + d
      if d > peak[i] then peak[i] = d end
    end
  end
  stamp = {}
end)
local lag, gameFrames = 0, 0
memory.registerexec(a("nmi_start"), function()
  if playing then
    gameFrames = gameFrames + 1
    if memory.readbyte(0x1b) ~= 0 then lag = lag + 1 end
  end
end)

local seed = 4242
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end
local held = {{}, {}, {}, {}}
for n = 1, frames do
  local pads = {{}, {}, {}, {}}
  if n >= 300 and n < 300 + presses * 20 and n % 20 == 0 then pads[1].select = true end
  if n == 400 then pads[1].start = true end
  if n > 600 then
    for i = 1, 4 do
      if n % 25 == i then held[i] = {right = rnd(10) < 7, left = rnd(10) < 1, up = rnd(10) < 2,
        down = rnd(10) < 2, A = rnd(10) < 3, B = rnd(10) < 7} end
      for k, v in pairs(held[i]) do pads[i][k] = v end
    end
    if n % 900 == 0 then pads[1].start = true; pads[1].A = false end
  end
  local demo = os.getenv("PROF_DEMO")
  if demo then
    playing = memory.readbyte(0x1c) == 1 and memory.readbyte(0x2c) == 4 and memory.readbyte(0x30) == tonumber(demo)
  else
    for i = 1, 4 do joypad.set(i, pads[i]) end
    playing = memory.readbyte(0x18) == 5 and memory.readbyte(0x2c) == 4
  end
  emu.frameadvance()
end
out:write(string.format("frames=%d lag=%d (%.1f%%)\n", gameFrames, lag, gameFrames > 0 and lag * 100 / gameFrames or 0))
local total = 0
for i = 1, #names do
  local avg = count > 0 and sum[i] / count or 0
  total = total + avg
  out:write(string.format("%-20s avg=%6.0f peak=%6d\n", names[i], avg, peak[i]))
end
out:write(string.format("%-20s avg=%6.0f (frame budget ~29780 cycles)\n", "total", total))
if objhist then
  out:write("objects (sprite slots + bullets): frames, heavy\n")
  for k = 0, 50 do if objhist[k] then out:write(string.format("  %2d: %5d %5d\n", k, objhist[k][1], objhist[k][2])) end end
end
if heavy then
  out:write(string.format("heavy frames (>24000 in game loop): %d, average breakdown:\n", heavy))
  for i = 1, #names do out:write(string.format("  %-20s %6.0f\n", names[i], heavySum[i] / heavy)) end
end
out:close()
os.exit()
