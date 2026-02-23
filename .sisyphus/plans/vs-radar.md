# VS Radar System - Work Plan

## TL;DR
> **Summary**: CC:Tweaked Lua 레이더 프로그램. Clockwork Phys Bearing 위에 Optical Sensor를 탑재, Create 동력으로 360° 회전하며 VS 배를 탐지. 2D 모니터 맵 + 레드스톤 경보.
> **Deliverables**: `radar/` 디렉토리에 6개 Lua 파일 (config, scanner, state, ui, alarm, startup)
> **Effort**: Medium
> **Parallel**: YES - 2 waves
> **Critical Path**: config → scanner → state → ui/alarm → startup

## Context

### Original Request
CC:Tweaked + Valkyrien Skies 환경에서 다른 Ship을 탐지하는 레이더 프로그램 제작.

### Interview Summary
- **VS 배는 Minecraft Entity가 아님** — `shipObjectWorld`에 존재하는 물리 객체. 표준 Entity 스캐너(AP 등)로 탐지 불가.
- **Create: Propulsion Optical Sensor** — 레이캐스트 블록 감지기. CC 페리페럴 통합 있음 (`getDistance()`, `setMaxDistance()`). VS2 공식 지원.
- **Clockwork Phys Bearing** — 회전부가 VS Ship이 됨. CC Computer 정상 작동. Create 동력으로 회전.
- **CC:VS API** — `ship.getQuaternion()` 으로 각도 읽기 (Command Computer 불필요). 토크 제어는 Command Computer 필요하지만 각도 읽기만 하므로 무관.
- **사용자 인게임 테스트**: Optical Sensor 페리페럴 확인됨.

### Metis Review (gaps addressed)
- `getHit()` 메서드 없음 → `distance < maxDistance`로 판별
- `applyRotDependentTorque()` deprecated → 사용하지 않음 (Create 동력 사용)
- 자기 배 감지 방지 → MIN_DISTANCE 필터 적용
- Quaternion→Yaw 변환 수학 검증 필요 → 인게임 테스트 시나리오 포함

## Work Objectives

### Core Objective
Clockwork Phys Bearing으로 Optical Sensor를 360° 회전시키며, 감지된 블록의 각도+거리를 극좌표→직교좌표로 변환하여 CC Monitor에 2D 레이더 맵을 그리고, 근접 타겟에 대해 레드스톤 경보를 출력하는 Lua 프로그램.

### Deliverables
- `radar/config.lua` — 설정 상수
- `radar/scanner.lua` — 센서 데이터 수집 (각도+거리 읽기)
- `radar/state.lua` — 타겟 상태 관리
- `radar/ui.lua` — 2D 모니터 렌더링
- `radar/alarm.lua` — 레드스톤 경보
- `radar/startup.lua` — 메인 루프

### Definition of Done (verifiable conditions)
- `luac -p radar/*.lua` — 모든 파일 구문 검증 통과
- 각 모듈이 `require()`로 독립 로드 가능
- Mock 데이터로 UI 렌더링 로직 검증 가능

### Must Have
- Quaternion → Yaw(0-360°) 변환
- Polar(angle, distance) → Cartesian(x, z) 변환
- 자기 배 블록 필터링 (MIN_DISTANCE)
- 2D 원형 레이더 UI (센터 + 타겟 점)
- 근접 경보 (설정 반경 이내 타겟 시 레드스톤 출력)
- 에러 핸들링 (페리페럴 미연결 시 재시도)

### Must NOT Have (guardrails)
- Command Computer 전용 API 사용 금지
- 3D 시각화 (범위 밖)
- IFF(아군/적군 식별), 속도 예측, 궤적 표시 (v2 기능)
- 무선 데이터 전송 (범위 밖)

## Verification Strategy
> ZERO HUMAN INTERVENTION — all verification is agent-executed.
- Test decision: tests-after + luac syntax check
- QA policy: Every task has agent-executed scenarios
- Evidence: .sisyphus/evidence/task-{N}-{slug}.{ext}

## Execution Strategy

### Parallel Execution Waves

Wave 1: [Foundation — 독립 모듈]
- Task 1: config.lua (설정 상수)
- Task 2: scanner.lua (센서 읽기 + 좌표 변환)
- Task 3: state.lua (타겟 상태 관리)

