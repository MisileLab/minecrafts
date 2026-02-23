# VS Radar: Exhaustive Lua Codebase Search Results

**Date**: 2026-02-23  
**Task**: Identify reusable trigonometry, coordinate conversion, and rendering patterns in existing Lua codebase for radar UI mapping.

## Executive Summary

**Finding**: No existing trigonometric, coordinate conversion, or rendering helpers exist in the codebase.

**Corollary**: All radar math and rendering must be implemented from scratch. However, several **pattern analogs** exist that can serve as templates for implementation.

---

## 1. Complete Lua File Inventory

### All 5 Lua Files (399 total lines)

| File | Lines | Purpose | Category |
|------|-------|---------|----------|
| `/Users/misile/repos/minecrafts/reactor/reactor_monitor.lua` | 183 | Reactor data collection + WebSocket comms | Data/Comms |
| `/Users/misile/repos/minecrafts/transfer_via_laser/receiver.lua` | 93 | Bit reception via redstone relays | Data Rx |
| `/Users/misile/repos/minecrafts/transfer_via_laser/main.lua` | 66 | Bit transmission via redstone relays | Data Tx |
| `/Users/misile/repos/minecrafts/reactor/config.lua` | 48 | Configuration module with helper functions | Config |
| `/Users/misile/repos/minecrafts/transfer_via_laser/lib.lua` | 9 | Number-to-bits conversion utility | Util |

---

## 2. Trigonometry & Math Search Results

### Direct Trigonometry: NONE FOUND
- `math.sin()` — NOT FOUND
- `math.cos()` — NOT FOUND
- `math.rad()` — NOT FOUND
- `math.atan2()` — NOT FOUND
- `math.deg()` — NOT FOUND
- `math.sqrt()` — NOT FOUND

### Math Operations Found (Limited)
| File | Line | Operation | Type |
|------|------|-----------|------|
| `transfer_via_laser/lib.lua` | 4 | `math.floor(num / 2^i) % 2` | Bit extraction |
| `reactor/reactor_monitor.lua` | 70-72 | `((value / capacity) * 100)` | Percentage normalization |

**Conclusion**: Only **percentage normalization** and **bit arithmetic** exist. No trigonometric helpers.

---

## 3. Coordinate Conversion & Position Search Results

### Coordinate-Related Code: NONE FOUND
- No `x`, `y`, `z` position tracking
- No polar-to-cartesian conversion
- No angle-based position calculation
- No distance calculations

### Numeric Computation Context
The closest analog is **percentage scaling** in `reactor_monitor.lua`:

```lua
-- reactor_monitor.lua:70-72
fuel_level = ((reactor.getFuel()["amount"] or 0) / (reactor.getFuelCapacity() or 1)) * 100,
coolant_level = ((reactor.getCoolant()["amount"] or 0) / (reactor.getCoolantCapacity() or 1)) * 100,
waste_level = ((reactor.getWaste()["amount"] or 0) / (reactor.getWasteCapacity() or 1)) * 100,
```

**Pattern**: `value / max * scaling_factor` — REUSABLE TEMPLATE for radar radius scaling:
- Replace `value` with `distance`
- Replace `max` with `SCAN_RANGE`
- Replace `scaling_factor` with `RADAR_SCREEN_RADIUS`

**Verdict**: Can adapt this pattern for screen space scaling, but no angular calculations present.

---

## 4. Rendering & UI Search Results

### Rendering Functions: NONE FOUND
- No `draw()` or `render()` functions
- No CC Monitor API usage (`term.write()`, `paintutils.*`, `colors.*`)
- No screen coordinate calculations
- No visual output helpers

### Output Operations Found
Only **text-based debug output** exists:

| File | Function | Purpose |
|------|----------|---------|
| `reactor/reactor_monitor.lua` | `print()` × 14 calls | Status messages |
| `transfer_via_laser/receiver.lua` | `print()` × 8 calls | Status messages |
| `transfer_via_laser/main.lua` | `print()` × 6 calls | Status messages |

