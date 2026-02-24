-- Radar Startup / Main Loop
-- Integrates all radar modules: config, scanner, state, ui, alarm

local config  = require("config")
local scanner = require("scanner")
local state   = require("state")
local ui      = require("ui")
local alarm   = require("alarm")

local startup = {}

--- Initialize all radar subsystems.
local function init()
  scanner.init(config)
  state.init()
  ui.init(config)
  alarm.init(config)
end

--- Main radar loop.
-- Reads scan points each tick, detects 360° sweep boundaries,
-- then refreshes UI and checks alarm.
local function main()
  init()
  local lastAngle = 0

  while true do
    local point = scanner.readPoint()

    if point.hit then
      print(string.format("[DETECT] angle=%d° dist=%.1f x=%.1f z=%.1f", math.floor(point.angle), point.distance, point.x, point.z))
      state.addPoint(point)
    end

    local currentAngle = point.angle

    -- Detect sweep wraparound (crossed 0°)
    if lastAngle > 270 and currentAngle < 90 then
      ui.refresh(state.getSweepData(), currentAngle, config)
      alarm.check(state.getClosestDistance(), config.ALARM_RADIUS)
      state.clearSweep()
    end

    lastAngle = currentAngle
    os.sleep(config.REFRESH_RATE)
  end
end

--- Public entry point for external callers.
function startup.start()
  local ok, err = pcall(main)
  if not ok then
    print("Radar error: " .. tostring(err))
    alarm.reset()
  end
end

-- Auto-run when executed as a script (not require'd)
if not ... then
  startup.start()
end

return startup