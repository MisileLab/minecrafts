# VS Radar: Learnings from Task 1 (config.lua)

**Date**: 2026-02-23

## Patterns Confirmed

1. **Config Module Structure**
   - `reactor/config.lua` pattern is a reliable baseline for radar config
   - Flat config table with constants + helper functions works well
   - `peripheral.find(type)` is the correct lookup pattern (not hardcoded names)

2. **Peripheral Discovery**
   - `findPeripheral(type)` wrapper around `peripheral.find()` is minimal and effective
   - Allows dynamic lookups in scanner/ui init functions
   - Type string `"optical_sensor"` will be used by scanner.lua

3. **Configuration Naming**
   - Constants use UPPER_CASE convention (consistent with reactor/config.lua)
   - Descriptive keys: SCAN_RANGE, MIN_DISTANCE, ALARM_RADIUS, ALARM_SIDE, MONITOR_SCALE, REFRESH_RATE
   - PERIPHERALS table uses lowercase keys for dynamic assignment

## Code Style
- Lua 5.1+ compatible (all standard library functions used)
- Comment style matches reactor/ module (inline unit documentation)
- Return statement at end (standard Lua module pattern)

## Dependencies for Future Tasks
- `scanner.lua` will call `config.findPeripheral("optical_sensor")` 
- `ui.lua` will call `config.findPeripheral("monitor")`
- `alarm.lua` will use `config.ALARM_RADIUS`, `config.ALARM_SIDE`
- All modules require() this config at startup

## Verification Success
- ✅ `luac -p` syntax check passed
- ✅ Constants exported correctly (SCAN_RANGE == 128)
- ✅ Function type check passed (`findPeripheral` is function)
- ✅ All required keys present: SCAN_RANGE, MIN_DISTANCE, ALARM_RADIUS, ALARM_SIDE, MONITOR_SCALE, REFRESH_RATE, PERIPHERALS
---

# VS Radar: Learnings from Task 2 (scanner.lua)

**Date**: 2026-02-23

## Implementation Decisions

1. **Retry Pattern for Peripheral**
   - Adopted reactor_monitor.lua's `while not X do ... sleep(5) end` pattern
   - `sensor.setMaxDistance(config.SCAN_RANGE)` called once during init after sensor found
   - Module-local `sensor` and `cfg` references avoid repeated lookups

2. **Quaternion → Yaw**
   - Formula: `atan2(2*(w*y - z*x), 1 - 2*(y^2 + z^2))`
   - Guarded with `pcall(ship.getQuaternion)` — returns 0 on failure
   - Normalized to [0, 360) via `if yaw < 0 then yaw = yaw + 360 end`
   - Identity quaternion {x=0,y=0,z=0,w=1} correctly yields yaw=0

3. **readPoint() Robustness**
   - `pcall(sensor.getDistance)` catches sensor disconnect mid-operation
   - On failure: returns max-range miss (hit=false, x=0, z=0)
   - MIN_DISTANCE filter: only computes x/z when `hit and distance > MIN_DISTANCE`
   - This prevents self-detection from Phys Bearing blocks

4. **ship API Availability**
   - `ship` is a global CC:VS API, only available on VS ships
   - Scanner warns but doesn't crash if ship API missing
   - getYaw() gracefully returns 0 — allows testing outside VS context

## API Contracts Confirmed
- `config.findPeripheral("optical_sensor")` works as expected from Task 1
- `sensor.getDistance()` returns float
- `sensor.setMaxDistance(int)` sets max raycast range
- `ship.getQuaternion()` returns table with {x, y, z, w} fields

## Verification
- ✅ `luac -p radar/scanner.lua` passed (exit 0)


# Task 3 Learnings (state.lua)

**Date**: 2026-02-23

## Data Structure Design

1. **Dual Container Pattern**
   - `sweepData`: Linear array of raw points from one 360° rotation
   - `targets`: Map keyed by floor(angle) for fast lookups and dedup
   - Separation allows UI to iterate raw points + alarm to query by closest distance
   - Targets persist across `clearSweep()` (intended for single-rotation UI updates)

2. **addPoint() Filtering**
   - Silently ignores nil or non-hit points (no error logging needed)
   - Stores angle-keyed targets for dedup (last point at angle wins)
   - Both containers populated for flexibility in downstream modules

