# Pitfalls Research: Multi-Method Comparison Framework

**Domain:** Plugin-based comparison framework for video segmentation methods
**Researched:** 2026-01-19
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Premature Interface Abstraction (The "One Shape Fits All" Trap)

**What goes wrong:**
You design an abstract method interface too early, forcing fundamentally different algorithms into incompatible shapes. Methods end up implementing dummy/null operations just to satisfy the interface, or worse, you contort the working algorithm to fit the abstraction, breaking what made it effective.

**Why it happens:**
Natural desire for clean architecture before understanding the problem space. The AV-Funnel (audio-first) and Streak-Context (vision-first) methods use completely different detection primitives:
- AV-Funnel: Audio waveform → onset peaks → temporal clustering
- Streak-Context: Motion heatmap → Hough lines → FSM states

Designing the interface before implementing the second method means speculating about shared abstractions that may not exist.

**How to avoid:**
1. **Implement the second method in parallel BEFORE abstracting** — Work with concrete, running code for both methods
2. **Extract interfaces from working implementations, not from theory** — Let the natural commonalities emerge
3. **Accept method-specific components** — Not everything needs to be abstracted; duplication is better than wrong abstraction
4. **Use composition over inheritance** — Methods can share utilities without sharing interfaces

**Warning signs:**
- Interface methods with names like `get_intermediate_data()` returning `Any` or `dict`
- Methods implementing interface methods that just `raise NotImplementedError` or return `None`
- Comments like "This doesn't apply to X method" in interface documentation
- Arguments to interface methods that only make sense for one implementation

**Phase to address:**
Phase 1 (Method Integration) — Refactor AV-Funnel into isolated module WITHOUT abstracting. Phase 2 (Second Method) — Implement Streak-Context standalone. Phase 3 (Framework Layer) — Extract common patterns AFTER both methods work.

---

### Pitfall 2: Breaking the Working Prototype During Refactoring

**What goes wrong:**
The existing AV-Funnel implementation works and produces correct results. During refactoring to create the framework, you change the algorithm logic alongside the architectural changes. When tests fail, you don't know if it's the refactor or a real bug. You lose the working baseline.

**Why it happens:**
Mixing concerns — refactoring (restructuring code) and enhancement (changing behavior) happen simultaneously. You see "improvements" while moving code and can't resist making them. No test coverage means you can't verify behavior preservation.

**How to avoid:**
1. **Establish frozen baseline** — Tag the working commit, capture output on test videos
2. **Refactor-only commits** — Separate structural changes from behavioral changes completely
3. **Behavioral regression tests FIRST** — Before touching code, write tests that capture current behavior (even if imperfect)
4. **Parallel implementation during transition** — Keep old code working while building new structure, switch atomically
5. **Output comparison, not code comparison** — For each refactor step, verify identical output on test videos

**Warning signs:**
- Commits that say "refactor and fix X" — red flag combination
- Changing parameter values during code restructuring
- Test suite that only exists after refactoring, not before
- Inability to run the "old way" after starting refactoring
- Explaining behavior changes as "probably fine" or "seems better"

**Phase to address:**
Phase 0 (Pre-work) — Create test harness with frozen output from current AV-Funnel. Phase 1 (Refactoring) — Every commit must pass frozen-output tests before merging.

---

### Pitfall 3: Method-Biased Benchmarking Metrics

**What goes wrong:**
You choose evaluation metrics that inadvertently favor one method's design philosophy. For example, prioritizing "precision" over "recall" favors conservative methods (AV-Funnel audio detection with strict thresholds) over aggressive methods (Streak-Context with exploratory FSM). Neither method is "better" — they're optimized for different error profiles — but metrics make one look superior.

**Why it happens:**
Benchmarks designed while only one method exists naturally encode that method's implicit assumptions. The FVD metric for video quality is biased toward per-frame quality over temporal consistency. Similarly, if you design metrics while only AV-Funnel exists, you'll unconsciously choose metrics where it performs well.

