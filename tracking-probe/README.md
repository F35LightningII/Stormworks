# Autonomous Tracking Probe — Dual-Source Guidance

Microcontroller logic for a probe that pursues a parent-craft radio telemetry
fix (State 1), hands off on signal loss (State 2), and homes on its own
directional sensor for terminal guidance (State 3).

This README is split in two halves: **§1–2 teach the Stormworks
microcontroller mechanics from zero** (skip if you've built MCs before),
and **§3–5 are the reference material for this specific probe** (wiring
tables, the script, tuning).

## 1. How a Stormworks Microcontroller Actually Works

Three concepts, in the order they matter:

1. **The MC block's physical connectors.** A microcontroller (MC) is a
   component you place in the vehicle editor like any other block. It has
   no connectors until you add them — each connector (a small numbered
   socket you'll later run a wire into, in the vehicle editor) is created
   by placing an `Input` or `Output` node of the matching type (`Number`,
   `On/Off`, `Composite`, `Video`, `Audio`) on the MC's internal logic
   canvas.
2. **Composite Read / Composite Write nodes.** A composite connector
   carries a bundle of up to 32 number channels + 32 boolean channels on
   one wire. The `Composite Input`/`Composite Output` node you place in
   step 1 is just the pass-through socket — to actually read or write one
   channel inside that bundle, you place a **separate** `Composite Read
   (Number)` / `Composite Read (On/Off)` node (or `Composite Write …` on
   the output side) **per channel**, and set that node's own `Channel`
   property to the index you want. There is no "unpack everything at
   once" node.
3. **The Lua Script node.** Your actual Lua code lives on one special node
   on the canvas (add it like any other node, then double-click it to open
   the code editor). That node has its **own** pin list — you set how many
   Number Inputs, Boolean Inputs, Number Outputs, and Boolean Outputs it
   has in its properties, independent of the MC's outer physical
   connectors. Inside the code, `input.getNumber(i)` / `input.getBool(i)`
   read pin `i` **of this node**, in the order you added those pins — not
   the physical connector's index, not the composite channel's index. You
   connect wires from your canvas (physical Input nodes, or Composite Read
   node outputs) into this node's pins to make the numbers line up with
   what the script expects.

So a single value, e.g. Target X, actually crosses three hops before your
Lua code sees it: **physical Composite Input connector → Composite Read
(Number), channel set to whatever the transmitter used → Script node's
Number-In pin 1 → `input.getNumber(1)`**.

## 2. Assemble the Microcontroller From Scratch

### A. Place the block
1. Open the vehicle editor on the probe body (Workbench → Vehicle Editor,
   or edit an existing vehicle).
2. In the parts palette, go to the **Logic** category and select
   **Microcontroller**. Place one block anywhere convenient on the probe
   — its position doesn't affect behavior, only where its physical
   connectors will stick out for wiring later.

### B. Open the logic editor
3. With the microcontroller selected, use its right-click/context menu
   option to **Edit Microcontroller** (or the equivalent "edit logic"
   action shown for that block). This opens a separate node-graph canvas
   — you're no longer looking at the 3D vehicle, you're inside the MC's
   internal logic.

### C. Build the physical interface (the outer connectors)
4. Right-click empty canvas space to bring up the node search/add menu.
   Add the following **Input** nodes (these become sockets on the MC
   block once you exit):
   - 3× `Composite Input` — one each for the Radio Receiver, the Onboard
     Directional Sensor, and the Physics Sensor. Rename them (there's a
     label field on each node) to `Radio`, `Sensor`, `Physics` so you
     don't mix them up.
   - 1× `On/Off Input` — for the Launch Trigger (this one is a plain
     boolean wire in the 3D editor, not part of a composite bundle).
5. Add these **Output** nodes:
   - 2× `On/Off Output` — label them `Sensor Power` and `Thruster`.
   - 2× `Number Output` — label them `Pitch Fins` and `Yaw Fins`.

### D. Unpack the composite buses
6. Off the `Radio` Composite Input node, add and wire in:
   - 3× `Composite Read (Number)`, Channel set to **1, 2, 3** → Target X,
     Y, Z.
   - 1× `Composite Read (On/Off)`, Channel **1** → Data Valid.
   (These channel numbers must match whatever the parent craft's
   transmitter packs them as — see §2‑I.)
7. Off the `Sensor` Composite Input node, add and wire in a
   `Composite Read (On/Off)` for the found/lock flag and three
   `Composite Read (Number)` nodes for distance, azimuth, and elevation.
   **The exact channel numbers here are fixed by whichever sensor
   component you're using, not by you** — see the caveat in §3.
8. Off the `Physics` Composite Input node, add six
   `Composite Read (Number)` nodes set to channels **1–6** (Map X, Map Y,
   Altitude, Roll, Pitch, Yaw — this layout is fixed by the game's Physics
   Sensor component). Skip channels 7–14 (velocities/compass) — unused
   here.

### E. Add the Lua Script node
9. Add a `Script` (Lua) node to the canvas. Open its properties and set:
   **Number Inputs: 12, Boolean Inputs: 3, Number Outputs: 2, Boolean
   Outputs: 2.** (Naming the pins is optional but strongly recommended —
   it doesn't change the index, just makes the wiring readable.)

### F. Wire the canvas
10. Connect every Composite Read node's output, and the plain `On/Off
    Input` (Launch Trigger), into the Script node's input pins in **this
    exact order** — the Lua script indexes them positionally:

    | Script pin | Source |
    |---|---|
    | Number In 1–3 | Radio: Target X, Y, Z |
    | Number In 4–6 | Sensor: Distance, Azimuth, Elevation |
    | Number In 7–9 | Physics: Map X, Altitude, Map Y *(see note below)* |
    | Number In 10, 12 | Physics: Pitch, Yaw |
    | Number In 11 | Physics: Roll |
    | Boolean In 1 | Radio: Data Valid |
    | Boolean In 2 | Sensor: Found/Lock flag |
    | Boolean In 3 | Launch Trigger (plain On/Off Input) |

    > **Note on Number In 7–9:** the script computes `dx = tx-mx`,
    > `dy = ty-my`, `dz = tz-mz` — it only needs the probe's own position
    > in the *same* axis order the target coordinates use. Wire Physics
    > channel 1 (Map X) → pin 7, channel 3 (Altitude) → pin 8, channel 2
    > (Map Y) → pin 9, so pins 7/8/9 line up with X/Y/Z the same way the
    > telemetry's Target X/Y/Z do. As long as both ends are consistent,
    > the relative-position math is correct regardless of what Stormworks
    > internally calls each axis.

11. Connect the Script node's output pins to the physical Output nodes
    from step 5, in order: Number Out 1 → `Pitch Fins`, Number Out 2 →
    `Yaw Fins`, Boolean Out 1 → `Sensor Power`, Boolean Out 2 →
    `Thruster`.

### G. Paste the code
12. Double-click the Script node to open its code editor and paste the
    full contents of [`tracking_probe.lua`](./tracking_probe.lua) (§4).
    Close the editor — the MC compiles automatically; if a pin count
    doesn't match what the code expects you'll get a compile error naming
    the mismatched index, which usually means step 9's counts are off.
13. Exit the logic editor (back arrow / Escape) to return to the 3D
    vehicle editor. The MC block now shows all 7 sockets you built:
    3 composite in, 1 bool in, 2 number out, 2 bool out.

### H. Wire the physical connectors in the vehicle
14. Using the vehicle editor's connection tool (hover a component's
    connector node and drag to another — check Controls settings for the
    exact bind if the connector nodes aren't visible by default), wire:
    - Radio Receiver's composite output → MC's `Radio` composite input.
    - Onboard Directional Sensor's composite output → MC's `Sensor`
      composite input.
    - Physics Sensor's composite output → MC's `Physics` composite input.
    - Whatever triggers separation/activation (a button, a physics
      sensor, a timer, another MC) → MC's Launch Trigger on/off input.
    - MC's `Pitch Fins` / `Yaw Fins` number outputs → the pitch/yaw
      control surface components' number inputs.
    - MC's `Sensor Power` bool output → the directional sensor's power/
      enable input.
    - MC's `Thruster` bool output → the propulsion component's ignition
      input.

### I. Set up the parent craft's transmitter
15. On the **parent craft**, the values feeding its Radio Transmitter must
    be packed with a `Composite Write (Number)` set to channel 1/2/3 for
    Target X/Y/Z, and a `Composite Write (On/Off)` on channel 1 for Data
    Valid — matching step 6 exactly. Where the parent gets Target X/Y/Z
    from (its own tracking radar, a waypoint, etc.) is outside this
    probe's scope, but the channel numbers on both ends must agree or the
    probe reads garbage.

### J. Test
16. In test mode, trigger Launch and confirm: thruster fires, `Sensor
    Power` output stays low while Data Valid is true, pitch/yaw outputs
    move as you reposition the target, and toggling Data Valid off
    permanently flips `Sensor Power` on and keeps it on even if you flip
    Data Valid back — that's the sticky hand-off from §5 working.

## 3. Wiring Reference (quick lookup)

### Inputs — Composite Read nodes needed

| Bus | Composite Read node | Channel | → Script pin |
|---|---|---|---|
| Radio Receiver | Composite Read (Number) | 1 | Number In 1 (Target X) |
| | Composite Read (Number) | 2 | Number In 2 (Target Y) |
| | Composite Read (Number) | 3 | Number In 3 (Target Z) |
| | Composite Read (On/Off) | 1 | Boolean In 1 (Data Valid) |
| Onboard Directional Sensor | Composite Read (On/Off) | *component-specific* | Boolean In 2 (Found) |
| | Composite Read (Number) | *component-specific* | Number In 4 (Distance, reserved) |
| | Composite Read (Number) | *component-specific* | Number In 5 (Azimuth) |
| | Composite Read (Number) | *component-specific* | Number In 6 (Elevation) |
| Physics Sensor | Composite Read (Number) | 1 (Map X) | Number In 7 |
| | Composite Read (Number) | 3 (Altitude) | Number In 8 |
| | Composite Read (Number) | 2 (Map Y) | Number In 9 |
| | Composite Read (Number) | 4 (Roll) | Number In 11 |
| | Composite Read (Number) | 5 (Pitch) | Number In 10 |
| | Composite Read (Number) | 6 (Yaw) | Number In 12 |
| Launch Trigger | *(plain On/Off Input, no composite)* | — | Boolean In 3 |

**⚠️ Sensor channel caveat:** the Physics Sensor's channel layout above
(1=Map X, 2=Map Y, 3=Altitude, 4=Roll, 5=Pitch, 6=Yaw) is fixed by the
game and confirmed. The **Onboard Directional Sensor's** channels depend
on which exact component you're using: a single-target Distance/Seeker
sensor typically exposes Bool ch.1 = Found, Number ch.1 = Distance, ch.2 =
Azimuth, ch.3 = Elevation (what's assumed in `tracking_probe.lua`), but
the multi-contact **Radar** component instead groups 4 channels per
contact (distance, azimuth, elevation, time-since-detected — contact 1 =
channels 1–4, contact 2 = channels 5–8, etc.). Before wiring, add one
`Composite Read (Number)` set to channel 1, watch its live value in the
editor while moving the target, and confirm it's actually reporting
distance before wiring the rest — don't assume the numbers above without
checking your specific sensor block.

### Outputs — plain, no Composite Write needed

| Script pin | Physical Output node | Wire to |
|---|---|---|
| Number Out 1 | `Pitch Fins` | Pitch control surface(s), -1..1 |
| Number Out 2 | `Yaw Fins` | Yaw control surface(s), -1..1 |
| Boolean Out 1 | `Sensor Power` | Directional sensor power/enable |
| Boolean Out 2 | `Thruster` | Main propulsion ignition |

These four are plain `Output` nodes wired straight to their actuators —
bundling them into a `Composite Write` is only useful if they need to
cross a single physical connector (e.g. a detach hook or a hinge); see
Extensions.

**Angle units:** Euler pitch/yaw and sensor azimuth/elevation are read as
Stormworks' native normalized "turns" (roughly -0.5..0.5 for relative
offsets, 0..1 for absolute heading), which is what the Physics Sensor and
Directional Sensor composites natively output — so no radian conversion is
needed. If your sensor setup instead outputs radians, divide by `2*math.pi`
before use.

## 4. Complete Lua Script

See [`tracking_probe.lua`](./tracking_probe.lua) (2 KB, well under the 4096
character limit). Paste it into the Script node as described in §2‑G.

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

## 5. Tuning Guide

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
- **Bundling outputs onto one composite wire:** if the 4 outputs need to
  cross a detach connector or hinge, add a `Composite Write (Number)` ×2
  and `Composite Write (On/Off)` ×2 after the Script node instead of wiring
  straight to physical Output nodes, feed the bundle through one
  `Composite Output` connector, and unpack it with a matching set of
  `Composite Read` nodes on the other side of the joint.
