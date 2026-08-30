# Motion benchmark — original implementation

- Date: 2026-08-31
- Build: Release
- Fixture: `normal` — two Boards, 24 cards per Board
- Iterations: 5 per measured interaction
- Computer: MacBook Air, Apple M5 (10 cores), 16 GB memory
- Software: macOS 26.6.2, Xcode 26.6 (17F113)
- Metrics: XCTest CPU time, animation hitch ratio, and peak physical memory
- Raw local result bundle: `/tmp/PinboardPerfBaselineFull.xcresult`

## Results

| Interaction | CPU time | Hitch ratio | Peak memory | Test result |
| --- | ---: | ---: | ---: | --- |
| Board switch A → B → A | 1.339 s | 27.075 ms/s | 170,623.965 kB | Passed |
| Search open → close | 0.804 s | 58.717 ms/s | 156,324.005 kB | Passed |
| Zoom out twice → reset | 0.957 s | 59.142 ms/s | 157,700.261 kB | Passed |
| Card collapse → expand | — | — | — | Harness failed to locate the nested control |
| Card drag out → back | — | — | — | Harness matched inherited duplicate identifiers |

## Integrity note

This first baseline intentionally records the two harness failures instead of presenting them as application regressions or removing them from the report. The failures exposed unstable accessibility identifiers in the initial test implementation. The test hooks were then separated into a dedicated card drag area and individual control identifiers before the after-change suite was run.

The three passing interactions above remain valid before-change measurements and are used for direct comparison. Collapse and drag are reported only in the corrected after-change run because there is no trustworthy before-change sample for them.