**How to avoid:**
1. **Metric diversity** — Use complementary metric pairs: precision AND recall, speed AND accuracy, compression ratio AND segment completeness
2. **Method-blind metric design** — Design evaluation BEFORE implementing methods, based on user goals not algorithm characteristics
3. **Ground truth from domain, not from existing method** — Human-annotated rally boundaries, not "what AV-Funnel detected"
4. **Separate metrics for different use cases** — "Highlight reel" vs "coaching analysis" have different success criteria
5. **Metric justification** — For each metric, document WHY it matters to end users, not why it measures the algorithm

**Warning signs:**
- All metrics show one method as superior across the board (suggests bias, not truth)
- Metrics that measure algorithm intermediate steps rather than final user value
- Ground truth annotations that closely match one method's output
- Defensiveness when discussing metric choice ("but that's how everyone does it")
- Metrics chosen after seeing results, not before

**Phase to address:**
Phase 0 (Pre-work) — Define metrics and create ground truth annotations BEFORE refactoring. Phase 4 (Benchmarking) — Blind comparison using pre-defined metrics.

---

### Pitfall 4: Leaky Abstraction in Visualization Pipelines

**What goes wrong:**
You create a "generic" visualization component for FSM states, but it makes assumptions about state names, transition logic, or data structure that only apply to one method's FSM implementation. When the second method's FSM has different semantics (e.g., hierarchical states, parallel states, probabilistic transitions), the visualization breaks or requires extensive modification, defeating the purpose of the abstraction.

**Why it happens:**
FSM visualization seems like an obvious shared component — both methods use state machines. But FSMs are a pattern, not a data structure. Each FSM encodes domain-specific semantics:
- AV-Funnel might use states: `SILENT → POTENTIAL_RALLY → VALIDATED_RALLY`
- Streak-Context might use states: `SCAN_ROI → DETECT_BALL → VALIDATE_PLAYER → RALLY_ACTIVE`

The visualization must understand these semantics to be useful, which couples it to implementation details.

**How to avoid:**
1. **Data adapter pattern** — Methods provide visualization data in standardized format, but each method owns the adapter
2. **Minimal visualization primitives** — Generic component renders timelines/state transitions, but doesn't interpret meaning
3. **Accept method-specific visualizations** — Shared FSM timeline is fine, but Streak-Context's ROI heatmap can't be forced into AV-Funnel's waveform plot
4. **Composition over shared components** — Dashboard composes method-specific visualizations rather than forcing them through shared interface

**Warning signs:**
- Visualization code with conditionals: `if method_type == "av_funnel":`
- Method implementations passing raw internal state objects to visualization layer
- Visualization breaking when method implementation changes internal state representation
- Generic component with dozens of optional parameters to handle method-specific cases

**Phase to address:**
Phase 3 (Visualization Layer) — Build method-specific visualizations first, extract common rendering utilities (not abstractions) second.

---

### Pitfall 5: Test Harness Coupling to Method Internals

**What goes wrong:**
The test harness needs access to intermediate outputs for debugging (e.g., onset strength curve, ROI heatmaps), so you expose these as required method interface elements. Now every method must compute and expose intermediate data in specific formats, even when those intermediates don't naturally exist in their pipeline. The test harness becomes a de-facto method specification, constraining implementation choices.

**Why it happens:**
Desire for comprehensive testing and debugging drives exposure of internals. Without separation between "required for comparison" (final segment boundaries) and "useful for debugging" (algorithm intermediates), everything becomes required.

**How to avoid:**
1. **Separate interfaces** — Core comparison interface (required) vs. introspection interface (optional, method-specific)
2. **Logging/telemetry, not interface methods** — Methods emit debug data via structured logging; test harness consumes logs, not API calls
3. **Visualization hooks, not requirements** — Methods CAN provide visualization data through optional registry, not MUST through required interface
4. **Black-box primary evaluation** — Core benchmarks only use inputs (video) and outputs (segment boundaries), nothing internal

