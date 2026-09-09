# Markdown rendering — 2026-09-09

The fix adds lazy document blocks, bounded caches for Markdown/inline parsing, precomputed table column lengths, and a value-based EquatableView boundary for unchanged previews. Table widths are computed from the full parsed document to keep horizontal scroll extent stable. Source text keys prevent reuse of stale content after edits.

Baseline renderer: `f27c837`. Both standalone variants were compiled with `swiftc -O` and run on macOS 26.6.2 (25G83), with 12 cards containing 24 Markdown sections each. The fixed application also completed a Release build successfully.

| Operation | Before CPU (s) | After CPU (s) | Change |
| --- | ---: | ---: | ---: |
| Initial layout (one sample) | 1.977242 | 0.069423 | -96.5% |
| First-card scroll targets (five-sample mean) | 0.297603 | 0.049309 | -83.4% |
| Pan all previews (five-sample mean) | 0.389549 | 0.055249 | -85.8% |

Each interaction sample contains six programmatic updates. CPU measures user + system time in a standalone NSHostingView hosting production MarkdownContentView. Scrolling uses ScrollViewReader targets and panning uses offsets; these are not physical trackpad or full-board hitch measurements. Raw wall times include settling delays. The results support reduced rendering CPU cost, not a guarantee of hitch-free board scrolling.

Viewport screenshots were inspected for both variants: headings, wrapping, Chinese text and inline formatting remained visible. Follow-up table/end-of-document/edit comparison was stopped at the user's request and is not claimed as verified.

## UI-test startup failures

All three attempts below failed before running test cases: the test runner was killed before connecting to the test manager. Re-signing, including with the local development certificate, did not resolve startup. No passing UI tests or frame hitch metrics are claimed.

- `/tmp/PinboardMarkdownBefore-20260909.xcresult`
- `/tmp/PinboardMarkdownBeforeSigned-20260909.xcresult`
- `/tmp/PinboardMarkdownBaseline-20260909.xcresult`

## Evidence

- [Before samples](2026-09-09-markdown-before.json)
- [After samples](2026-09-09-markdown-after.json)
- Harness: `Benchmarks/Tools/MarkdownRenderingBenchmark.swift`
- Runner: `Benchmarks/Tools/run-markdown-rendering-benchmark.sh`
- Local standalone outputs: `/tmp/PinboardMarkdownDirect-20260909/`
- Successful Release build log: `/tmp/PinboardMarkdownAfterBuild-20260909.log`

Reproduction from the repository root, when explicitly requested:

```bash
bash Benchmarks/Tools/run-markdown-rendering-benchmark.sh
bash Benchmarks/Tools/run-markdown-rendering-benchmark.sh /path/to/baseline/MarkdownContentView.swift baseline
```

The standalone harness uses temporary fixture content, not user boards. New XCTest cases `testMarkdownScrollCycle` and `testMarkdownCanvasPanCycle` use the long-document `markdown` fixture for future UI measurements when runner startup is available.
