# Motion benchmark — final comparison

- Date: 2026-08-31
- Build: Release
- Fixture: `normal` — two Boards, 24 cards per Board
- Iterations: 5 per measured interaction
- Computer: MacBook Air, Apple M5 (10 cores), 16 GB memory
- Software: macOS 26.6.2, Xcode 26.6 (17F113)
- Metrics: XCTest CPU time, animation hitch ratio, and peak physical memory

## Verification result

The corrected five-test performance suite passed **5 of 5 tests**. After the suite, the zoom curve was shortened and its dedicated five-iteration test passed again.

Sanitized pass/fail summaries extracted with `xcresulttool` are retained in [the complete-suite JSON](2026-08-31-final-test-summary.json) and [the zoom-refinement JSON](2026-08-31-zoom-test-summary.json).

Final raw local result bundles:

- Complete accepted suite: `/tmp/PinboardPerfFinal-20260831.xcresult`
- Final zoom refinement: `/tmp/PinboardPerfZoomFinal-20260831.xcresult`
- Accessibility-harness validation for collapse and drag: `/tmp/PinboardPerfValidation-20260831.xcresult`

## Before and after

Lower values are better. These are direct comparisons for the three interactions that produced valid original measurements.

| Interaction | Metric | Original | Final | Change |
| --- | --- | ---: | ---: | ---: |
| Board switch | CPU time | 1.339 s | 1.219 s | **−9.0%** |
|  | Hitch ratio | 27.075 ms/s | 22.158 ms/s | **−18.2%** |
|  | Peak memory | 170,623.965 kB | 171,236.726 kB | +0.4% |
| Search open/close | CPU time | 0.804 s | 0.774 s | **−3.8%** |
|  | Hitch ratio | 58.717 ms/s | 63.255 ms/s | +7.7% |
|  | Peak memory | 156,324.005 kB | 151,834.813 kB | **−2.9%** |
| Zoom/reset | CPU time | 0.957 s | 0.756 s | **−21.0%** |
|  | Hitch ratio | 59.142 ms/s | 65.541 ms/s | +10.8% |
|  | Peak memory | 157,700.261 kB | 153,574.770 kB | **−2.6%** |

Animation hitch results vary substantially between iterations: the original search and zoom samples had relative standard deviations of approximately 41% and 38%. Their final hitch changes are inside that observed run-to-run noise and are not treated as a demonstrated regression or improvement. Board switching improved both CPU and hitch means without temporarily keeping two complete canvases alive.

## Newly reliable coverage

The first baseline exposed accessibility problems in the test harness for collapse and drag, so it did not produce trustworthy before-change figures for them. After fixing the test hooks, both interactions passed in the final suite:

| Interaction | CPU time | Hitch ratio | Peak memory | Result |
| --- | ---: | ---: | ---: | --- |
| Card collapse → expand | 0.287 s | 12.947 ms/s | 145,739.941 kB | Passed |
| Card drag out → back | 0.893 s | 24.682 ms/s | 149,888.370 kB | Passed |

## Decision made from the benchmark

An initial implementation crossfaded the complete old and new Board. It raised CPU by 18.4%, hitching by 24.0%, and peak memory by 26.6%, so it was removed. The accepted implementation switches Board content directly, retains the existing lightweight staged loader, and centralizes short, reduced-motion-aware animations for card controls, search, hover, and canvas actions.

See [the rejected experiment](2026-08-31-rejected-board-crossfade.md) for its recorded measurements. All five final samples for every metric are retained in [the final CSV](2026-08-31-motion-final.csv); original samples are in [the baseline CSV](2026-08-31-motion-baseline.csv).