**Warning signs:**
- Method interface requiring methods like `get_onset_strength()` that don't apply to all methods
- Test harness failing when method doesn't implement debug/visualization methods
- Method implementations doing extra work just to satisfy test harness expectations
- Inability to benchmark new method without modifying test harness code

**Phase to address:**
Phase 2 (Test Harness) — Design two-tier architecture: required comparison interface (minimal) and optional debug/visualization hooks (extensible).

---

### Pitfall 6: Under-Abstraction: Duplicating Test/Export Logic Per Method

**What goes wrong:**
In avoiding over-abstraction, you swing too far and duplicate entire test harnesses, video loading, metrics calculation, and export logic for each method. Now fixing a bug in segment merging requires updating three codebases. Adding a new metric requires three implementations. The framework provides no value.

**Why it happens:**
Paralysis from fear of premature abstraction. Treating methods as completely independent systems when they DO share common infrastructure needs (video I/O, interval arithmetic, export pipeline).

**How to avoid:**
1. **Distinguish domain logic from infrastructure** — Method-specific: detection algorithms. Shared: video loading, segment merging, file export
2. **Utility libraries, not frameworks** — Provide reusable functions (merge_intervals, compute_iou) without forcing architectural patterns
3. **Dependency injection for shared services** — Methods receive video loader, metrics calculator as dependencies; don't instantiate their own
4. **Progressive abstraction** — Start with copy-paste, refactor when you see the SAME code (not similar) in three places

**Warning signs:**
- Identical video loading code in both method implementations
- Copy-pasted interval merging algorithms with different variable names
- Metrics calculated differently for each method despite measuring the same thing
- Export logic duplicated because "methods are independent"
- More than 50% code duplication between method implementations

**Phase to address:**
Phase 1 (Shared Infrastructure) — Identify and extract provably common operations (video I/O, interval math, metrics) BEFORE abstracting method interface.

---

### Pitfall 7: Visualization Performance Collapse

**What goes wrong:**
The interactive dashboard (Streamlit) loads entire 3-hour videos into memory for visualization. Adding ROI heatmaps for Streak-Context means rendering 300,000+ frames. The dashboard becomes unusably slow or crashes. Developers optimize by reducing video resolution, which makes the visualization useless for debugging.

**Why it happens:**
Visualization code written for small test clips (30 seconds) scales poorly to real match videos (3 hours). Memory-efficient processing (streaming video frames) conflicts with interactive visualization needs (random access to frames).

**How to avoid:**
1. **Pre-compute visualization artifacts** — Processing phase generates static visualizations (images, JSON timelines), dashboard displays them
2. **Sampling strategies** — Visualize every Nth frame for full video, but allow full-resolution inspection of specific segments
3. **Lazy loading** — Dashboard requests visualization data on-demand, methods provide generators not full arrays
4. **Separate processing and visualization pipelines** — Processing can be slow/thorough, visualization must be fast/responsive

**Warning signs:**
- Dashboard taking >30 seconds to load after processing completes
- Out-of-memory errors when adding second method's visualizations
- Developer comments like "reduce frame_stride to make this faster"
- Visualization code calling video processing functions synchronously
- Loading entire numpy arrays into Streamlit session state

**Phase to address:**
Phase 3 (Visualization) — Design visualization data format (lightweight JSON/PNG artifacts) separately from processing pipeline. Cap memory usage regardless of video length.

---

### Pitfall 8: Implicit Temporal Assumptions in Interval Merging

**What goes wrong:**
You write interval merging logic that assumes segments are short (< 30 seconds) and well-separated (> 2 second gaps). When Streak-Context produces long segments (entire games) or overlapping segments (FSM re-entry), the merging logic produces nonsensical results or exponential runtime. Tests pass because they use the same assumptions as the implementation.

