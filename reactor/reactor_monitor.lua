-- Reactor Monitoring Script for ComputerCraft
-- Communicates with FastAPI server via WebSocket

-- Load configuration
local config = require("config")

-- Global variables for reactor and websocket
local reactor = nil
local ws = nil

-- Function to find and connect to reactor
local function connectToReactor()
  print("Searching for fission reactor...")
  while not reactor do
    -- Find the reactor peripheral with the smallest number
    local reactorName = config.findReactorPeripheral()
    if reactorName then
      reactor = peripheral.wrap(reactorName)
      if reactor then
        print("Fission reactor found and connected: " .. reactorName)
      else
        print("Failed to wrap reactor peripheral: " .. reactorName)
        sleep(5)
      end
    else
      print("No fission reactor found. Retrying in 5 seconds...")
      sleep(5)
    end
  end
end

-- Function to connect to WebSocket server
local function connectToServer()
  print("Connecting to monitoring server...")
  while not ws do
    local full_url = config.SERVER_URL .. "?secret=" .. config.SECRET_KEY
    ws, err = http.websocket(full_url)
    if not ws then
      print("Failed to connect to server: " .. tostring(err) .. ". Retrying in 5 seconds...")
      sleep(5)
    else
      print("Connected to reactor monitoring server")
    end
  end
end

-- Initial connections
connectToReactor()
connectToServer()

-- Function to get reactor data
local function getReactorData()
  local data = {
    temperature = reactor and reactor.getTemperature() or 0,
    fuel_level = reactor and ((reactor.getFuel()["amount"] or 0) / (reactor.getFuelCapacity() or 1)) * 100 or 0,
    coolant_level = reactor and ((reactor.getCoolant()["amount"] or 0) / (reactor.getCoolantCapacity() or 1)) * 100 or 0,
    waste_level = reactor and ((reactor.getWaste()["amount"] or 0) / (reactor.getWasteCapacity() or 1)) * 100 or 0,
    status = reactor and reactor.getStatus() or "disassembled",
    burn_rate = reactor and reactor.getBurnRate() or 0,
    actual_burn_rate = reactor and reactor.getActualBurnRate() or 0,
    alert_status = 0 -- Will be calculated based on conditions
  }

  -- Calculate alert status
  -- 0 = normal, 1 = caution, 2 = danger
  if data.temperature > config.ALERT_THRESHOLDS.TEMPERATURE_DANGER then
    data.alert_status = 2
  elseif data.temperature > config.ALERT_THRESHOLDS.TEMPERATURE_CAUTION or data.coolant_level < config.ALERT_THRESHOLDS.COOLANT_LOW_WARNING then
    data.alert_status = 1
  else
    data.alert_status = 0
  end

  return data
end

-- Function to send data to server
local function sendReactorData()
  -- Try to reconnect if reactor is not connected
  if not reactor then
    print("Reactor disconnected. Attempting to reconnect...")
    connectToReactor()
  end
  
  local success, data = pcall(getReactorData)
  if success then
    local jsonData = textutils.serializeJSON(data)
    local send_success, send_err = pcall(function()
      ws.send(jsonData)
      return true
    end)
    if not send_success then
      print("Failed to send data: " .. tostring(send_err))
      print("WebSocket connection lost. Attempting to reconnect...")
      ws = nil
      connectToServer()
    end
  else
    print("Error getting reactor data: " .. tostring(data))
    -- Reactor might have disconnected, try to reconnect
    reactor = nil
  end
end

-- Function to handle incoming commands
local function handleCommand(command_json)
  local success, data = pcall(textutils.unserialiseJSON, command_json)
  if success and type(data) == "table" then
    -- Check if reactor is still connected before executing commands
    if not reactor then
      print("Cannot execute command: Reactor not connected")
      return
    end
    
    if data.command == "emergency_stop" then
      reactor.setEmergencyShutdown(true)
      print("Emergency stop activated")
    elseif data.command == "coolant_speed" and data.value then
      reactor.setCoolantSpeed(data.value)
      print("Coolant speed set to " .. data.value)
    end
  else
    print("Failed to parse command: " .. tostring(data))
  end
end

-- Main loop
local function main()
  print("Starting reactor monitoring...")

  while true do
    -- Check if WebSocket is still connected
    if not ws then
      print("WebSocket disconnected. Attempting to reconnect...")
      connectToServer()
    end

    -- Send reactor data
    sendReactorData()

    -- Check for incoming commands
    if ws then
      local response = ws.receive(0.1) -- Non-blocking receive
      if response then
        handleCommand(response)
      end
    end

    -- Wait for next update
    sleep(config.UPDATE_INTERVAL)
  end
end

-- Handle shutdown gracefully
local function shutdown()
  if ws then
    ws.close()
  end
  print("Reactor monitoring stopped")
end

-- Run main loop with error handling
local success, main_err = pcall(main)
if not success then
  print("Error in main loop: " .. tostring(main_err))
end

-- Cleanup
shutdown()