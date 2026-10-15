#!/bin/zsh
set -eu

task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_build="$(mktemp -d "${TMPDIR:-/private/tmp}/overtone-audio-check.XXXXXX")"
trap 'rm -rf "$task_build"' EXIT

xcrun swiftc -swift-version 6 -module-cache-path "$task_build/ModuleCache" \
  -emit-library -emit-module -module-name OvertoneCore \
  "$task_root/Sources/OvertoneCore/MusicTheory.swift" \
  -emit-module-path "$task_build/OvertoneCore.swiftmodule" \
  -o "$task_build/libOvertoneCore.dylib"

xcrun swiftc -swift-version 6 -O -module-cache-path "$task_build/ModuleCache" \
  -I "$task_build" -L "$task_build" -lOvertoneCore \
  -Xlinker -rpath -Xlinker "$task_build" \
  "$task_root/App/Sensory/PianoSynth.swift" "$task_root/Tools/audio-check.swift" \
  -o "$task_build/check-audio"

"$task_build/check-audio"
