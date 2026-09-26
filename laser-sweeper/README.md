# Laser Wavelength Sweeper — Countermeasure MC

A microcontroller that continuously drives ten laser emitters through a wide
band of integer wavelengths so that, sooner or later, one of them lands on the
channel an enemy **Laser Point Sensor** is listening on. The sweep has no
inputs. Turning the lasers on and off is left to your own key, wired straight
to the emitters.

This is pure game logic. The script only rewrites ten number outputs, once
per tick at 60 Hz.

---

## 0. Read this first: what is verified, and what you must check

| Claim | Status |
|---|---|
| **Laser Beacon**, **Laser Point Sensor** and **Laser Distance Sensor** are vanilla blocks. The beacon and the distance-sensor beam create laser points. A Laser Point Sensor only sees points on its own wavelength and reports the one nearest the centre of its view. | Verified. Added in v0.7.6‑7, "The Laser Point Sensor Update". |
| The Lua block reads and writes one **composite** bus (`input.getBool/getNumber`, `output.setBool/setNumber` by channel). `property.getNumber` reads property nodes by label. | Verified, standard Stormworks Lua API. |
| The wavelength on a Laser Beacon or Laser Distance Sensor can be changed **by a logic number input** while the vehicle is running, not only as an editor setting. | **Not verified. Check it before you build.** In the editor, hover each connector on the block. If there's no number input for wavelength or frequency, the value is fixed at spawn and **no sweep of any kind is possible.** See §5 for the fallback. |
| The real wavelength range, and whether values are integers. | **Not verified.** That's why the range is set by `Min WL` and `Max WL` properties instead of being hard-coded. Set them to the limits the block's own slider or tooltip shows. |

### The tactical catch

A laser point on **your own hull** sits right next to the point the enemy
designator is painting on you. The missile's sensor tracks the most central
matching point, so a hull emitter on the right wavelength will not pull the
missile off you. At best it does nothing. If the enemy's paint was sloppy, it
can even help them. To work as a decoy, the matching point has to show up
**somewhere other than the aircraft**:

* **Laser Distance Sensors pointed away from the airframe.** Each beam paints
  a point where it hits terrain or sea, which is well away from you. This is
  the most useful layout for a sweeper.
* **Laser Beacons on a jettisoned decoy pod.** A detachable sub-vehicle with
  its own copy of this MC, released with a detacher.
* Beacons on the hull are useful only for **testing** the sweep against your
  own Laser Point Sensor.

**Duty cycle.** With a band `S` wide and 10 emitters, each wavelength is lit
for `Dwell` ticks once every `ceil(S/10)*Dwell` ticks. With the defaults
(0–99), that is 1 tick in every 10, or about 6 blips per second on the
enemy's channel. Whether blips that short disturb a missile depends on how
its builder filters the sensor output. A missile that averages or latches
over several ticks will barely notice. Raising `Dwell` makes each blip
longer but the full sweep slower.

---

## 1. The Lua code

[`laser_sweeper.lua`](./laser_sweeper.lua) is about 1.8 KB, well under the
4096-character limit. The work per tick is one loop of 10 `setNumber` calls. It reads no inputs and
simply sweeps on every tick. The lasers only emit when your separate enable
key powers them.

How it sweeps: the band `[Min WL, Max WL]` is split into 10 equal **lanes**
of width `stride = ceil(span/10)`. Emitter *i* starts at the bottom of lane
*i* and steps +1 every `Dwell` ticks, wrapping at the top of its lane. All 10
lanes move together, so **every integer in the band gets covered once every
`stride` steps**, with no two emitters overlapping. A band of 100 is fully
covered in 10 ticks, which is 1/6 s. Coverage was checked for spans that are
multiples of 10, spans that aren't, and spans smaller than 10.

---

## 2. Microcontroller node map

### Physical connectors (the outer I/O of the MC)

| Node type | Label | Direction |
|---|---|---|
| `Number Output` ×10 | `WL 1` … `WL 10` | out |

### Internal nodes

| Node | Setting | Wiring |
|---|---|---|
| `Lua Script` | paste `laser_sweeper.lua` | composite input left unconnected; composite out → the reads below |
| `Composite Read (Number)` ×10 | Channels **1…10** | Lua composite out → each read → `WL 1` … `WL 10` |
| `Property Number` ×3 (optional) | labels exactly `Min WL`, `Max WL`, `Dwell` | Not wired. The script reads them by label. If one is missing, its default is used. |

The Lua block has **one composite input and one composite output**.
`output.setNumber(3, …)` means composite number channel 3, which is why the
Composite Read nodes are needed. The composite input isn't used.

---

## 3. Step-by-step setup

1. **Check the wavelength input.** Place one Laser Distance Sensor and one
   Laser Beacon on a test vehicle and hover their connectors. Write down
   which connector sets the wavelength, whether it takes a number, and the
   range the block allows. If it's editor-only, stop and go to §5.
2. **Place the microcontroller.** Logic category → Microcontroller. Any
   size with 10 free connectors will do.
3. **Build the logic** following §2: 10 number outputs, the Lua block,
   10 Composite Read (Number) on ch 1–10, and optionally the 3 property
   nodes. Set `Min WL` and `Max WL` to
   the range you found in step 1.
4. **Mount the emitters.** Laser Distance Sensors are the preferred choice
   (see §0):
   * Spread 10 of them so their beams point **away** from the airframe:
     some down and aft, some down and to each side, never along your own
     flight path. The painted points should land well clear of you.
   * Keep the beams from hitting your own hull. A point painted on
     yourself is no use as a decoy.
   * If you use a decoy pod instead, put the beacons and a copy of this MC
     on the pod, and route your enable key across the detacher before
     separation.
5. **Wire the vehicle.**
   * `WL n` → wavelength number input of emitter *n*, for n = 1…10.
   * Your existing enable key → the on/off or power input of **all 10**
     emitters, so they're only lit while you're jamming. The MC doesn't
     touch this.
   * Power the emitters and the MC from the electrical network as usual.
6. **Test in the workbench.** Put a Laser Point Sensor on a *second* test
   vehicle set to some wavelength inside your band, for example 37. Turn
   on your laser key and watch the sensor's detection output. It should
   pulse, one tick every `stride` ticks (every 10 with the defaults). Set
   `Dwell` to 30 to slow the sweep down enough to see it by eye.
7. **Tune.** Narrow `Min WL` and `Max WL` to the wavelengths enemies
   actually use: a narrow band means a shorter cycle and more hits per
   second. Raise `Dwell` if a one-tick blip is too short to register.

---

## 4. Tuning reference

| Property | Default | Effect |
|---|---|---|
| `Min WL` / `Max WL` | 0 / 99 | The band to sweep. A narrower band means each wavelength is revisited more often. |
| `Dwell` | 1 | Ticks each value is held. Blips get longer, the full cycle gets slower (`stride × Dwell` ticks). |

---

## 5. If the wavelength is editor-only

If you can't set the wavelength from logic, you can't sweep it at runtime.
The nearest workable design is a **static spread**: give each emitter a
different fixed wavelength in the editor, covering the channels you most
expect enemies to use, and switch them all with your enable key. This MC
isn't needed in that case.