Wave 2: [UI + Alarm — state.lua 의존]
- Task 4: ui.lua (2D 모니터 렌더링)
- Task 5: alarm.lua (레드스톤 경보)

Wave 3: [통합]
- Task 6: startup.lua (메인 루프)

### Dependency Matrix
| Task | Depends On | Blocks |
|------|-----------|--------|
| 1. config | — | 2,3,4,5,6 |
| 2. scanner | 1 | 6 |
| 3. state | 1 | 4,5,6 |
| 4. ui | 1,3 | 6 |
| 5. alarm | 1,3 | 6 |
| 6. startup | 1,2,3,4,5 | — |

### Agent Dispatch Summary
| Wave | Tasks | Categories |
|------|-------|------------|
| 1 | 1,2,3 | quick, unspecified-high, quick |
| 2 | 4,5 | unspecified-high, quick |
| 3 | 6 | unspecified-high |

## TODOs

- [x] 1. config.lua — 설정 상수 모듈

  **What to do**:
  `radar/config.lua` 파일 생성. 아래 설정을 테이블로 정의하고 `return config`로 내보냄:
  - `SCAN_RANGE = 128` (최대 레이캐스트 거리)
  - `MIN_DISTANCE = 5` (자기 배 블록 무시 거리)
  - `ALARM_RADIUS = 50` (경보 반경)
  - `ALARM_SIDE = "top"` (레드스톤 출력 면)
  - `MONITOR_SCALE = 0.5` (모니터 텍스트 스케일)
  - `REFRESH_RATE = 0.05` (스캔 간격, 초)
  - `PERIPHERALS` 테이블: sensor, monitor 이름 (nil이면 자동 탐색)
  - `findPeripheral(type)` 헬퍼 함수: `peripheral.find(type)`의 래퍼

  **Must NOT do**: 하드코딩된 페리페럴 이름 사용 금지. 항상 `peripheral.find()` 패턴 사용.

  **Recommended Agent Profile**:
  - Category: `quick` — 단일 설정 파일
  - Skills: [] — 추가 스킬 불필요
  - Omitted: [`git-master`] — 커밋은 마지막 통합 시

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 2,3,4,5,6 | Blocked By: —

  **References**:
  - Pattern: `reactor/config.lua` — 동일 프로젝트의 설정 패턴 (테이블 + return + findPeripheral 헬퍼)

  **Acceptance Criteria**:
  - [ ] `luac -p radar/config.lua` 통과
  - [ ] `lua -e 'local c = dofile("radar/config.lua"); assert(c.SCAN_RANGE == 128); assert(type(c.findPeripheral) == "function")'` 통과

  **QA Scenarios**:
  ```
  Scenario: Config loads correctly
    Tool: Bash
    Steps: luac -p radar/config.lua
    Expected: Exit code 0
    Evidence: .sisyphus/evidence/task-1-config-syntax.txt

  Scenario: All required keys exist
    Tool: Bash
    Steps: lua -e 'local c = dofile("radar/config.lua"); for _,k in ipairs({"SCAN_RANGE","MIN_DISTANCE","ALARM_RADIUS","ALARM_SIDE","MONITOR_SCALE","REFRESH_RATE"}) do assert(c[k] ~= nil, k.." missing") end; print("OK")'
    Expected: prints "OK", exit 0
    Evidence: .sisyphus/evidence/task-1-config-keys.txt
  ```

  **Commit**: NO (통합 커밋에서 처리)

