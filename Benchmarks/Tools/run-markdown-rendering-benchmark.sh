#!/bin/bash
set -euo pipefail

# Run from the repository root. Optional arguments: renderer source and
# "optimized" (enables the same EquatableView boundary used by BoardCardView).
renderer="${1:-Pinboard/Views/MarkdownContentView.swift}"
variant="${2:-optimized}"
build_dir="$(mktemp -d /tmp/pinboard-markdown-benchmark.XXXXXX)"
flags=(-D MARKDOWN_BASELINE)
if [[ "$variant" == "optimized" ]]; then flags+=(-D MARKDOWN_OPTIMIZED); fi
xcrun swiftc -O -swift-version 5 -default-isolation MainActor -parse-as-library \
  -module-cache-path "$build_dir/module-cache" \
  "${flags[@]}" "$renderer" Benchmarks/Tools/MarkdownRenderingBenchmark.swift \
  -o "$build_dir/benchmark"
"$build_dir/benchmark"
