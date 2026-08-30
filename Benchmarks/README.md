# Pinboard performance benchmarks

Pinboard keeps its performance checks in the repository so UI and motion changes can be measured again instead of judged only by feel.

## What is included

- `PinboardPerformanceTests/PinboardPerformanceTests.swift` contains repeatable macOS UI performance tests.
- `Pinboard/Utilities/PerformanceTestConfiguration.swift` creates deterministic, in-memory boards. It never reads or changes the user's real Pinboard data.
- `results/` contains dated benchmark records with the machine, build configuration, result status, and measured values.

The suite covers Board switching, card collapse/expand, search open/close, canvas zoom/reset, and card dragging. Each measured interaction runs five times and records CPU time, animation hitch ratio, and peak physical memory through XCTest.

## Fixture sizes

| Profile | Cards per Board | Total cards | Purpose |
| --- | ---: | ---: | --- |
| `normal` | 24 | 48 | Routine regression check |
| `heavy` | 150 | 300 | Busy real-world Board |
| `stress` | 500 | 1,000 | Stress and scaling investigation |

Every profile uses the same IDs, positions, card kinds, text, sizes, and two-Board structure on every run.

## Run in Xcode

1. Open `Pinboard.xcodeproj`.
2. Select the `Pinboard` scheme and **My Mac**.
3. Open the Test navigator.
4. Run `PinboardPerformanceTests`.

To run one test, use the diamond beside that test's name. Xcode shows the performance measurements in the test report.

## Run from Terminal

```bash
xcodebuild test \
  -project Pinboard.xcodeproj \
  -scheme Pinboard \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/PinboardPerformance \
  -resultBundlePath /tmp/PinboardPerformance.xcresult \
  -only-testing:PinboardPerformanceTests/PinboardPerformanceTests
```

Use a larger deterministic fixture by adding one of these before the command:

```bash
export PINBOARD_PERFORMANCE_FIXTURE=heavy
# or
export PINBOARD_PERFORMANCE_FIXTURE=stress
```

The result bundle can be opened directly in Xcode. Choose a new output path, or remove the old bundle, before running the same command again.

## Comparing motion

Normal runs use Pinboard's production motion system. For an animation-off control run, add:

```bash
export PINBOARD_MOTION=disabled
```

This switch is available only as a launch environment for testing; it does not add an end-user setting or alter saved data.

## Recorded runs

- [Original motion baseline](results/2026-08-31-motion-baseline.md) — the valid before-change measurements and an honest record of two initial test-harness failures.
- [Final comparison](results/2026-08-31-motion-comparison.md) — the accepted animation implementation, before/after figures, and final pass status.
- [Rejected Board crossfade](results/2026-08-31-rejected-board-crossfade.md) — an animation experiment removed after it increased CPU, hitching, and memory.

The matching CSV files retain all five samples behind each reported mean. The JSON summaries preserve Xcode's pass/fail counts without committing large, machine-specific `.xcresult` bundles. Local bundle paths are listed in the dated reports so a run can still be opened in Xcode while it remains on the machine.