3. **getClosestDistance() Implementation**
   - Iterates targets map, compares distance field
   - Returns nil if no targets (safe for alarm.lua null check)
   - Scanner/UI handle MIN_DISTANCE filtering upstream (not state's concern)

## Code Style Notes
- Minimal Lua: no comments beyond class docstring, functions self-document
- os.clock() used for tick tracking (precision not critical for UI refresh)
- Math.floor(angle) for key keeps map size bounded (360 max entries)

## Integration Points
- `scanner.lua` calls `addPoint(readPoint())` per frame
- `ui.lua` reads `getSweepData()` for point iteration + `getTargets()` for validation
- `alarm.lua` reads `getClosestDistance()` for radius check
- `startup.lua` calls `clearSweep()` after sweep boundary detection

## Verification Results
- ✅ Syntax: `luac -p` passed
- ✅ addPoint() stores in both containers
- ✅ getClosestDistance() returns minimum or nil
- ✅ clearSweep() clears raw data, preserves targets
- ✅ All acceptance criteria met
---

# Task 5 Learnings (alarm.lua)

**Date**: 2026-02-23

## Implementation Details

1. **Simple Threshold Pattern**
   - Stores config reference from `init(cfg)`
   - `check(closestDistance, alarmRadius)` uses distance ≤ radius logic (inclusive boundary)
   - Consistent with reactor/reactor_monitor.lua threshold pattern

2. **Nil Safety**
   - `if closestDistance and closestDistance <= alarmRadius` guards against nil distance
   - Treats missing target (nil) as safe condition → redstone output false
   - Matches plan spec for handling missing state.getClosestDistance()

3. **Redstone Output**
   - Uses `config.ALARM_SIDE` ("top" by default) for output direction
   - Direct `redstone.setOutput()` call per CC:Tweaked API
   - Pure: no state mutation, just peripheral control

4. **Reset Function**
   - Explicit `reset()` for graceful shutdown (used by startup.lua pcall wrapper)
   - Forces output false regardless of current state

## Integration Points
- Called from `startup.lua` after each 360° sweep boundary
- Receives distance from `state.getClosestDistance()` and radius from `config.ALARM_RADIUS`
- Called in shutdown path: `pcall(main)` catches error → `alarm.reset()`

## Verification
- ✅ Syntax: `luac -p` passed
- ✅ check(30, 50) → true, redstone output set
- ✅ check(80, 50) → false, redstone output cleared
- ✅ check(nil, 50) → false (nil safety confirmed)
- ✅ reset() → clears output unconditionally

---

# Task 4 Learnings (ui.lua)

**Date**: 2026-02-23

## Implementation Details

1. **Headless Safety Pattern**
   - Every public function guards `if not mon then return end`
   - Private `writeAt()` also nil-checks `mon` before any peripheral call
   - `init(nil)` is safe — no crash on nil config or missing monitor
   - Fully degrades to no-op when no monitor attached

2. **worldToScreen Coordinate Mapping**
   - `scale = min(monW, monH) / 2 / radarRadius` — fits radar in smaller axis
   - Center: `floor(width/2), floor(height/2)` — integer pixel coords
   - Origin (0,0) maps to exact center: `worldToScreen(0,0,128,40,20)` → `(20,10)`
   - Full range target at (128,0) maps to `(30,10)` — edge of half-screen

3. **Rendering Layers (bottom to top)**
   - Clear (black background)
   - Crosshair: horizontal `-` and vertical `|` in green
   - Center marker: `+` in green
   - Info text: `T:<count> D:<dist>` at (1,1) in white
   - Scan line endpoint: `.` in lime at current angle
   - Targets: `X` in red — plotted last so they overlay frame

4. **Bounded Write Helper**
   - `writeAt(x, y, text, color)` clips to monitor bounds
   - Prevents CC monitor errors from out-of-bounds cursor positions
   - Color parameter optional — preserves current color if nil

5. **refresh() Nil Safety**
   - `sweepData and #sweepData or 0` handles nil sweep data
   - Closest distance computed inline (no dependency on state module)
   - currentAngle can be nil — scan line simply not drawn

## Integration Points for Task 6
- `ui.init(config)` — call once, passes config with findPeripheral
- `ui.refresh(sweepData, currentAngle, config)` — call after each 360° sweep
- All CC color constants used: `colors.black`, `colors.green`, `colors.red`, `colors.lime`, `colors.white`

## Verification
- ✅ `luac -p radar/ui.lua` passed (exit 0)
- ✅ `worldToScreen(0,0,128,40,20)` → `(20,10)` confirmed
- ✅ All 5 exports present: init, worldToScreen, drawFrame, plotTargets, refresh
- ✅ Headless safety: nil config, no monitor, nil sweepData — all no-crash
- ✅ ASCII-only characters: `-`, `|`, `+`, `X`, `.`

---

# Task 6 Learnings (startup.lua)

**Date**: 2026-02-23

## Implementation Details

1. **Module Integration Order**
   - `init()` calls: scanner → state → ui → alarm
   - scanner.init blocks until optical sensor found (retry loop in scanner.lua)
   - state/ui/alarm inits are instant (no blocking peripherals)

2. **Sweep Boundary Detection**
   - `lastAngle > 270 and currentAngle < 90` detects 0° crossing
   - On boundary: ui.refresh → alarm.check → state.clearSweep (order matters)
   - clearSweep last so UI/alarm can read current sweep data first

3. **Auto-run Guard: `if not ... then`**
   - `...` is the vararg containing module name when loaded via `require()`
   - When executed directly (e.g., CC startup), `...` is nil/falsy → auto-runs
   - When `require("startup")`, `...` is the module name → skips auto-run
   - Enables both `startup.start()` API and direct script execution

4. **Error Handling**
   - `pcall(main)` wraps entire loop; any error triggers alarm.reset()
   - Individual sensor failures handled inside scanner.readPoint() (returns safe miss)
   - No restart loop at this level — CC:Tweaked users typically use `shell.run` for restart

## Integration Points
- Requires all 5 modules via `require("name")` — CC:Tweaked resolves from same directory
- `startup.start()` exported for programmatic invocation
- `return startup` enables `require("startup")` pattern

## Verification
- ✅ `luac -p radar/startup.lua` passed (exit 0)
- ✅ All require() paths resolve with mocked CC globals
- ✅ `startup.start` function exported and callable
- ✅ Auto-run guard works (require doesn't trigger main loop)
---

# Task 4 Remediation: Ring & Scan Line Rendering

**Date**: 2026-02-23

## Ring Rendering Strategy

### Challenge
Task 4 plan requires "동심원" (concentric circles), but CC:Tweaked monitor is character-based ASCII grid.
True circle rasterization not feasible with single-character primitives.

### Solution: Cardinal Direction Markers
Instead of full circles, mark cardinal directions (N/S/E/W) at three ring distances:
- 25%, 50%, 75% of radar radius
- Each ring: four `*` markers at top, bottom, left, right
- Provides distance reference without over-rendering

### Implementation Detail
```lua
local rings = {0.25, 0.5, 0.75}
for _, ratio in ipairs(rings) do
  local r = math.floor(math.min(monW, monH) / 2 * ratio)
  writeAt(cx, cy - r, "*", colors.green)  -- North
  writeAt(cx, cy + r, "*", colors.green)  -- South
  writeAt(cx - r, cy, "*", colors.green)  -- West
  writeAt(cx + r, cy, "*", colors.green)  -- East
end
```

**Why math.floor(math.min(monW, monH) / 2 * ratio)**:
- `math.min(monW, monH) / 2`: Radius in pixels (fits to smaller axis)
- `* ratio`: Scale to 25%, 50%, 75%
- `math.floor()`: Integer pixel coordinates for ASCII grid

## Scan Line Rendering Algorithm

### Challenge
Parametric line from (cx, cy) to (sx, sy) with discrete characters only.
Cannot use `paintutils.drawLine()` safely (may not exist in all CC:Tweaked configs).

### Solution: Parametric Interpolation (10-segment)
```lua
local steps = 10
for step = 1, steps do
  local t = step / steps           -- Parameter 0.0 to 1.0
  local ix = math.floor(cx + (sx - cx) * t)
  local iy = math.floor(cy + (sy - cy) * t)
  writeAt(ix, iy, "-", colors.lime)
end
```

**Why 10 segments?**
- 10 dashes spread evenly from center to endpoint
- Dense enough for visual line at typical monitor sizes (40x20)
- Sparse enough to avoid character density overload
- `step / steps` produces t ∈ [0.1, 0.2, ..., 1.0] (includes endpoint)

**Why separate endpoint marker (`"."` instead of `"-"`)?**
- Marks active scanning direction more clearly
- Different character provides visual emphasis
- Consistent with plan spec "현재 센서 방향 표시"

### Edge Cases Handled
1. `currentAngle = nil` → Line not drawn (guard: `if currentAngle then`)
2. Endpoint outside bounds → `writeAt()` clips it (boundary check: `if x < 1 or y < 1 or x > monW or y > monH`)
3. Degenerate line (cx==sx, cy==sy) → Multiple dots stacked, still renders correctly

## Coordinate Contract Maintained

Both additions preserve the existing `worldToScreen()` contract:
- World coords (wx, wz) in ship-relative coordinates
- Scaled to screen with `scale = math.min(mw, mh) / 2 / radarRadius`
- Center offset: `(cx, cy) = floor(mw/2), floor(mh/2)`
- Endpoint calculation for scan line uses same math as plotTargets

No changes to `ui.worldToScreen()` function or its contract.

## Rendering Layer Order (Bottom to Top)

1. **Clear**: `mon.clear()` (black background)
2. **Rings**: Cardinal markers at 25%, 50%, 75% rings (green `*`)
3. **Crosshair**: Horizontal/vertical lines (green `-`, `|`)
4. **Center**: Center marker (green `+`)
5. **Info text**: `T:<count> D:<dist>` (white, top-left)
6. **Scan line**: Parametric trace from center to endpoint (lime `-` + endpoint `.`)
7. **Targets**: Red `X` markers (plotted last, overlay everything)

Order ensures:
- Frame (rings + crosshair) provides reference grid
- Scan line visible over frame (lime vs green contrast)
- Targets visible over scan line (red vs lime contrast)

## Backward Compatibility

All changes confined to `drawFrame()` and `refresh()` internals:
- No change to function signatures
- No change to module exports
- No change to config requirements
- No change to UI contract with startup.lua

Existing `ui.init()`, `ui.worldToScreen()`, `ui.plotTargets()` remain identical.

---

# Quality Closure: MIN_DISTANCE and Nil-Config Fixes

**Date**: 2026-02-23

## Scanner: MIN_DISTANCE in Hit Logic

**Pattern Learned**: Distance filtering must apply at hit-detection time, not downstream

When computing `hit`, BOTH boundaries matter:
```lua
local hit = (distance < cfg.SCAN_RANGE and distance > cfg.MIN_DISTANCE)
```

**Rationale**:
- `distance < SCAN_RANGE`: Detects any reflection (optical sensor returns SCAN_RANGE on miss)
- `distance > MIN_DISTANCE`: Filters self-ship reflections (blocks at distance ~3)
- Combined: Only marks hits for valid external targets

**Consequence**: 
- Even though x/z computation downstream was guarded by `if hit and distance > cfg.MIN_DISTANCE`,
  the hit flag itself must enforce MIN_DISTANCE
- Otherwise alarm downstream sees hit=true for self-blocks, triggers false alarm

**Code Organization**:
- x/z computation guard (`if hit and distance > cfg.MIN_DISTANCE`) can remain as safety redundancy
- But hit flag is the source of truth for state/alarm

## Alarm: Config Guard in Reset

**Pattern Learned**: Defensive guards required on module-local state in error handlers

When `alarm.reset()` is called in startup.lua's pcall error handler:
```lua
function alarm.reset()
  if not config then return end  -- Guard: init may not have completed
  redstone.setOutput(config.ALARM_SIDE, false)
end
```

**Rationale**:
- startup.lua error handler may catch errors BEFORE alarm.init() runs
- config local would be nil → indexing nil = crash
- Reset is meant to gracefully shut down alarm regardless of state

**Code Order** (startup.lua):
1. scanner.init (can error if sensor not found)
2. state.init (instant)
3. ui.init (instant)
4. alarm.init (instant, but happens AFTER scanner which can error)
5. Main loop (if any module init failed, we're in pcall error handler calling alarm.reset)

**Guard Pattern**: Applies to any module with state that's assigned during init.
All three guard types safe:
- `if not config then return end` → no-op when uninitialized
- `if config and config.field then ...` → explicit nil check
- `if config == nil then return end` → explicit equality

## Integration Notes

Both fixes preserve API contracts:
- scanner.readPoint() still returns {angle, distance, hit, x, z}
- alarm.reset() still accepts no args, returns nothing
- alarm.init(config) signature unchanged
- alarm.check(distance, radius) behavior identical

Fixes are internal logic refinements, not signature changes.
