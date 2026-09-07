# Antenna placement and keep-out

The ESP32-S3 Super Mini carries its Wi-Fi antenna on the PCB itself, at one
end of the board. Anything conductive close to that end degrades the radio.
This is not a marginal effect: on 2026-09-07 it cost most of a day of
debugging and very nearly cost a working board, because every symptom
pointed at a hardware fault.

Read this before seating the board in a breadboard, before laying out a PCB,
and before closing it inside a chassis.

## The rule

**The antenna end of the board must have clear air around it.** No metal, no
copper, no wiring bundle, no screw, no bracket.

On a breadboard that means the antenna end **overhangs the end of the
breadboard**. Never seat the board centrally, where the antenna sits over the
metal spring strips.

## What it looked like when it was wrong

The board was seated normally in a breadboard, antenna over the contact
strips. Measurements, all from the same board on the same desk:

| Condition | Test | Result |
|---|---|---|
| Seated in breadboard | Scan for nearby networks | Heard 14 networks — receive looked fine |
| Seated in breadboard | Same router, two positions | −56 dBm in one, −90 dBm in another |
| Seated in breadboard | Start an access point | Reported success at full transmit power |
| Seated in breadboard | Look for that access point | Invisible to an iPhone *and* a MacBook 30 cm away |
| Seated in breadboard | Join the network by typing its name | "cannot be found" |
| Seated in breadboard | Join a phone hotspot heard at −29 dBm | Failed after 30 s |
| **Off the breadboard** | **Join that same hotspot** | **Connected in about 1 s, −23 dBm** |

The last two rows are the controlled comparison: identical firmware,
identical target, signal heard at −29 dBm both times. The only variable was
whether the board was sitting in the breadboard.

A full chip erase, which clears the stored radio calibration data, changed
nothing. Do not spend time on that — it is not the cause.

## Why transmit appears to fail first

Nearby metal detunes the antenna and absorbs energy. The loss applies to both
directions, but you notice it on transmit first.

Receiving a strong nearby access point still works, because there is plenty
of signal to spare. Joining a network is a two-way exchange — the board must
transmit and be *heard back* — and that return path has no margin left. So
the board appears to "hear but not speak", which looks exactly like a blown
transmitter.

If you ever see a radio that receives well but cannot associate or be seen,
suspect its surroundings before suspecting the board.

## PCB layout

This matters more on the real board than on the breadboard, because the fault
becomes permanent and is far harder to find once everything is soldered.

- **No copper under or beside the antenna, on any layer.** No traces, no
  ground pour, no fill, no stitching vias.
- **Let the antenna overhang the board outline** where the mechanics allow,
  or leave a clear keep-out region around it.
- **Keep the switching converter away.** It is a deliberate source of
  broadband noise sitting next to a sensitive receiver.
- **Do not route servo or battery wiring across the antenna.** Those carry
  large, fast current swings.

The Super Mini uses an antenna printed on the board rather than a certified
module, so there is no manufacturer keep-out dimension to cite. Treat the
qualitative rules above as the specification and confirm the result by
measurement — see below.

## Chassis and 3D-printed parts

- Plain PLA, PETG and ABS are transparent to 2.4 GHz. They are fine.
- **Carbon-fibre filament is conductive.** Do not use it near the antenna.
- Keep metal screws, bearings, brackets and cable bundles away from that end.
- Servo bodies contain a motor and gearing — treat them as metal.

## Verify, do not assume

The mechanical build can detune the radio just as the breadboard did. Run the
acceptance test in [../../firmware/test/README.md](../../firmware/test/README.md)
twice:

1. On the bare board, before wiring anything.
2. Again in the final assembly, with the chassis closed.

A pass in both is the only evidence that the finished robot has a working
radio. It takes two minutes and it is the check that would have saved a day.

## Related

- [README.md](README.md) — assembly order and pre-power checklist
- [pin-map.md](pin-map.md) — what every GPIO does
- [power.md](power.md) — rail design and the converter that must stay clear
