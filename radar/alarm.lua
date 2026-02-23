-- Radar Alarm Module
-- Manages redstone alert output based on target distance

local alarm = {}
local config

-- Initialize with configuration
function alarm.init(cfg)
  config = cfg
end

-- Check distance and control redstone output
-- Returns true if alarm is triggered, false otherwise
function alarm.check(closestDistance, alarmRadius)
  if closestDistance and closestDistance <= alarmRadius then
    redstone.setOutput(config.ALARM_SIDE, true)
    return true
  else
    redstone.setOutput(config.ALARM_SIDE, false)
    return false
  end
end

-- Force alarm off
function alarm.reset()
  if not config then return end
  redstone.setOutput(config.ALARM_SIDE, false)
end

return alarm
