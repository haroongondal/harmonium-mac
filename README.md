# Harmonium for Mac

A harmonium you play by moving your MacBook's lid.

Recent MacBooks have an angle sensor in the hinge. This app reads it and treats the lid like a harmonium's bellows: opening and closing the lid pumps air, and the lid angle picks the note. Move the lid and it plays. Stop, and the sound fades as the air runs out.

You can also play it like a normal harmonium from the computer keyboard or with the mouse.

## Requirements

- macOS 14 or later
- Xcode or the Swift toolchain (Swift 5.10+)
- A MacBook with a lid angle sensor for lid control. Tested on a Mac17,2. On Macs without the sensor, the app still works and the air is simply always on.

## Build and run

```sh
./build-app.sh
open build/Harmonium.app
```

`build-app.sh` builds a release binary and wraps it in an ad-hoc signed `Harmonium.app` under `build/`.

To run the tests:

```sh
swift test
```

## Playing

### With the lid

The Bellows panel has three modes:

| Mode | What the lid does |
|------|-------------------|
| **Play with lid** (default) | The angle picks the note and the movement pumps the air. Every 6° is the next note of the major scale (Sa Re Ga ma Pa Dha Ni), starting at 20° open. The note being played lights up on the keyboard. |
| **Pump with lid** | Movement only pumps air. Play notes with the keys. |
| **Air always on** | The lid is ignored. Plays like an ordinary keyboard. |

Each note held uses up air, so if you stop pumping, a held chord fades out in a couple of seconds. The **Sensitivity** slider sets how much air each movement adds.

### With the keyboard

| Keys | Action |
|------|--------|
| `Z` row (`Z S X D C V G B H N J M , L . ; /`) | Notes from the lower Sa |
| `Q` row (`Q 2 W 3 E R 5 T 6 Y 7 U I 9 O 0 P [ = ]`) | Notes one octave up |
| `←` / `→` | Octave down / up |
| `↑` / `↓` | Change the key (Sa) |

Keys are matched by position, so the layout works the same on non-QWERTY keyboards.

## Controls

- **Reeds:** Bass (one octave down), Male, Male 2 and Female (one octave up), each with its own volume. Male 2 is tuned slightly apart from Male, which gives the beating "vibrato" sound of a real harmonium. **Beat (cents)** sets how far apart they are.
- **Sound:** volume, soft/hard tone, reverb and bellows attack.
- **Scale:** the key changer (Sa = C, C♯ …), octave, fine tuning in cents, and labels in sargam or Western note names.

## How it works

- `Sources/HarmoniumCore/Synth.swift`: the reed sound, synthesized from wavetables of reed-like harmonics. No recorded samples are used.
- `Sources/HarmoniumCore/Bellows.swift`: the air reservoir. Lid movement fills it, held notes drain it, and the volume follows how much air is left.
- `Sources/HarmoniumCore/LidMelody.swift`: maps the lid angle to scale notes, with a small margin so a lid resting on the line between two notes doesn't flicker.
- `Sources/Harmonium/LidSensor.swift`: reads the hinge sensor through IOKit HID (vendor `0x05AC`, product `0x8104`, usage page `0x20`, usage `0x8A`). It reads feature report 1, which holds the angle in whole degrees, about 60 times a second.

## Limitations

- The lid sensor is undocumented. A future macOS update could change or remove it, in which case the app falls back to air always on.
- Closing the lid too far may put the Mac to sleep.
- Lid melody mode plays the major scale only.
- Not yet built: tanpura drone, chord and hold modes, recording, MIDI input and the coupler.
