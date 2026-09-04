# Multi-selection and Fit Content performance comparison

- Date: 2026-09-04
- Fixture: `normal` — two Boards, 24 cards per Board
- Iterations: 5 per measured interaction
- Computer: MacBook Air, Apple silicon (`arm64`)
- Software: macOS 26.6.2 (25G83), Xcode 26.6
- Metrics: XCTest CPU time, animation hitch ratio, and peak physical memory
- Valid baseline bundle: `/tmp/PinboardBenchmarkBeforeRepeat-20260904.xcresult`
- Valid final bundle: `/tmp/PinboardBenchmarkAfterFinal-20260904.xcresult`

Both accepted bundles passed two tests with no failures. The earlier `/tmp/PinboardBenchmarkBeforeRetry-20260904.xcresult` contained zero executed tests and is excluded. `/tmp/PinboardBenchmarkAfter-20260904.xcresult` is retained locally as an intermediate run but is not used for the final comparison.

## Mean results

| Interaction | Metric | Before | After | Change |
| --- | --- | ---: | ---: | ---: |
| Select all → Fit Content | CPU time | 0.197595 s | 0.058540 s | -70.4% |
| Select all → Fit Content | Hitch ratio | 20.000 ms/s | 0.000 ms/s | -100.0% |
| Select all → Fit Content | Peak memory | 149,498.406 kB | 146,146.240 kB | -2.2% |
| Select all → zoom out twice → reset | CPU time | 0.714607 s | 0.748361 s | +4.7% |
| Select all → zoom out twice → reset | Hitch ratio | 38.925 ms/s | 85.706 ms/s | +120.2% |
| Select all → zoom out twice → reset | Peak memory | 179,857.958 kB | 180,506.789 kB | +0.4% |

Lower values are better for all three metrics.

## Conclusion

The final Fit Content implementation materially reduced measured CPU time, eliminated recorded hitches in all five accepted samples, and slightly reduced peak memory. This supports the content-height measurement cache and the avoidance of redundant model writes.

The selected-card zoom path did not improve in the same run. CPU time and peak memory were nearly flat, but the mean hitch ratio increased from 38.925 to 85.706 ms/s. That regression is recorded rather than attributed to the Fit Content optimization or omitted. It should be rechecked in a dedicated zoom investigation before claiming an overall multi-selection rendering improvement.

The matching CSV contains every accepted sample. The JSON file preserves the pass counts, environment, means, and calculated changes without committing the large machine-specific `.xcresult` bundles.