**Verdict**: Zero rendering helpers. All radar UI must be built from scratch using CC Monitor APIs.

---

## 5. Loop & Iteration Patterns Found

### Loop Structures (REUSABLE)

#### Pattern 1: Simple Indexed Loop
**Location**: `transfer_via_laser/receiver.lua:51-60` (bit reading loop)
```lua
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
```

**Applicability**: ✓ Can reuse for iterating scan points (replace `8` with max angles)

#### Pattern 2: Main Event Loop
**Location**: `reactor/reactor_monitor.lua:146-166` (WebSocket + state machine loop)
```lua
while true do
  -- Check connection state
  if not ws then
    connectToServer()
  end
  
  -- Process data
  sendReactorData()
  
  -- Check for input
  local response = ws.receive(0.1)
  if response then
    handleCommand(response)
  end
  
  -- Sleep
  sleep(config.UPDATE_INTERVAL)
end
```

**Applicability**: ✓ Perfect template for radar main loop (replace WS comms with sensor reads)

#### Pattern 3: Timeout/State Transition Loop
**Location**: `transfer_via_laser/main.lua:25-30` (wait for acknowledgement)
```lua
while ack_relay.getInput("back") == 0 do
  os.sleep(0.01)
end
while ack_relay.getInput("back") ~= 0 do
  os.sleep(0.01)
end
```

**Applicability**: ✓ Can use for detecting 360° sweep completion (wait for angle to wrap)

---

## 6. Table & Data Structure Patterns (REUSABLE)

### Pattern 1: Configuration Table with Helper
**Location**: `reactor/config.lua:4-46`
```lua
local config = {
  SERVER_URL = "ws://localhost:8765/ws/computercraft/" .. os.getComputerID(),
  SECRET_KEY = "supersecretkey",
  UPDATE_INTERVAL = 1,
  ALERT_THRESHOLDS = {
    TEMPERATURE_DANGER = 1000,
    TEMPERATURE_CAUTION = 600,
  },
  findReactorPeripheral = function()
    local peripherals = peripheral.getNames()
    -- search logic
    return result
  end
}
return config
```

**Applicability**: ✓✓ EXACT PATTERN for `radar/config.lua`
- Reuse structure: constants + helper functions
- Reuse `peripheral.getNames()` + loop search pattern
- Example: `findPeripheral("optical_sensor")`

### Pattern 2: Data Aggregation Table
**Location**: `reactor/reactor_monitor.lua:68-89`
```lua
local data = {
  temperature = reactor.getTemperature(),
  fuel_level = ((reactor.getFuel()["amount"] or 0) / capacity) * 100,
  coolant_level = ...,
  waste_level = ...,
  status = reactor.getStatus(),
  burn_rate = reactor.getBurnRate(),
  alert_status = 0
}
return data
```

**Applicability**: ✓ Template for `state.lua` — replace reactor fields with:
```lua
{
  angle = scanner.getYaw(),
  distance = sensor.getDistance(),
  hit = (distance < maxDist),
  x = distance * math.cos(...),  -- NEW: will need to implement
  z = distance * math.sin(...),  -- NEW: will need to implement
  tick = os.clock()
}
```

### Pattern 3: Threshold-Based Alert
**Location**: `reactor/reactor_monitor.lua:79-87`
```lua
if data.temperature > config.ALERT_THRESHOLDS.TEMPERATURE_DANGER then
  data.alert_status = 2
elseif data.temperature > config.ALERT_THRESHOLDS.TEMPERATURE_CAUTION or data.coolant_level < ... then
  data.alert_status = 1
else
  data.alert_status = 0
end
```

**Applicability**: ✓ Template for `alarm.lua` distance-based trigger:
```lua
if closestDistance and closestDistance <= config.ALARM_RADIUS then
  redstone.setOutput(config.ALARM_SIDE, true)
else
  redstone.setOutput(config.ALARM_SIDE, false)
end
```

