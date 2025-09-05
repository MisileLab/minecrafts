---@diagnostic disable-next-line: param-type-mismatch
local relayes = {peripheral.find("redstone_relay")}
write("> ")
local stre = read()
local bytes = {string.byte(stre, 1, stre:len())}
local lib = require "lib"
print("Sending " .. #bytes .. " bytes")
for i=1,#bytes do
  print("Sending byte " .. i .. ": " .. bytes[i])
  local byte = lib.NumberToBits(bytes[i])
  for j=1,8 do
    local bit = byte[j]
    local relay = relayes[j]
    if relay == nil then error("Relay " .. j .. " not found") end
    if bit == 1 then
---@diagnostic disable-next-line: undefined-field
      relay.setOutput("back", 15)
    else
---@diagnostic disable-next-line: undefined-field
      relay.setOutput("back", 0)
    end
  end
  print("Waiting for response...")
  while relayes[9].getInput("back") ~= 0 do
    os.sleep(0.01)
  end
  print("Response received. Go to next byte.")
end
