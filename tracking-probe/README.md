# Autonomous Tracking Probe — Dual-Source Guidance

Microcontroller logic for a probe that pursues a parent-craft radio telemetry
fix (State 1), hands off on signal loss (State 2), and homes on its own
directional sensor for terminal guidance (State 3).

## 1. Microcontroller Wiring Schematic

Composite buses carry multiple channels on one wire. In the Microcontroller
Editor, drop a **Composite Read** node for each bus, then wire its individual
channel pins to **Number In** / **Boolean In** nodes at the indices below
(set the index in each Input node's properties).

### Inputs

| Source | Channel | Type | MC Input Index |
|---|---|---|---|
| Composite In 1 — Radio Receiver | Target X | Number | Number In **1** |
| | Target Y | Number | Number In **2** |
| | Target Z | Number | Number In **3** |
| | Data Valid | Boolean | Bool In **1** |
| Composite In 2 — Onboard Directional Sensor | Found Flag | Boolean | Bool In **2** |
| | Distance | Number | Number In **4** *(reserved — see Extensions)* |
| | Azimuth | Number | Number In **5** |
| | Elevation | Number | Number In **6** |
| Composite In 3 — Physics Sensor | GPS X | Number | Number In **7** |
| | GPS Y | Number | Number In **8** |
| | GPS Z | Number | Number In **9** |
| | Euler Pitch | Number | Number In **10** |
| | Euler Roll | Number | Number In **11** *(unused — see Extensions)* |
| | Euler Yaw | Number | Number In **12** |
| Launch Trigger (direct on/off wire, not composite) | — | Boolean | Bool In **3** |

### Outputs

| Signal | Type | MC Output Index | Wire to |
|---|---|---|---|
| Onboard Sensor Power | Boolean | Bool Out **1** | Directional sensor power/enable |
| Thruster Ignition | Boolean | Bool Out **2** | Main propulsion trigger |
| Pitch Control Surface | Number | Number Out **1** | Pitch fin actuator(s), -1..1 |
| Yaw Control Surface | Number | Number Out **2** | Yaw fin actuator(s), -1..1 |

**Angle units:** Euler pitch/yaw and sensor azimuth/elevation are read as
Stormworks' native normalized "turns" (roughly -0.5..0.5 for relative
offsets, 0..1 for absolute heading), which is what the Physics Sensor and
Directional Sensor composites natively output — so no radian conversion is
needed. If your sensor setup instead outputs radians, divide by `2*math.pi`
before use.

## 2. Complete Lua Script

See [`tracking_probe.lua`](./tracking_probe.lua) (2 KB, well under the 4096
character limit). Paste it directly into the Microcontroller's Lua editor.

Logic summary:
- **Not launched:** all outputs zeroed/off, state reset so a future launch
  starts clean.
- **Launched + `Data Valid == true` + not locked (State 1):** computes
  bearing/elevation from the probe's GPS position to the telemetry target,
  subtracts the probe's own yaw/pitch to get a steering error, and adds a
  proportional-navigation lead term driven by the line-of-sight rotation
  rate (`N`) — this is the standard Stormworks-scripting simplification of
  PN (pursuit + LOS-rate lead) rather than full augmented PN, which keeps it
  cheap enough to run every tick.
- **`Data Valid == false` at any point (State 2):** sets a `locked` flag to
  `true`. This flag is **sticky** — it is never cleared while the probe
  remains launched, even if telemetry comes back, so a flickering radio link
  can't bounce the probe between states. It only resets on the next launch
  edge (`launched == false`).
- **`locked == true` (State 3):** powers the onboard sensor (Bool Out 1),
  and once it reports `Found`, steers directly on its azimuth/elevation
  (already a normalized angular offset — no trig needed).
- Thruster ignition holds `true` for the entire time the probe is launched.

## 3. Tuning Guide

| Constant | Location | Effect |
|---|---|---|
| `N` (default `4`) | top of script | Proportional-navigation gain on the line-of-sight rate term during State 1. Higher = more aggressive intercept lead against a maneuvering target, but too high causes overshoot/oscillation as telemetry updates are discrete. Start at 3, raise toward 5 only if the probe visibly lags a turning target. |
| `G` (default `1.5`) | top of script | Overall fin sensitivity — multiplies both the heading-error term (State 1) and the raw sensor azimuth/elevation (State 3) before clamping to ±1. Raise if the probe responds sluggishly to angle error; lower if it oscillates or the fins saturate (pin to ±1) too early. |
| Clamp range `(-1, 1)` in `clamp(...)` calls | output stage | Matches control-surface input range; leave as-is unless your fin actuators use a different convention. |

Practical tuning order:
1. Set `N = 0` temporarily (pure pursuit, no PN lead) and tune `G` alone
   until State 1 tracking is stable and responsive with a stationary or
   slow target.
2. Reintroduce `N` (start at 3) against a moving/maneuvering target and
   raise until intercept improves without inducing oscillation.
3. Tune State 3 behavior by adjusting `G` against a live sensor lock —
   the same `G` drives both states, so revisit step 1 if terminal homing
   ends up too twitchy relative to mid-course tracking. If they need to
   diverge significantly, split `G` into `G1` (State 1) and `G3` (State 3).

### Extensions (not implemented, wiring already reserved)
- **Proximity fuze:** onboard sensor `Distance` is already wired to Number
  In 4; add a threshold check (e.g. detonate/trigger below N meters) without
  touching the guidance logic.
- **Roll stabilization:** Euler Roll is wired to Number In 11 for airframes
  that need bank-to-turn correction; the current script assumes a
  cruciform/X-fin layout where roll can be ignored.
