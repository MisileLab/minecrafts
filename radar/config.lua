-- Radar Configuration
-- This file contains all configurable settings for the radar system

local config = {
  -- Sensor configuration
  SCAN_RANGE = 128,         -- Maximum raycast distance (blocks)
  MIN_DISTANCE = 5,         -- Minimum distance to ignore own blocks (blocks)
  REFRESH_RATE = 0.05,      -- Scan interval (seconds)

  -- Alarm settings
  ALARM_RADIUS = 50,        -- Detection radius for alarm trigger (blocks)
  ALARM_SIDE = "top",       -- Redstone output side

  -- Monitor display
  MONITOR_SCALE = 0.5,      -- Text scale for monitor

  -- Peripheral names
  PERIPHERALS = {
    sensor = nil,   -- Will be set dynamically
    monitor = nil   -- Will be set dynamically
  },

  -- Function to find a peripheral by type
  findPeripheral = function(type)
    return peripheral.find(type)
  end
}

return config
