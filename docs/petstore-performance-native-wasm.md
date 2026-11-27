# Pet Store evidence and native/WASM research direction

Date: 2026-11-27. Status: user-reported local evidence, architecture direction accepted; implementation hypotheses unverified.

## Integration evidence

Reference app: [sergii/petstore PR #1](https://github.com/sergii/petstore/pull/1), benchmark runner commit e168e2dc4d986679b2531df5b1cecf952bbd2940, locked Domstride 0f7efe9825e385c05bc59839d388f188304d36e7. Ruby 4.0.10, Rails 8.1.4.1, Importmap/Propshaft, Turbo, Stimulus, Node 26.7.0 (previous local diagnostic), jsdom31 compatible profile. No changes to original test scenarios. Four stacked draft fixes: #3 UTF-8 Rack response body, #5 cross-realm AbortSignal, #7 immediate scroll-to-origin, #9 scoped Capybara confirm. Progress: 0, 2, 5, 12, 15 assertions; final 3 runs / 15 assertions / 0 failures / 0 errors / 0 skips. Full Domstride regression/CI and merge review still required.

## Sequential benchmark

User-provided terminal summary: 2 warmups per driver, 10 measured fresh Rails processes per driver, alternating driver order, paired seeds, single Rails worker. All samples PASS. Smoke: runner tests 5/5, 18 assertions. Raw JSON/logs remain local and were not supplied; summary and visible per-run wall/RSS values are evidence, not independent replication.

| Metric | Selenium | Domstride | Domstride relative change |
|---|---:|---:|---:|
| Median wall seconds | 3.265 | 3.095 | -5.2% |
| p95 wall seconds | 3.760 | 3.180 | -15.4% |
| Median CPU seconds | 2.610 | 3.925 | +50.4% |
| Median sampled peak process-tree RSS MiB | 1578.2 | 381.2 | -75.8% |
| Measured tests / assertions | 30 / 150 | 30 / 150 | equal |

Wall speedup 1.055x. RSS ratio 4.14x. Do not claim 4x faster or 4x more parallel workers: CPU cost and shared RSS pages complicate that inference. CPU is time -p waited-child accounting and can omit detached processes; RSS is sampled concurrent sum, not unique memory. Ten-sample nearest-rank p95 is maximum. No general browser parity or CI cost savings established.

| Pair | Selenium wall s | Domstride wall s | Selenium RSS MiB | Domstride RSS MiB |
|---:|---:|---:|---:|---:|
| 1 | 3.36 | 3.12 | 1574.3 | 382.4 |
| 2 | 3.23 | 3.10 | 1579.4 | 379.7 |
| 3 | 3.23 | 3.09 | 1577.2 | 387.2 |
| 4 | 3.20 | 3.00 | 1579.3 | 380.2 |
| 5 | 3.26 | 3.14 | 1737.0 | 388.6 |
| 6 | 3.27 | 3.09 | 1724.4 | 378.4 |
| 7 | 3.27 | 3.01 | 1563.9 | 379.4 |
| 8 | 3.18 | 3.04 | 1582.2 | 384.4 |
| 9 | 3.49 | 3.13 | 1564.6 | 382.2 |
| 10 | 3.76 | 3.18 | 1475.1 | 380.0 |

## Product direction

Accepted long-term direction: **Ruby-first, native-accelerated, browserless testing engine**. WASM-capable is a proposed extension, not a shipped feature. Resource-efficient testing driver is an evidence-backed positioning candidate for this workload. Keep Ruby/Capybara public API stable and preserve explicit compatibility boundaries; never silently fall back or weaken tests.

Rust is the preferred candidate for native experiments (not a commitment to a rewrite). Zig is a possible alternative where C ABI or low-level deployment needs justify it. Use profiling before selecting a component. Candidate pure-data work: snapshot/diff, recording compression/decoding, HTML parsing, selector indexing, IPC serialization. A native DOM or JS engine is a separate long-term R&D project; DOM/Web APIs, synchronous event semantics and Hotwire compatibility are far more expensive than swapping a parser.

WASM is complementary to Rust: a compilation target and host execution model, not a DOM or JS runtime. Three possible routes:
- Node host + Rust/WASM (wasm-bindgen) for coarse-grained operations, compared against JS and napi-rs native bindings.
- Ruby + Wasmtime for isolated pure computations; compare against Magnus/rb-sys native binding. Host permissions, call overhead, memory copies and platform packaging matter.
- Browser Replay Viewer + shared Rust/WASM snapshot diff/reconstruction/codec: promising portability use case, no application scripts executed by replay. Same deterministic test vectors across Ruby/Node/browser.

Research candidates only: html5ever, Servo selector crates, Wasmtime/wasmtime-rb, wasm-bindgen, Magnus, napi-rs, dawm and tljs. Evaluate maturity, license, correctness, API coverage and benchmark against actual workload before adoption. No compatibility or performance promises for these projects. Proposed layout native/domstride-core, domstride-ruby, domstride-node, domstride-wasm only when a justified prototype exists.

## Performance discovery sequence

1. Keep verified dependency pin and existing test parity; inspect all four draft fixes against current foundation/mvp before merge.
2. Collect command counts, Ruby round-trip wall time, worker wall time, Rack requests/time, bytes transferred, bundle hits/misses using existing profiler. Collect Ruby process CPU and optional Node V8 CPU stacks separately. Nested measurements overlap; do not sum them as disjoint CPU categories. Profile runs are diagnostic and not timing baselines.
3. Identify mount/asset resolution vs DOM initialization vs query/IPC vs Rack vs worker lifecycle. Existing compiled classic-script cache is not evidence that Importmap esbuild output is cached.
4. A/B only one change at a time, identical driver configuration, tests and seeds. Candidates: module asset cache keyed by complete graph/content and runtime version; fewer IPC round trips; safe worker lifecycle reuse with document/cookie/timer/handle isolation.
5. Parallel scalability: independent workers with isolated databases/state, 1/2/4/8 then 16/32 if capacity permits; throughput, wall time, CPU, RSS and correctness; distinguish measured from extrapolated.
6. Native PoC only after a measured hot path; benchmark JS/Ruby baseline, Rust native, Rust WASM including crossing/copy/startup costs. Require correctness vectors and maintenance/packaging cost evaluation.

Do not reorder existing report/replay/Fizzy roadmap or merge foundation changes implicitly. This research track feeds batch 011 performance work.
