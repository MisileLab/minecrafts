-- Radar Scanner Module
-- Reads optical sensor distance + ship quaternion to produce scan points

local scanner = {}

-- Module-local references (set during init)
local sensor = nil
local cfg = nil

--- Initialize scanner peripherals and config.
-- Retries sensor lookup until found (blocks with sleep).
-- @param config  The radar config table from config.lua
function scanner.init(config)
  cfg = config

  -- Retry loop for optical sensor (mirrors reactor_monitor.lua pattern)
  print("Searching for optical sensor...")
  while not sensor do
    sensor = config.findPeripheral("optical_sensor")
    if sensor then
      sensor.setMaxDistance(config.SCAN_RANGE)
      print("Optical sensor found. Max distance set to " .. config.SCAN_RANGE)
    else
      print("No optical sensor found. Retrying in 5 seconds...")
      sleep(5)
    end
  end

  -- Verify ship API is available (running on a VS ship / Phys Bearing)
  if not ship or not ship.getQuaternion then
    print("Warning: ship API not available. Yaw readings will default to 0.")
  end
end

--- Extract yaw (0-360 degrees) from the ship quaternion.
-- Formula: yaw = atan2(2*(w*y - z*x), 1 - 2*(y^2 + z^2))
-- Returns 0 if ship API is unavailable.
-- @return number  yaw in degrees [0, 360)
function scanner.getYaw()
  if not ship or not ship.getQuaternion then
    return 0
  end

  local ok, q = pcall(ship.getQuaternion)
  if not ok or not q then
    return 0
  end

  -- Handle both {x,y,z,w} and {1,2,3,4} indexed formats
  local x = q.x or q[1] or 0
  local y = q.y or q[2] or 0
  local z = q.z or q[3] or 0
  local w = q.w or q[4] or 0

  local siny = 2 * (w * y - z * x)
  local cosy = 1 - 2 * (y * y + z * z)
  local yaw = math.deg(math.atan2(siny, cosy))

  if yaw < 0 then
    yaw = yaw + 360
  end

  return yaw
end

--- Read a single scan point from the sensor.
-- @return table  { angle=number, distance=number, hit=bool, x=number, z=number }
function scanner.readPoint()
  local angle = scanner.getYaw()

  local ok, distance = pcall(sensor.getDistance)
  if not ok then
    -- Sensor read failed; treat as max-range miss
    return { angle = angle, distance = cfg.SCAN_RANGE, hit = false, x = 0, z = 0 }
  end

  local hit = (distance < cfg.SCAN_RANGE and distance > cfg.MIN_DISTANCE)

  local x, z = 0, 0
  if hit and distance > cfg.MIN_DISTANCE then
    local rad = math.rad(angle)
    x = distance * math.cos(rad)
    z = distance * math.sin(rad)
  end

  return { angle = angle, distance = distance, hit = hit, x = x, z = z }
end

return scanner