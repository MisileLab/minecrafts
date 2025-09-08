-- Find all available redstone relays.
-- The first 8 are for data, the 9th is for receiving acknowledgement.
-- Ensure they are cabled in the correct order in the game world.
local relays = peripheral.find("redstone_relay", nil, true)
if #relays < 9 then
    error("Error: Could not find at least 9 redstone relays.")
end

-- The 9th relay is used for the acknowledgement signal from the receiver.
local ack_relay = relays[9]

-- Function to clear data lines
local function clear_lines()
    print("Clearing data lines...")
    for j=1,8 do
        if relays[j] == nil then error("Relay " .. j .. " not found") end
        relays[j].setOutput("back", 0)
    end
end

-- Function to wait for an acknowledgement pulse (HIGH, then LOW)
local function wait_for_ack()
    print("Waiting for response...")
    -- Wait for the acknowledgement line to go HIGH
    while ack_relay.getInput("back") == 0 do
        os.sleep(0.01)
    end
    -- Now wait for it to go LOW again
    while ack_relay.getInput("back") ~= 0 do
        os.sleep(0.01)
    end
    print("Response received.")
end

local lib = require "lib"

-- Main program
write("Enter string to send: ")
local message = read()
local bytes = {string.byte(message, 1, #message)}

print("Sending " .. #bytes .. " bytes")

for i=1, #bytes do
    -- Send the actual byte
    print("Sending byte " .. i .. "/" .. #bytes .. ": " .. bytes[i])
    local bits = lib.NumberToBits(bytes[i])
    for j=1,8 do
        local bit = bits[j]
        local relay = relays[j]
        if relay == nil then error("Relay " .. j .. " not found") end
        if bit == 1 then
            relay.setOutput("back", 15)
        else
            relay.setOutput("back", 0)
        end
    end
    wait_for_ack()

    -- Clear the lines to signal end of byte
    clear_lines()
    wait_for_ack()
end

print("Transmission complete.")
clear_lines() -- Final clear
