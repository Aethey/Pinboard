# Rejected experiment — full Board crossfade

The first motion pass crossfaded the entire outgoing and incoming canvas during a Board switch. The benchmark caught a material regression, so this experiment was removed before the final implementation.

| Metric | Original baseline | Full crossfade | Change |
| --- | ---: | ---: | ---: |
| CPU time | 1.339 s | 1.585 s | +18.4% |
| Hitch ratio | 27.075 ms/s | 33.585 ms/s | +24.0% |
| Peak physical memory | 170,623.965 kB | 215,965.061 kB | +26.6% |

Both canvases existed briefly during the transition, increasing rendering work and memory. The final design switches the canvas directly and uses only the small staged-loading indicator already provided by `BoardCardsLayer`.

Raw local result bundle for the interrupted experiment: `/tmp/PinboardPerfAfter-20260831.xcresult`.