**Why it happens:**
Merging logic optimized for AV-Funnel's characteristic output pattern (audio peaks clustered into rally segments). Implicit assumptions about segment duration, gap distribution, and overlap patterns encoded in implementation without documentation or validation.

**How to avoid:**
1. **Document interval assumptions** — Explicitly state expected segment duration, gap sizes, overlap behavior
2. **Adversarial test cases** — Test with pathological inputs: zero-length segments, fully-overlapping segments, entire-video segment
3. **Algorithm complexity analysis** — Ensure O(n log n) or better, even with n = all video frames
4. **Configuration validation** — Reject invalid configurations (e.g., padding > max_gap creates unavoidable overlaps)

**Warning signs:**
- Merging algorithm using nested loops without early termination
- Test suite only using "realistic" examples from one method's output
- Unexpected behavior when methods produce very long or very short segments
- Runtime increasing exponentially with number of segments

**Phase to address:**
Phase 1 (Shared Infrastructure) — Design interval merging with explicit complexity guarantees and tested with adversarial cases before methods depend on it.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using dict for method results instead of dataclass | No need to define schema upfront | Type confusion, runtime errors, impossible refactoring | Never — dataclasses are 5 lines |
| Skipping video validation during development | Faster iteration on audio detection | Can't evaluate real accuracy, false confidence in results | Only for isolated audio algorithm experiments |
| Hard-coding test video paths in code | Quick testing without config files | Can't share tests, can't run in CI, breaks on other machines | Never — use environment variables or config |
| Storing visualization data in Streamlit session_state | Easy access across UI components | Memory leaks, serialization failures, debugging nightmares | Only for small metadata, not large arrays |
| Copy-pasting parameter sets between methods | Quick setup of second method | Diverging configurations, unclear which values matter | Only as starting point, refactor immediately |
| Using global variables for pipeline components | Avoid dependency injection complexity | Untestable code, hidden coupling, initialization order bugs | Never — even in research code |

## Integration Gotchas