---

## 7. Peripheral & API Integration Patterns (REUSABLE)

### Pattern 1: Peripheral Discovery with Retry
**Location**: `reactor/reactor_monitor.lua:12-30` + `config.lua:23-45`
```lua
local function connectToReactor()
  print("Searching for fission reactor...")
  while not reactor do
    local reactorName = config.findReactorPeripheral()
    if reactorName then
      reactor = peripheral.wrap(reactorName)
      if reactor then
        print("Connected: " .. reactorName)
      else
        print("Failed to wrap " .. reactorName)
        sleep(5)
      end
    else
      print("Not found. Retrying in 5 seconds...")
      sleep(5)
    end
  end
end
```

**Applicability**: ✓✓ Perfect for `scanner.init(config)`:
```lua
function scanner.init(config)
  while not sensor do
    local sensorName = config.findPeripheral("optical_sensor")
    -- same retry logic
  end
  while not ship do
    if ship then  -- CC:VS API is global
      break
    else
      print("ship API not found")
      sleep(1)
    end
  end
end
```

### Pattern 2: Error Handling with pcall
**Location**: `reactor/reactor_monitor.lua:100-118` + `122-140`
```lua
local success, data = pcall(getReactorData)
if success then
  -- process data
else
  print("Error: " .. tostring(data))
  -- handle failure
end
```

**Applicability**: ✓ Can wrap `sensor.getDistance()` calls in pcall for fault tolerance.

### Pattern 3: Graceful Shutdown
**Location**: `reactor/reactor_monitor.lua:170-184`
```lua
local function shutdown()
  if ws then ws.close() end
  print("Monitoring stopped")
end

local success, main_err = pcall(main)
if not success then
  print("Error: " .. tostring(main_err))
end
shutdown()
```

**Applicability**: ✓ Can adapt for `radar/startup.lua` cleanup (reset alarm output, clear monitor).

---

## 8. JSON & Data Serialization

### Found
- `textutils.serializeJSON()` — `reactor_monitor.lua:102`
- `textutils.unserialiseJSON()` — `reactor_monitor.lua:122`

**Applicability**: ✗ Not needed for radar (no network comms, all local peripheral access).

---

## 9. String Handling & Formatting

### Pattern: String Concatenation
**Location**: `reactor/reactor_monitor.lua:36` + multiple others
```lua
local full_url = config.SERVER_URL .. "?secret=" .. config.SECRET_KEY
print("Error: " .. tostring(main_err))
```

**Applicability**: ✓ Can use for UI text formatting (e.g., `"Distance: " .. distance .. "m"`).

### Pattern: String Matching (Regex)
**Location**: `reactor/config.lua:29-31`
```lua
if string.match(name, "^fissionReactorLogicAdapter_") then
  local number = tonumber(string.match(name, "fissionReactorLogicAdapter_(%d+)"))
end
```

**Applicability**: ✓ Can use for sensor name matching (e.g., `"optical_sensor"` or by index).

---

## 10. Closest Analog Patterns for Radar Implementation

### For Coordinate Transformation
**No direct analog**, but can adapt:
- **Percentage scaling** pattern (reactor_monitor.lua:70-72) → Screen space scaling
- Need to implement from scratch: `polar_to_cartesian(angle, distance)`

### For Rendering
**No analog exists**. Will need to implement:
- CC Monitor Terminal API (`term.setBackgroundColor()`, `term.write()`, `paintutils.drawLine()`)
- CC Colors API (`colors.red`, `colors.green`, etc.)

### For Main Loop
**Strong analog**: `reactor_monitor.lua:146-166`
- Use for tick loop with sensor reading
- Adapt state machine (currently: await WS response → now: detect 360° sweep)

### For Config
**Exact analog**: `reactor/config.lua:4-46`
- Reuse structure verbatim
- Add `findPeripheral()` helper (same pattern)

