# Overtone

A native iPhone and iPad instrument that connects piano keys to sound, frequency, light, and touch. Designed for someone starting with no music theory.

Open `Overtone.xcodeproj`, select the Overtone scheme, and run on iOS 26 or later. Source project generation uses XcodeGen (`xcodegen generate`). No third-party runtime dependencies, microphone, account, or network are required.

## Start here

In Learn, touch any piano key. Read the frequency in hertz, see a calculated wave, and feel a strike with a short decay on supported iPhones. Each discovery is earned by playing an experiment. Use Journey to revisit any of the ten experiments. Understand this opens the full explanation without covering the instrument in technical text.

The path is vibration → pitch → half-steps → octaves → C major scale → timbre → major chord → minor chord → steady pulse → an opening phrase from Ode to Joy. Amber dots identify the next key. Chord exercises require the notes held together; pressing them separately does not pass. Melody exercises check note order; their final phrase does not grade rhythm or fingering. The pulse exercise checks four note onsets at 80 BPM with a 22% interval tolerance, capped at 180 milliseconds.

Lab exposes all 88 piano keys, A0 to C8, through the octave arrows. Keep notes lets one finger stack a chord; Release all clears it. Sustain keeps released notes ringing until the pedal is switched off. Switch between Pure wave and a synthesized Piano-like tone. The frequency ratio panel uses the lowest and highest displayed notes; up to four voices are visualized, with a disclosure when more are held. Audio supports 32 simultaneous voices.

Practice plays a hidden C, D, E, F, or G. Find it by ear and receive directional feedback. The metronome has independently audible, visual, and haptic pulses, with the first beat accented.

Sound and touch settings include volume, haptics, haptic strength, short decay feel, and key names. Sound, touch preferences, completed discoveries, and the current lesson persist locally. Sound uses the current output route and plays in silent mode when enabled. Backgrounding, interruptions, and route changes silence the instrument; pressing a key starts it again.

## What the visual and tactile models mean

The keyboard uses equal temperament at A4 = 440 Hz: `f = 440 × 2^((MIDI − 69)/12)`. Octaves are exactly 2:1; fifths and thirds approximate simple ratios. The scope displays a 10 ms slice of each voice's **starting** waveform, animated slowly for viewing. The harmonic bars use the same initial harmonic recipe as audio. Actual partials fade at different rates; neither plot is a microphone measurement. Real piano strings can have slightly inharmonic partials.

Core Haptics maps register to sharpness and gives a brief strike/decay envelope. The haptic motor does not reproduce the audible pitch. Sound produces the true frequency. Reduce Motion freezes the wave while preserving its geometry and readouts. VoiceOver names individual keys and activates short notes; visual keys support multiple fingers and glissando. Physical piano posture, fingering, touch, and reading notation require further practice beyond this app.

## Verify

```sh
CLANG_MODULE_CACHE_PATH=/tmp/OvertoneClangCache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/OvertoneSwiftModuleCache swift test --disable-sandbox --scratch-path /tmp/OvertoneCore-build
bash Tools/check-audio.sh
```

`UITests/OvertoneUITests.swift` verifies earned completion versus demonstrations, correct/wrong sequences, progress restoration, layering, settings, and ear feedback. UI tests use their own defaults suite and never reset a learner's normal progress.

On this host Xcode stalled in a coordinated Documents read. Building an identical temporary copy avoids that host issue:

```sh
ditto "$PWD" /tmp/OvertoneStaged
xcodebuild -project /tmp/OvertoneStaged/Overtone.xcodeproj -scheme Overtone -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/OvertoneVerifiedBuild CODE_SIGNING_ALLOWED=NO build
```

See `VERIFICATION.md` for the completed checks and their limits. Native motor feel and output latency require physical-device assessment.

## Sources and design

- [UNSW: notes and frequencies](https://www.phys.unsw.edu.au/music/notes.html)
- [UNSW: temperament and frequency ratios](https://phys.unsw.edu.au/jw/tartini-temperament.html)
- [UNSW: sound spectra](https://www.phys.unsw.edu.au/jw/sound.spectrum.html)
- [Acoustical Society of America: piano inharmonicity](https://acoustics.org/pressroom/httpdocs/134th/galembo.htm)
- [Apple: haptic sharpness](https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/hapticsharpness)
- [Apple: AVAudioSourceNode](https://developer.apple.com/documentation/avfaudio/avaudiosourcenode)

The visual concept in `Design/concept.png` was generated with the built-in image generation tool. `Design/concept-prompt.md` records the prompt. Its layout provided art direction; the implementation uses working native controls and scientifically constrained content. `Design/make-icon.swift` renders the code-native app icon.


## Public snapshot

See [PUBLICATION.md](PUBLICATION.md) for publication exclusions and setup requirements.
