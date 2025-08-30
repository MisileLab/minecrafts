-- Reactor Monitor Configuration
-- This file contains all configurable settings for the reactor monitoring system

local config = {
  -- Server connection settings
  SERVER_URL = "ws://localhost:8765/ws/computercraft/" .. os.getComputerID(),
  SECRET_KEY = "supersecretkey", -- IMPORTANT: Change this to match your server's SECRET_KEY
  UPDATE_INTERVAL = 1, -- seconds

  -- Alert thresholds
  ALERT_THRESHOLDS = {
    TEMPERATURE_DANGER = 1000,  -- Temperature threshold for danger alert
    TEMPERATURE_CAUTION = 600,  -- Temperature threshold for caution alert
    COOLANT_LOW_WARNING = 20,   -- Coolant level threshold for caution alert (%)
  },

  -- Peripheral names
  PERIPHERALS = {
    REACTOR = "fissionReactorLogicAdapter_0"
  }
}

return config