### For State Management
**Strong analog**: `reactor_monitor.lua:52-89`
- Adapt data structure (replace reactor fields with scan results)
- Reuse error handling pattern

### For Alarm Logic
**Strong analog**: `reactor_monitor.lua:79-87`
- Adapt threshold comparison (temperature → distance)
- Replace alert_status with redstone.setOutput()

---

## 11. Missing Utilities (Must Implement)

| Utility | Type | Complexity | Notes |
|---------|------|-----------|-------|
| `math.sin()`, `math.cos()`, `math.atan2()` | Trig | Built-in Lua | Use directly, no wrapper needed |
| `math.rad()`, `math.deg()` | Trig | Built-in Lua | Use directly |
| `quaternion_to_yaw(quat)` | Math | Medium | New: Formula from plan lines 166-170 |
| `polar_to_cartesian(angle, distance)` | Math | Medium | New: `x = r*cos(θ)`, `z = r*sin(θ)` |
| `world_to_screen(wx, wy, radius, monW, monH)` | Graphics | Medium | New: Coordinate transform + centering |
| `draw_radar_frame(monitor, radius, colors)` | Graphics | High | New: Concentric circles + crosshairs |
| `draw_target(monitor, sx, sy, color)` | Graphics | Low | New: Simple point drawing |
| `draw_scan_line(monitor, angle, sx, sy, color)` | Graphics | Low | New: Radial line from center |

---

## 12. Recommendations for Radar Implementation

### Phase 1: Leverage Existing Patterns
1. **config.lua** — Use `reactor/config.lua` as exact template
2. **scanner.lua** — Adapt `reactor_monitor.lua:12-30` for sensor init
3. **state.lua** — Adapt `reactor_monitor.lua:52-89` for data structure
4. **startup.lua** — Adapt `reactor_monitor.lua:143-184` for main loop

### Phase 2: Implement New Math
1. Quaternion → Yaw conversion (plan provides formula)
2. Polar → Cartesian (standard math: `x = r*cos(θ)`, `z = r*sin(θ)`)
3. World → Screen scaling (linear transform with centering)

### Phase 3: Implement New Rendering
1. Use CC Monitor APIs directly (no wrapper needed if simple)
2. Implement frame drawing separately from target drawing
3. Test with mock data before integrating with scanner

### Phase 4: Reusable Patterns to Import
- **Peripheral discovery loop** (config.lua pattern) → `scanner.init()`
- **Error handling** (pcall wrapper) → sensor reads
- **Threshold comparison** (reactor_monitor.lua) → alarm logic
- **Main loop structure** (reactor_monitor.lua) → startup.lua

---

## 13. Evidence Summary

**Total Lua Files Analyzed**: 5  
**Total Lua Lines**: 399  
**Files With Math**: 2 (lib.lua, reactor_monitor.lua)  
**Files With Rendering**: 0  
**Files With Coords**: 0  
**Files With Trig**: 0  

**Reusable Patterns Found**: 8 (config, peripheral discovery, error handling, thresholds, main loop, data structures, string ops, table operations)

**Patterns CANNOT Reuse**: 3 (trigonometry, coordinate conversion, rendering)

---

## Conclusion

✅ **Config & Structure**: Use `reactor/config.lua` as template  
✅ **Peripheral Integration**: Use `reactor/reactor_monitor.lua` patterns (init, retry, error handling)  
✅ **State Management**: Use `reactor/reactor_monitor.lua` data structures  
✅ **Alarm Logic**: Use `reactor/reactor_monitor.lua` threshold pattern  
✅ **Main Loop**: Use `reactor/reactor_monitor.lua` event loop  
❌ **Trigonometry**: Implement from scratch (no existing helpers)  
❌ **Coordinate Conversion**: Implement from scratch (no existing helpers)  
❌ **Rendering**: Implement from scratch (no existing helpers)  

All radar code is **buildable with existing pattern templates**. No existing code for math/rendering exists to refactor.

