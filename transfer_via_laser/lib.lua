function NumberToBits(num)
  if num == 0 then return "0" end
  local bits = {}
  while num > 0 do
      table.insert(bits, 1, tostring(num % 2))
      num = math.floor(num / 2)
  end
  return bits
end

return {NumberToBits = NumberToBits}
