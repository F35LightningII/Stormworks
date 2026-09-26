# Laser Scatter Sweep

Lua for a microcontroller with one composite output. Every tick (60 Hz) it
sends a new X/Y tilt pair so the beam jumps between opposite quadrants.

| Channel | Type   | Meaning               | Range      |
|---------|--------|-----------------------|------------|
| 1       | Number | X tilt / yaw          | -1.0 .. 1.0 |
| 2       | Number | Y tilt / pitch        | -1.0 .. 1.0 |

## Pattern
- Quadrants go in the order `++, --, +-, -+`. Every tick flips at least one
  axis, and every second tick flips both, which is the biggest jump possible.
- Ticks 0–3 of each 8-tick block hit the four corners exactly (±1, ±1).
- Ticks 4–7 put points inside the quadrants using golden-ratio sequences. The
  magnitude is 0.25–1.0, so over time the whole square fills in without the
  pattern repeating.

## Microcontroller
- Size 1x1 is enough.
- Nodes: **exactly one**, `Composite Output` (name it e.g. `Beam Tilt`).
  No inputs.
- Logic: one `Lua Script` block. Wire its composite output pin to the
  `Composite Output` node. Nothing goes into its input pin.

## Verification caveat, read before building
I couldn't confirm that the vanilla **Laser Distance Sensor** has a composite
tilt/steering input. As far as I know, its node list is just an on/off input
and a distance number output. It measures straight along its facing
direction, and the community builds LIDAR scanners with robotic pivots
because of that. Stormworks also doesn't let you wire a composite output into
a number or on/off node.

Check the sensor's node list in the editor (hover the block → logic nodes):
- **If there's a composite input** (e.g. "Control"/"Pivot"): wire the MC's
  `Beam Tilt` output straight to it. That's all. If the sensor has an enable
  on/off input too, it still needs a separate source, such as a constant-on
  wire or a pushbutton, which isn't part of this MC.
- **If there isn't one**, no microcontroller can steer this sensor's beam
  internally. The script will still run and show correct values in a
  Composite Read / debug display, but it won't move the laser.