Common mistakes when connecting pipeline components.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Video loading (librosa vs OpenCV) | Assuming timestamps match (librosa resamples audio, OpenCV doesn't) | Always validate timestamp alignment with test pattern video |
| Frame-to-time conversion | Off-by-one errors in frame indexing (0-indexed vs 1-indexed) | Use time-based interval representation, convert to frames only at I/O boundary |
| Audio-video sync | Trusting container metadata for A/V sync offset | Extract audio/video independently, verify sync with known test signal |
| Streamlit reactivity | Modifying mutable objects expecting UI update | Use immutable data or explicit st.rerun() after mutations |
| NumPy array slicing | Expecting copies, getting views (mutations propagate) | Explicit `.copy()` when slicing for independent processing |
| Interval boundary conditions | Open vs closed intervals ([start, end) vs [start, end]) | Document convention explicitly, use dataclass with inclusive/exclusive flags |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Loading full video into RAM | Works on 1-minute clips, OOM on full matches | Stream frames, process in chunks, use generators | >1GB video files (~20 min at HD) |
| Recomputing onset strength on parameter changes | Fast for 30s clips, hangs on full videos | Cache computed features, only recompute dependent stages | >10 minute videos |
| Synchronous frame processing in visualization | Responsive for 1000 frames, freezes for 100k frames | Pre-generate visualization artifacts offline | >5000 frames to visualize |
| O(n²) interval comparison for merging | Unnoticeable for <100 segments, minutes for 1000s segments | Sort intervals once, linear merge pass | >500 segments |
| Storing full waveform in result objects | Fine for test clips, memory leak for long videos | Downsample for visualization, store analysis results only | >30 minute audio |
| Pickle/session_state for large arrays | Works in development, crashes in deployment | Use file-based caching (HDF5, NPZ), store paths not data | >100MB session state |

## Data Quality Pitfalls

Issues with ground truth annotations and test data.

| Pitfall | Impact | Prevention |
|---------|--------|------------|
| Ground truth annotated by running current method | Biased evaluation — method scores high on its own output | Manual annotation by domain experts, blind to method outputs |
| Test videos all from same source (broadcast/amateur/court-level) | Method overfits to one camera angle, fails on others | Diverse test set: multiple camera angles, lighting, court surfaces |
| Annotations only marking clear rallies, skipping edge cases | Inflated accuracy on "easy" cases, unknown behavior on ambiguity | Annotate EVERYTHING: disputed calls, lets, weather delays, challenges |
| Frame-level annotations when segment-level is sufficient | Annotation fatigue, inconsistency, wasted effort | Match annotation granularity to evaluation needs (segment boundaries) |
| Single annotator per video | Unchecked bias, inconsistent criteria | Multiple annotators with inter-rater agreement measurement |
| No version control for ground truth | Can't reproduce old benchmark results after annotation fixes | Git-track annotations, tag releases used in benchmarks |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Method refactoring:** Output matches old implementation on regression test videos (not just "works")
- [ ] **Benchmark metrics:** Defined and validated BEFORE seeing any method's results (not tuned to favor one method)
- [ ] **Visualization dashboard:** Works on 3-hour videos, not just 30-second clips (performance tested at scale)
- [ ] **Interval merging:** Tested with pathological cases (zero-length, overlapping, entire-video segments)
- [ ] **Ground truth annotations:** Independent of any method's output (manually created by domain experts)
- [ ] **Test harness:** Can benchmark a new method without modifying harness code (extensible)
- [ ] **Configuration management:** Same parameter values reproducible across runs (serialized, version-controlled)
- [ ] **Audio-video sync:** Verified with test pattern, not assumed from container metadata (validated)

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Broke AV-Funnel during refactor | MEDIUM | 1. Revert to frozen baseline commit. 2. Create regression test capturing old behavior. 3. Refactor incrementally with test validation at each step. |
| Method-biased benchmarks discovered | HIGH | 1. Admit bias publicly. 2. Re-annotate ground truth blind to methods. 3. Add complementary metrics. 4. Re-run all benchmarks. 5. Document lessons learned. |
| Leaky visualization abstraction | MEDIUM | 1. Accept method-specific visualizations. 2. Extract only rendering utilities (plotting, layout), not semantics. 3. Remove forced interface compliance. |
| Test harness coupled to internals | MEDIUM | 1. Define minimal comparison interface (input video → output segments). 2. Move debug/visualization to optional hooks. 3. Refactor existing methods to new interface. |
| Over-abstracted method interface | HIGH | 1. Identify dummy/forced implementations. 2. Split interface into truly common operations and method-specific. 3. Use composition/utilities instead of inheritance. |
| Under-abstracted (massive duplication) | LOW | 1. Identify identical code (not similar). 2. Extract to utility functions. 3. Progressive refactoring as more duplication emerges. |
| Visualization performance collapse | LOW | 1. Profile to find bottleneck. 2. Pre-compute expensive visualizations. 3. Implement sampling for long videos. 4. Use lazy loading for dashboard. |
| Bad interval merging on edge cases | LOW | 1. Write adversarial test cases. 2. Fix algorithm for general case. 3. Add complexity constraints (O(n log n)). 4. Document assumptions. |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Premature interface abstraction | Phase 3 (Framework Layer) — AFTER both methods exist | Can add third method without changing interface? |
| Breaking working prototype | Phase 0 (Pre-work) & Phase 1 (Refactor) | Frozen output tests pass on every commit? |
| Method-biased benchmarks | Phase 0 (Pre-work) — Before any implementation | Metrics defined blind to method characteristics? |
| Leaky visualization abstraction | Phase 3 (Visualization) | Method-specific viz possible without framework changes? |
| Test harness coupling | Phase 2 (Test Harness) | Mock method can run benchmarks without real implementation? |
| Under-abstraction (duplication) | Phase 1 (Shared Infrastructure) | Video I/O, interval math, export shared? |
| Visualization performance collapse | Phase 3 (Visualization) | Dashboard loads 3-hour video in <5 seconds? |
| Interval merging edge cases | Phase 1 (Shared Infrastructure) | Adversarial test suite passes? |

## Sources

**Academic Research:**
- [Exploiting Temporal State Space Sharing for Video Semantic Segmentation](https://arxiv.org/abs/2503.20824) — CVPR 2025 paper on temporal consistency in video segmentation
- [VBenchComp Framework](https://arxiv.org/html/2505.14321v1) — Breaking Down Video LLM Benchmarks: bias detection in video understanding metrics
- [Beyond FVD: Enhanced Evaluation Metrics for Video Generation Quality](https://arxiv.org/html/2410.05203v2) — Content-bias in video quality metrics
- [Clustering High-dimensional Data: Balancing Abstraction and Representation](https://arxiv.org/abs/2601.11160) — AAAI 2026 tutorial on abstraction trade-offs

**Software Engineering Best Practices:**
- [Good Refactoring vs Bad Refactoring](https://www.builder.io/blog/good-vs-bad-refactoring) — Common refactoring mistakes
- [What are the most common code refactoring mistakes to avoid?](https://www.linkedin.com/advice/0/what-most-common-code-refactoring-mistakes-avoid-cjfee) — LinkedIn article on refactoring pitfalls
- [The Double-Edged Sword of Abstraction in Software Engineering](https://blog.chinaza.dev/the-double-edged-sword-of-abstraction-in-software-engineering) — When abstraction helps vs hurts
- [The Economics of Technical Debt](https://www.javacodegeeks.com/2026/01/the-economics-of-technical-debt-market-theory-applied-to-code-quality.html) — 2026 analysis of premature abstraction as speculation

**Testing & Benchmarking:**
- [Analyzing Fairness of Computer Vision and Natural Language Processing Models](https://www.mdpi.com/2078-2489/16/3/182) — Fairness metrics and bias detection
- [VideoLLM Benchmarks and Evaluation: A Survey](https://arxiv.org/html/2505.03829v1) — Benchmark design for video understanding
- [Video Segmentation 2025 Guide](https://averroes.ai/blog/video-segmentation-guide) — Temporal consistency challenges

**Architecture Patterns:**
- [Computer Vision Pipeline Architecture: A Tutorial](https://www.toptal.com/developers/computer-vision/computer-vision-pipeline) — Toptal tutorial on CV system architecture
- [Agents Done Right: A Framework Vision for 2026](https://blog.bryanl.dev/posts/agent-framework-vision/) — Critique of abstraction layers in frameworks
- [A Survey of Visualization Pipelines](https://www.kennethmoreland.com/vis-pipelines/VisPipelines.pdf) — Generic vs method-specific visualization design

**Migration & Refactoring:**
- [Software Migration Guide for 2026](https://hicronsoftware.com/blog/software-migration-guide/) — Safe refactoring strategies
- [AI-Driven Refactoring in Large-Scale Migrations](https://medium.com/qonto-way/ai-driven-refactoring-in-large-scale-migrations-strategies-and-techniques-fcdb9b5116c6) — Phased migration approaches
- [Modeling Starts With the Question](https://blogs.mathworks.com/autonomous-systems/2026/01/15/modeling-starts-with-the-question-on-model-fidelity-abstraction-and-engineering-judgement/) — MathWorks 2026 blog on abstraction fidelity

**Domain Knowledge:**
- Existing AV-Funnel implementation (src/pipeline.py, src/audio_analyzer.py)
- PROJECT.md milestone description (Two fundamentally different detection methods)
- TECHNICAL.md (Detailed signal processing pipeline documentation)

---
*Pitfalls research for: Multi-method comparison framework for video segmentation*
*Researched: 2026-01-19*
*Confidence: HIGH — Grounded in current codebase + verified with 2025-2026 academic and industry sources*