- [x] 2. scanner.lua — 센서 데이터 수집 모듈

  **What to do**:
  `radar/scanner.lua` 파일 생성. Optical Sensor + CC:VS ship API에서 데이터를 읽는 모듈.

  **핵심 함수**:

  ```lua
  local scanner = {}

  -- 초기화: 페리페럴 연결
  function scanner.init(config)
    -- peripheral.find()로 optical sensor 찾기
    -- ship API 존재 여부 확인 (Phys Bearing 위의 회전부 ship)
  end

  -- Quaternion → Yaw 변환 (0~360도)
  function scanner.getYaw()
    local q = ship.getQuaternion()  -- {x, y, z, w}
    local siny = 2 * (q.w * q.y - q.z * q.x)
    local cosy = 1 - 2 * (q.y * q.y + q.z * q.z)
    local yaw = math.deg(math.atan2(siny, cosy))
    if yaw < 0 then yaw = yaw + 360 end
    return yaw
  end

  -- 현재 센서 포인트 읽기
  function scanner.readPoint()
    local angle = scanner.getYaw()
    local distance = sensor.getDistance()
    local maxDist = config.SCAN_RANGE
    local hit = (distance < maxDist)
    local x, z = 0, 0
    if hit and distance > config.MIN_DISTANCE then
      x = distance * math.cos(math.rad(angle))
      z = distance * math.sin(math.rad(angle))
    end
    return { angle=angle, distance=distance, hit=hit, x=x, z=z }
  end
  ```

  **Must NOT do**:
  - `ship.applyWorldTorque()` 등 Command Computer 전용 API 사용 금지
  - `getHit()` 호출 금지 (존재하지 않음)

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — 수학 변환 + 페리페럴 API 통합
  - Skills: [] — 추가 스킬 불필요

  **Parallelization**: Can Parallel: YES (Wave 1, config와 동시) | Blocks: 6 | Blocked By: 1

  **References**:
  - API: CC:VS `ship.getQuaternion()` → `{x, y, z, w}` (https://github.com/TechTastic/CC-VS/blob/1.20.x/main/common/src/main/resources/data/computercraft/lua/rom/apis/ship.lua)
  - API: Optical Sensor `getDistance()` → float, `setMaxDistance(n)` → nil (https://github.com/SergeyFeduk/Create-Propulsion — OpticalSensorPeripheral.java)
  - Pattern: `reactor/reactor_monitor.lua:12-30` — 페리페럴 연결 + 재시도 패턴
  - Math: Quaternion→Yaw: `yaw = atan2(2*(w*y - z*x), 1 - 2*(y²+z²))`

  **Acceptance Criteria**:
  - [ ] `luac -p radar/scanner.lua` 통과
  - [ ] `getYaw()` 함수가 Quaternion {x=0, y=0, z=0, w=1} → 0도 반환
  - [ ] `readPoint()`가 `{angle, distance, hit, x, z}` 테이블 반환

  **QA Scenarios**:
  ```
  Scenario: Quaternion identity → yaw 0
    Tool: Bash
    Steps: lua -e 'package.path="radar/?.lua;"..package.path; -- mock ship API and test getYaw with identity quaternion'
    Expected: yaw ≈ 0
    Evidence: .sisyphus/evidence/task-2-quaternion.txt

  Scenario: Syntax validation
    Tool: Bash
    Steps: luac -p radar/scanner.lua
    Expected: Exit code 0
    Evidence: .sisyphus/evidence/task-2-syntax.txt
  ```

  **Commit**: NO

- [x] 3. state.lua — 레이더 상태 관리 모듈

  **What to do**:
  `radar/state.lua` 파일 생성. 스캔 결과를 저장하고 관리하는 모듈.

  **핵심 함수**:
  ```lua
  local state = {}
  local targets = {}     -- 현재 스캔 결과 {[angle_key] = {x, z, distance, angle, tick}}
  local sweepData = {}   -- 현재 sweep의 원시 포인트 배열

  function state.init() end
  function state.addPoint(point) end        -- scanner.readPoint() 결과 추가
  function state.getTargets() return targets end
  function state.getSweepData() return sweepData end
  function state.clearSweep() sweepData = {} end
  function state.getClosestDistance() end    -- 가장 가까운 타겟 거리 반환
  ```

  **Must NOT do**: UI/렌더링 로직 포함 금지. 데이터만 관리.

  **Recommended Agent Profile**:
  - Category: `quick` — 순수 데이터 구조
  - Skills: []

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 4,5,6 | Blocked By: 1

  **References**:
  - Pattern: `reactor/reactor_monitor.lua:52-89` — 데이터 수집 → 구조화 패턴

  **Acceptance Criteria**:
  - [ ] `luac -p radar/state.lua` 통과
  - [ ] addPoint 후 getTargets()에 데이터 존재

  **QA Scenarios**:
  ```
  Scenario: Add and retrieve targets
    Tool: Bash
    Steps: lua -e 'local s = dofile("radar/state.lua"); s.init(); s.addPoint({angle=45, distance=50, hit=true, x=35.3, z=35.3}); assert(#s.getSweepData() == 1); print("OK")'
    Expected: "OK", exit 0
    Evidence: .sisyphus/evidence/task-3-state.txt
  ```

  **Commit**: NO

- [x] 4. ui.lua — 2D 모니터 렌더링 모듈

  **What to do**:
  `radar/ui.lua` 파일 생성. CC Monitor에 2D 레이더 맵을 그리는 모듈.

  **핵심 기능**:
  - 원형 레이더 프레임 (십자선 + 동심원)
  - 중심 = 레이더 위치 (고정 `+` 표시)
  - 타겟 = 빨간 점 (`X` 표시)
  - 현재 스캔 라인 (초록 선) — 현재 센서 방향 표시
  - 상단에 정보 텍스트 (타겟 수, 가장 가까운 거리)

  **좌표 변환**:
  ```lua
  function ui.worldToScreen(wx, wz, radarRadius, monW, monH)
    local scale = math.min(monW, monH) / 2 / radarRadius
    local cx, cy = math.floor(monW/2), math.floor(monH/2)
    local sx = cx + math.floor(wx * scale)
    local sy = cy + math.floor(wz * scale)
    return sx, sy
  end
  ```

  **색상**: `colors.green` (프레임), `colors.red` (타겟), `colors.lime` (스캔라인), `colors.white` (텍스트)

  **Must NOT do**:
  - 3D 렌더링 시도 금지
  - Monitor가 없을 때 crash 금지 (headless 모드 지원)

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — 2D 좌표 변환 + CC 터미널 API
  - Skills: []

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 6 | Blocked By: 1,3

  **References**:
  - API: CC:Tweaked Monitor — `term.redirect()`, `term.setBackgroundColor()`, `term.setCursorPos()`, `term.write()`, `paintutils.drawLine()`
  - Pattern: `reactor/reactor_monitor.lua` — 기존 CC 프로그래밍 스타일

  **Acceptance Criteria**:
  - [ ] `luac -p radar/ui.lua` 통과
  - [ ] `worldToScreen(0,0, 128, 40, 20)` → 화면 중앙 좌표 (20, 10)

  **QA Scenarios**:
  ```
  Scenario: Coordinate conversion center
    Tool: Bash
    Steps: lua -e 'local ui = dofile("radar/ui.lua"); local x,y = ui.worldToScreen(0,0,128,40,20); assert(x==20 and y==10, x..","..y); print("OK")'
    Expected: "OK"
    Evidence: .sisyphus/evidence/task-4-coords.txt

  Scenario: Syntax check
    Tool: Bash
    Steps: luac -p radar/ui.lua
    Expected: Exit 0
    Evidence: .sisyphus/evidence/task-4-syntax.txt
  ```

  **Commit**: NO

- [x] 5. alarm.lua — 레드스톤 경보 모듈

  **What to do**:
  `radar/alarm.lua` 파일 생성. 타겟이 설정 반경 이내에 있으면 레드스톤 신호를 출력.

  **핵심 함수**:
  ```lua
  local alarm = {}

  function alarm.init(config) end

  -- 타겟 거리 확인 후 레드스톤 제어
  function alarm.check(closestDistance, alarmRadius)
    if closestDistance and closestDistance <= alarmRadius then
      redstone.setOutput(config.ALARM_SIDE, true)
      return true
    else
      redstone.setOutput(config.ALARM_SIDE, false)
      return false
    end
  end

  function alarm.reset()
    redstone.setOutput(config.ALARM_SIDE, false)
  end
  ```

  **Must NOT do**: 사운드/스피커 제어 (v2), 다중 알람 존 (v2)

  **Recommended Agent Profile**:
  - Category: `quick` — 단순 거리 비교 + 레드스톤 토글
  - Skills: []

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 6 | Blocked By: 1,3

  **References**:
  - API: CC:Tweaked `redstone.setOutput(side, bool)`
  - Pattern: `reactor/reactor_monitor.lua:79-87` — 임계값 기반 알림 패턴

  **Acceptance Criteria**:
  - [ ] `luac -p radar/alarm.lua` 통과
  - [ ] `check(30, 50)` → `true` (30 < 50이므로 알람)
  - [ ] `check(80, 50)` → `false` (80 > 50이므로 정상)

  **QA Scenarios**:
  ```
  Scenario: Alarm triggers within radius
    Tool: Bash
    Steps: lua -e 'local a = dofile("radar/alarm.lua"); -- mock redstone, test check(30, 50) returns true'
    Expected: returns true
    Evidence: .sisyphus/evidence/task-5-alarm.txt
  ```

  **Commit**: NO

- [x] 6. startup.lua — 메인 루프 통합

  **What to do**:
  `radar/startup.lua` 파일 생성. 모든 모듈을 통합하는 메인 루프.

  **핵심 로직**:
  ```lua
  local config = require("config")
  local scanner = require("scanner")
  local state = require("state")
  local ui = require("ui")
  local alarm = require("alarm")

  -- 1. 초기화 (페리페럴 연결 + 에러 핸들링)
  local function init()
    scanner.init(config)
    state.init()
    ui.init(config)
    alarm.init(config)
    -- sensor.setMaxDistance(config.SCAN_RANGE) 호출
  end

  -- 2. 메인 루프
  local function main()
    init()
    local lastAngle = 0
    while true do
      -- 스캔 포인트 읽기
      local point = scanner.readPoint()
      
      -- 히트 시 state에 추가
      if point.hit then
        state.addPoint(point)
      end
      
      -- 360도 회전 완료 감지 (각도가 0을 지나감)
      local currentAngle = point.angle
      if lastAngle > 270 and currentAngle < 90 then
        -- 한 바퀴 완료 → UI 갱신 + 알람 체크
        ui.refresh(state.getSweepData(), currentAngle, config)
        alarm.check(state.getClosestDistance(), config.ALARM_RADIUS)
        state.clearSweep()
      end
      lastAngle = currentAngle
      
      os.sleep(config.REFRESH_RATE)
    end
  end

  -- 3. 에러 핸들링 래퍼
  local ok, err = pcall(main)
  if not ok then
    print("Radar error: " .. tostring(err))
    alarm.reset()
  end
  ```

  **Must NOT do**:
  - 모듈 내부 로직 중복 금지 (모든 로직은 각 모듈에 위임)
  - `os.sleep(0)` 사용 금지 (서버 부하)

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — 모든 모듈 통합 + 360° sweep 감지 로직
  - Skills: []

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: — | Blocked By: 1,2,3,4,5

  **References**:
  - Pattern: `reactor/reactor_monitor.lua:143-167` — 메인 루프 + pcall 에러 핸들링 패턴
  - Pattern: `reactor/reactor_monitor.lua:178-183` — graceful shutdown 패턴

  **Acceptance Criteria**:
  - [ ] `luac -p radar/startup.lua` 통과
  - [ ] 모든 require() 경로가 정확

  **QA Scenarios**:
  ```
  Scenario: Syntax validation
    Tool: Bash
    Steps: luac -p radar/startup.lua
    Expected: Exit 0
    Evidence: .sisyphus/evidence/task-6-syntax.txt

  Scenario: Module imports resolve
    Tool: Bash
    Steps: lua -e 'package.path="radar/?.lua;"..package.path; local ok,err = pcall(require,"config"); assert(ok, tostring(err)); print("OK")'
    Expected: "OK"
    Evidence: .sisyphus/evidence/task-6-imports.txt
  ```

  **Commit**: YES | Message: `feat(radar): add VS ship radar system with optical sensor scanning` | Files: `radar/*.lua`

## Final Verification Wave (4 parallel agents, ALL must APPROVE)

- [x] F1. Plan Compliance Audit — oracle
- [x] F2. Code Quality Review — unspecified-high
- [x] F3. Real Manual QA — unspecified-high
- [x] F4. Scope Fidelity Check — deep

## Commit Strategy
- Single commit after all tasks complete: `feat(radar): add VS ship radar system with optical sensor scanning`
- Files: all `radar/*.lua`

## Success Criteria
1. 모든 Lua 파일이 `luac -p` 구문 검증 통과
2. 모듈 간 의존성이 `require()`로 깔끔하게 연결됨
3. Mock 데이터로 좌표 변환 수학이 정확함을 검증
4. 기존 프로젝트 코드 스타일 (config.lua 패턴, pcall 에러 핸들링) 준수
5. Command Computer 전용 API 미사용
