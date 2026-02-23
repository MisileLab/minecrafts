-- Radar UI Module
-- 2D monitor rendering for radar sweep display

local ui = {}

local mon = nil
local monW, monH = 0, 0

-- Initialize monitor peripheral (headless-safe)
function ui.init(config)
  if config and config.findPeripheral then
    mon = config.findPeripheral("monitor")
  end
  if mon then
    mon.setTextScale(config.MONITOR_SCALE or 0.5)
    monW, monH = mon.getSize()
  end
end

-- Convert world coordinates to screen coordinates
-- Returns pixel position on monitor for given world offset
function ui.worldToScreen(wx, wz, radarRadius, mw, mh)
  local scale = math.min(mw, mh) / 2 / radarRadius
  local cx = math.floor(mw / 2)
  local cy = math.floor(mh / 2)
  local sx = cx + math.floor(wx * scale)
  local sy = cy + math.floor(wz * scale)
  return sx, sy
end

-- Internal: bounded write to monitor
local function writeAt(x, y, text, color)
  if not mon then return end
  if x < 1 or y < 1 or x > monW or y > monH then return end
  if color then mon.setTextColor(color) end
  mon.setCursorPos(x, y)
  mon.write(text)
end

-- Draw radar frame: crosshair + concentric circles/rings
function ui.drawFrame(config)
  if not mon then return end
  mon.setBackgroundColor(colors.black)
  mon.clear()

  local cx = math.floor(monW / 2)
  local cy = math.floor(monH / 2)
  local radarRadius = config and config.SCAN_RANGE or 128

  -- Draw concentric circles/rings at 25%, 50%, 75% of radius
  -- Using simple ASCII approximation: circle markers at cardinal directions
  local rings = {0.25, 0.5, 0.75}
  for _, ratio in ipairs(rings) do
    local r = math.floor(math.min(monW, monH) / 2 * ratio)
    -- Cardinal directions: top, bottom, left, right
    writeAt(cx, cy - r, "*", colors.green)
    writeAt(cx, cy + r, "*", colors.green)
    writeAt(cx - r, cy, "*", colors.green)
    writeAt(cx + r, cy, "*", colors.green)
  end

  -- Horizontal crosshair
  for x = 1, monW do
    writeAt(x, cy, "-", colors.green)
  end

  -- Vertical crosshair
  for y = 1, monH do
    writeAt(cx, y, "|", colors.green)
  end

  -- Center marker
  writeAt(cx, cy, "+", colors.green)
end

-- Plot target markers from sweep data
function ui.plotTargets(sweepData, config)
  if not mon or not sweepData then return end
  local radius = config and config.SCAN_RANGE or 128
  for i = 1, #sweepData do
    local pt = sweepData[i]
    if pt.hit and pt.x and pt.z then
      local sx, sy = ui.worldToScreen(pt.x, pt.z, radius, monW, monH)
      writeAt(sx, sy, "X", colors.red)
    end
  end
end

-- Full render cycle: frame + info + scanline + targets
function ui.refresh(sweepData, currentAngle, config)
  if not mon then return end
  local cfg = config or {}
  local radius = cfg.SCAN_RANGE or 128

  ui.drawFrame(cfg)

  -- Info line: target count + closest distance
  local count = sweepData and #sweepData or 0
  local closest = nil
  if sweepData then
    for i = 1, #sweepData do
      local d = sweepData[i].distance
      if d and (not closest or d < closest) then
        closest = d
      end
    end
  end
  local info = "T:" .. count
  if closest then
    info = info .. " D:" .. math.floor(closest)
  end
  writeAt(1, 1, info, colors.white)

  -- Scan line: from center to endpoint
  if currentAngle then
    local rad = math.rad(currentAngle)
    local ex = radius * math.cos(rad)
    local ez = radius * math.sin(rad)
    local sx, sy = ui.worldToScreen(ex, ez, radius, monW, monH)
    
    -- Draw line from center to endpoint using simple ASCII trace
    local cx = math.floor(monW / 2)
    local cy = math.floor(monH / 2)
    local steps = 10  -- Number of segments for line approximation
    for step = 1, steps do
      local t = step / steps
      local ix = math.floor(cx + (sx - cx) * t)
      local iy = math.floor(cy + (sy - cy) * t)
      writeAt(ix, iy, "-", colors.lime)
    end
    -- Endpoint marker (brighter than line)
    writeAt(sx, sy, ".", colors.lime)
  end

  -- Plot targets on top of frame
  ui.plotTargets(sweepData, cfg)
end

return ui
