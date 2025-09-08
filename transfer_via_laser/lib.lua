local function NumberToBits(num)
  local bits = {}
  for i = 7, 0, -1 do
    bits[8-i] = tostring(math.floor(num / 2^i) % 2)
  end
  return bits
end

return {NumberToBits = NumberToBits}
