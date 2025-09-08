-- Find peripheral devices. Finds 8 input relays and 1 ack relay.
-- When setting up the world, you must ensure the relays are connected in the correct order.
-- This code assumes the peripherals are connected sequentially on the cable.
local relays = peripheral.find("redstone_relay", nil, true)
if #relays < 9 then
  error("Error: Could not find at least 9 redstone relays.")
end

-- Assign the first 8 relays for input, and the 9th for acknowledgement.
local inputs = {}
for i=1,8 do
  inputs[i] = relays[i]
end
local ack_relay = relays[9]

print("Found 8 input relays and 1 acknowledgement relay.")

-- Function to convert a table of bits (as "1" or "0") to a number.
local function BitsToNumber(bits)
  local num = 0
  for i=1, #bits do
    num = num * 2
    if bits[i] == "1" then
      num = num + 1
    end
  end
  return num
end

-- Function to send an acknowledgement pulse (HIGH, then LOW)
local function send_ack()
    print("Sending acknowledgement...")
    ack_relay.setOutput("back", 15)
    os.sleep(0.1) -- Pulse duration
    ack_relay.setOutput("back", 0)
    print("Acknowledgement sent.")
end

local received_string = ""
-- State flag: true if waiting for a non-zero byte, false if waiting for a zero byte.
local waiting_for_data = true 

print("Waiting for data...")

while true do
  local current_bits = {}
  local current_bits_str = ""
  local is_zero = true

  -- 1. Read the current bit state from the 8 relays.
  for i=1,8 do
    if inputs[i].getInput("back") > 0 then
      table.insert(current_bits, "1")
      current_bits_str = current_bits_str .. "1"
      is_zero = false
    else
      table.insert(current_bits, "0")
      current_bits_str = current_bits_str .. "0"
    end
  end

  -- 2. State machine logic
  if waiting_for_data then
    -- We are expecting a byte of data.
    if not is_zero then
      print("Data detected: " .. current_bits_str)

      -- 3. Convert bits to a byte, then to a character.
      local byte_val = BitsToNumber(current_bits)
      local char = string.char(byte_val)
      received_string = received_string .. char

      print("Received byte: " .. byte_val .. " ('" .. char .. "')")
      print("Current received string: \"" .. received_string .. "\"")

      -- 4. Send acknowledgement and change state to wait for the "clear" signal.
      send_ack()
      waiting_for_data = false
      print("Waiting for lines to clear...")
    end
  else
    -- We are expecting the lines to be cleared (all zeroes).
    if is_zero then
      print("Lines cleared.")
      -- 4. Send acknowledgement and change state to wait for the next byte.
      send_ack()
      waiting_for_data = true
      print("Waiting for next byte...")
    end
  end

  -- 5. A short delay to prevent the loop from running too fast.
  os.sleep(0.05)
end