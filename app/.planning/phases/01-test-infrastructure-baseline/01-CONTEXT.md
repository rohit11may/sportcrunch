# Phase 1: Test Infrastructure & Baseline - Context

**Gathered:** 2026-01-11
**Status:** Ready for research

<vision>
## How This Should Work

End-to-end tests that process real videos through the full detection pipeline. The test infrastructure should support both quick smoke tests for rapid development feedback and a thorough suite for pre-commit confidence.

Tests should feel fast enough to run frequently during development (using short test videos) while also providing comprehensive coverage when needed. The focus is on pipeline correctness: feed in a video, verify the right rallies/shots were detected.

**Golden test approach:** Tests pair test videos with their ground truth segments (based on highlight type: rally vs shot-by-shot). Since algorithm tuning produces slightly different timestamps on each run, evaluation uses fuzzy matching rather than exact timestamp comparison.

**Evaluation function:** Measures how well detected segments match ground truth using:
- Fuzzy matching to handle timing variations between runs
- False-positive rate: How much video did the algorithm keep that wasn't part of ground truth? (Guardrail: <15%)
- False-negative rate: How much ground truth video did it miss? (Guardrail: <10%)

Tests should use standard XCTest patterns with async/await support, making it straightforward for any iOS developer to understand and extend.

</vision>

<essential>
## What Must Be Nailed

- **Segment detection verification** - The ability to feed in a video and assert that the right rallies/shots were found. This is the foundation everything else builds on.
- **Fuzzy matching evaluation** - Evaluation function that handles timing variations gracefully while catching real regressions through FP/FN guardrails
- **Ground truth pairing** - Clear pattern for associating test videos with their expected segments based on highlight type

</essential>

<boundaries>
## What's Out of Scope

- UI testing - This phase focuses purely on the video processing and segment detection pipeline. SwiftUI interface testing comes later.
- Performance/speed benchmarks - Establishing correctness tests first. Measuring and optimizing processing speed is a separate concern.
- Comprehensive edge case coverage - Phase 1 is about infrastructure and patterns. Exhaustive test case coverage happens in Phase 3.

</boundaries>

<specifics>
## Specific Ideas

- Use XCTest following Apple's standard conventions - keep it recognizable to any iOS developer
- Test videos should be simple and short (10-30 seconds) for fast execution while still exercising detection logic
- Quick smoke tests + thorough suite: fast subset for development flow, comprehensive suite for commits
- FP/FN rate guardrails: <15% false-positive, <10% false-negative (tighter on FN since missing real segments is worse)
- Combined fuzzy matching approach (likely overlap metrics + boundary tolerance, to be explored during research/planning)

</specifics>

<notes>
## Additional Context

The core insight is that exact timestamp matching won't work for algorithm validation - need fuzzy evaluation that tolerates minor timing variations while catching real problems through false-positive/false-negative rate guardrails.

The two-tier test approach (quick + thorough) enables both rapid development iteration and high-confidence validation before commits.

</notes>

---

*Phase: 01-test-infrastructure-baseline*
*Context gathered: 2026-01-11*
