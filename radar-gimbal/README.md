# Radar Emission Tracker: 6-Detector Gimbal Pointer

Points a radar's built-in gimbal toward a radar emitter, using six Radar
Detectors (on/off) that face front, back, left, right, top and bottom.
Hull blocks shield each detector from the others.

## Wiring

The Lua Script node has one composite input and one composite output.

| MC input (On/Off) | Composite Write (On/Off) channel | Script reads     |
|-------------------|----------------------------------|------------------|
| 1 Front_Detector  | 1                                | `input.getBool(1)` |
| 2 Back_Detector   | 2                                | `input.getBool(2)` |
| 3 Left_Detector   | 3                                | `input.getBool(3)` |
| 4 Right_Detector  | 4                                | `input.getBool(4)` |
| 5 Top_Detector    | 5                                | `input.getBool(5)` |
| 6 Bottom_Detector | 6                                | `input.getBool(6)` |

Wire the script's composite output straight to MC Output 1
(`Radar_Gimbal_Control`, Composite). Then wire that output to the Radar
block's composite input.

- Channel 1: azimuth, -1..1 = -180°..+180° (0 = front, + = right)
- Channel 2: elevation, -1..1 = -90°..+90° (0 = level, + = up)

### Countermeasure output

The script also sets composite **boolean** channel 1. It turns on as soon
as any detector is on, and stays on for `HOLD` ticks after the last one
goes off. A sweeping radar only lights a detector briefly, so the hold
stops the output from flickering. Set `HOLD=0` to follow the detectors
exactly.

To get it out of the MC:

1. Add an On/Off Output node (e.g. Output 2, `Countermeasure_Trigger`).
2. Add a `Composite Read (On/Off)` node set to channel 1.
3. Wire the script's composite output into that Read node, and wire the
   Read node to Output 2.

The script's composite output also still goes straight to Output 1.
Numbers and booleans travel on separate channels, so the radar's number
channels 1 and 2 are not affected.

## How it works

Each detector that is on adds a unit vector: front/back on x, right/left
on y, top/bottom on z. The script then:

- Uses `atan(y, x)` for the target azimuth and `atan(z, √(x²+y²))` for the
  target elevation.
  - Front only → 0. Right only → +90°. Left only → −90°. Back only → 180°.
  - Front and right together → 45°. Top only → +90° elevation.
- Moves toward the target by `SMOOTH` × error each tick, capped at
  `AZ_RATE` / `EL_RATE`. Azimuth takes the shortest way round.
- Holds the last angle when no detector is on, or when opposite detectors
  cancel. Azimuth also holds when only top or bottom is on.

## Tuning

- `SMOOTH`: raise it for a faster response. Lower it for a smoother one.
- `AZ_RATE` / `EL_RATE`: the maximum movement per tick. At 60 ticks/s,
  0.02 is 216°/s of azimuth.
- If your radar expects different units (radians, turns, or a narrower
  range), rescale the two `output.setNumber` values.
- If an axis turns the wrong way, negate that value.
