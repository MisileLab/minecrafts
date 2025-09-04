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
    REACTOR = nil -- Will be set dynamically
  },

  -- Function to find the reactor peripheral with the smallest number
  findReactorPeripheral = function()
    local peripherals = peripheral.getNames()
    local reactorPeripherals = {}
    
    -- Find all peripherals that start with "fissionReactorLogicAdapter"
    for _, name in ipairs(peripherals) do
      if string.match(name, "^fissionReactorLogicAdapter_") then
        -- Extract the number from the peripheral name
        local number = tonumber(string.match(name, "fissionReactorLogicAdapter_(%d+)"))
        if number then
          table.insert(reactorPeripherals, {name = name, number = number})
        end
      end
    end
    
    -- Sort by number and return the one with the smallest number
    if #reactorPeripherals > 0 then
      table.sort(reactorPeripherals, function(a, b) return a.number < b.number end)
      return reactorPeripherals[1].name
    end
    
    return nil
  end
}

return config
