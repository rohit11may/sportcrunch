# Feature Research

**Domain:** Multi-Method Computer Vision Algorithm Comparison Framework
**Researched:** 2026-01-19
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features required for basic multi-method comparison. Missing these = framework feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Method Registry | Standard pattern for pluggable systems | LOW | Decorator-based self-registration is Python-idiomatic |
| Ground Truth Management | Can't compare without known-correct answers | MEDIUM | File-based storage with IoU/precision/recall metrics |
| Parallel Execution | Multiple methods should run independently | LOW | pytest-xdist or unittest-parallel provide this out-of-box |
| Basic Metrics (Precision/Recall/F1) | Industry standard for classification tasks | LOW | Simple confusion matrix math |
| Method Isolation | Each method's state shouldn't leak to others | MEDIUM | Clean interfaces + separate result objects |
| Result Persistence | Must save results to compare across runs | LOW | JSON/CSV export with timestamps |
| Side-by-Side Visualization | Core use case is comparing outputs | MEDIUM | Streamlit native columns or custom grid layout |
| Test Video Catalog | Need consistent test set for fair comparison | LOW | Directory-based with metadata files |

### Differentiators (Competitive Advantage)

Features that make this framework valuable for research, not just basic comparison.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Intermediate Output Capture | Visualize *how* methods arrive at results, not just final answer | MEDIUM | Method-specific hooks + typed result structure |
| Method-Specific Visualizations | Different algorithms need different debug views (audio waveforms vs heatmaps) | MEDIUM | Plugin architecture for viz components |
| FSM State Timeline | Temporal methods benefit from state visualization | MEDIUM | Reusable component across methods with FSM-based segmentation |
| Speed Benchmarking | Research needs to know computational cost, not just accuracy | LOW | Python time.perf_counter() with warmup runs |
| Compression Ratio Metrics | Domain-specific: how much dead time removed | LOW | Simple ratio calculation: output_duration / input_duration |
| Configurable Ground Truth Tolerance | IoU thresholds vary by use case | LOW | Parameterized validation with multiple threshold reporting |
| Result Diffing | Highlight where methods disagree | MEDIUM | Set operations on detected segments with visual highlighting |
| Batch Processing UI | Run entire test suite with one click | LOW | Streamlit button + progress bar |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems for a research tool.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Real-Time Processing | "Make it work live during matches" | Optimization before understanding what works; premature complexity | Offline analysis first, then optimize proven method |
| AutoML/Hyperparameter Tuning | "Automatically find best parameters" | Research goal is understanding methods, not black-box optimization | Manual parameter exploration with visualization |
| Production Deployment Features | "Add API endpoints, Docker, monitoring" | This is a research tool, not a product; maintenance burden | Keep it simple; production-ize proven methods separately |
| Universal Method Interface | "All methods must implement same interface" | Methods use fundamentally different primitives (audio vs visual); forced abstraction breaks | Minimal interface (run + results), method-specific everything else |
| Built-in Model Training | "Train new detectors in the framework" | Scope creep; training is separate concern from comparison | Use pre-trained models or train externally, import for comparison |
| Database for Everything | "Store all results in PostgreSQL" | Overkill for research tool; adds complexity | File-based storage (JSON/CSV) is sufficient and inspectable |

## Feature Dependencies

```
[Ground Truth Management]
    └──requires──> [Test Video Catalog]

[Basic Metrics (Precision/Recall/F1)]
    └──requires──> [Ground Truth Management]
    └──requires──> [Result Persistence]

[Side-by-Side Visualization]
    └──requires──> [Result Persistence]
    └──enhances──> [Result Diffing]

[Method-Specific Visualizations]
    └──requires──> [Intermediate Output Capture]
    └──requires──> [Method Registry]

[FSM State Timeline]
    └──requires──> [Intermediate Output Capture]

[Parallel Execution]
    └──requires──> [Method Isolation]
    └──enhances──> [Batch Processing UI]

[Speed Benchmarking]
    └──requires──> [Method Isolation]
    └──enhances──> [Basic Metrics]
```

### Dependency Notes

- **Basic Metrics require Ground Truth:** Can't compute precision/recall without known-correct answers
- **Side-by-Side Visualization requires Result Persistence:** Must load previous runs to compare
- **Method-Specific Visualizations require Intermediate Output Capture:** Can't visualize audio waveforms unless method exposes them
- **Parallel Execution requires Method Isolation:** Methods must not share state or corrupt each other's results
- **FSM State Timeline is reusable:** Works for any method that uses finite state machines (both AV-Funnel and Streak-Context)

## MVP Definition

### Launch With (v1.0 — Current Milestone)

Minimum viable framework for comparing 2 methods (AV-Funnel refactored + prepare for Streak-Context).

- [x] **Method Registry** — Plugin system using decorator-based self-registration pattern (simple, Pythonic)
- [x] **Test Video Catalog** — Directory-based with simple metadata files for ground truth
- [x] **Method Isolation** — Abstract base class with run() → results interface
- [x] **Result Persistence** — JSON export of detected segments + metadata
- [x] **Basic Metrics** — Precision, Recall, F1 computed against ground truth
- [x] **Intermediate Output Capture** — Method returns typed result object with optional intermediate fields
- [x] **Side-by-Side Visualization** — Streamlit dashboard with columns for each method's output
- [x] **Method-Specific Visualizations** — Plugin hooks for method to provide custom viz components (e.g., audio waveform)
- [x] **FSM State Timeline** — Reusable timeline component for temporal state visualization
- [x] **Batch Processing UI** — Run all methods on all test videos with progress tracking

### Add After Validation (v1.x)

Features to add once framework is working with 2 methods.

- [ ] **Parallel Execution** — Trigger: Test suite grows beyond 5 videos (runtime becomes bottleneck)
- [ ] **Speed Benchmarking** — Trigger: Methods have different computational profiles (need cost/accuracy tradeoff)
- [ ] **Result Diffing** — Trigger: Methods produce similar results, need to highlight subtle differences
- [ ] **Compression Ratio Metrics** — Trigger: Domain-specific validation (how much dead time removed)
- [ ] **Configurable Ground Truth Tolerance** — Trigger: Debate about what counts as "correct" detection (IoU threshold sensitivity)

### Future Consideration (v2+)

Features to defer until basic comparison framework is proven useful.

- [ ] **Statistical Significance Testing** — Defer: Need larger test sets first
- [ ] **Cross-Method Ensemble** — Defer: Research question is comparison, not combination
- [ ] **Video Annotation Tool** — Defer: Use external tools (CVAT, LabelImg) for ground truth creation
- [ ] **Export to Paper-Ready Figures** — Defer: Use existing tools (matplotlib export, Plotly) when publishing
- [ ] **Web-Based Multi-User Interface** — Defer: Single researcher using desktop Streamlit is sufficient

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Method Registry | HIGH | LOW | P1 |
| Test Video Catalog | HIGH | LOW | P1 |
| Method Isolation | HIGH | LOW | P1 |
| Result Persistence | HIGH | LOW | P1 |
| Basic Metrics | HIGH | LOW | P1 |
| Intermediate Output Capture | HIGH | MEDIUM | P1 |
| Side-by-Side Visualization | HIGH | MEDIUM | P1 |
| Method-Specific Visualizations | HIGH | MEDIUM | P1 |
| FSM State Timeline | MEDIUM | MEDIUM | P1 |
| Batch Processing UI | MEDIUM | LOW | P1 |
| Parallel Execution | MEDIUM | LOW | P2 |
| Speed Benchmarking | MEDIUM | LOW | P2 |
| Result Diffing | MEDIUM | MEDIUM | P2 |
| Compression Ratio Metrics | LOW | LOW | P2 |
| Configurable Ground Truth Tolerance | LOW | LOW | P2 |

**Priority key:**
- P1: Must have for v1.0 launch (framework foundation)
- P2: Should have for v1.x (enhanced comparison capabilities)
- P3: Nice to have for v2+ (advanced research features)

## Research vs Production Features

### Research Tool Priorities (This Project)

**What to build:**
- Flexibility over performance (swap methods easily, not optimize one)
- Transparency over polish (expose intermediate steps, not hide complexity)
- Comparison over deployment (visualize differences, not serve predictions)
- Iteration over stability (refactor freely, not maintain backwards compatibility)

**What NOT to build:**
- API endpoints, Docker containers, monitoring dashboards
- Authentication, authorization, multi-tenancy
- Database migrations, data backups, disaster recovery
- Automated testing for production edge cases
- Load balancing, caching layers, CDN integration

### Production System Concerns (Deferred)

From 2026 AI/ML research, the industry is moving from "build your own" to "integrate and deploy". For this research tool:

- Focus on proving which method works, not deploying it at scale
- Use file-based storage, not databases (easier to inspect, version control)
- Single-user desktop tool, not multi-user web service
- Manual parameter exploration, not automated tuning

When a method proves valuable, THEN productionize it separately with proper engineering.

## Comparison Framework Analysis

### Competitor Patterns (from research)

| Feature | MLflow | Neptune.ai | Detectron2 | Our Approach |
|---------|--------|------------|------------|--------------|
| Method Registry | Model registry with versioning | Experiment tracking with metadata | Modular architecture (backbone/neck/head) | Decorator-based plugin system (simpler) |
| Metrics | Automatic logging | Compare table with diff highlighting | Built-in evaluation metrics | Confusion matrix + domain metrics |
| Visualization | Basic plots | Interactive dashboards | TensorBoard integration | Streamlit with method-specific plugins |
| Parallel Execution | MLflow Projects | Distributed compute | Not built-in | pytest-xdist (standard Python testing) |
| Result Storage | Artifact store (S3, Azure) | Cloud-based metadata DB | File-based checkpoints | Local JSON/CSV (inspectable, versionable) |

### Key Insights

**What works for research tools:**
- File-based storage beats databases for inspectability and version control
- Method-specific visualizations matter more than universal dashboards
- Plugin architecture with minimal interfaces (over-abstraction kills flexibility)
- Standard testing tools (pytest) over custom test harness

**What to avoid:**
- Cloud dependencies (research should work offline)
- Complex deployment infrastructure (not needed for comparison)
- Universal abstractions that force incompatible methods into same mold
- Real-time processing before understanding what works

## Sources

### Computer Vision Frameworks
- [11 Computer Vision Algorithms You Should Know in 2026](https://maddevs.io/blog/computer-vision-algorithms-you-should-know/)
- [Ultralytics YOLO Performance Metrics](https://docs.ultralytics.com/guides/yolo-performance-metrics/)
- [Google Model Explorer: Graph visualization for large models](https://research.google/blog/model-explorer/)

### Benchmarking & Metrics
- [Object Detection: Key Metrics for Computer Vision Performance](https://labelyourdata.com/articles/object-detection-metrics)
- [Mean Average Precision (mAP) Explained](https://www.v7labs.com/blog/mean-average-precision)
- [CVAT: Precision, Recall, & Accuracy Annotation Quality Metrics](https://www.cvat.ai/resources/blog/precision-recall-accuracy-annotation-quality-metrics)

### ML Model Comparison Tools
- [Neptune.ai: Best Tools for Machine Learning Model Visualization](https://neptune.ai/blog/the-best-tools-for-machine-learning-model-visualization)
- [MLflow Model Registry](https://mlflow.org/docs/latest/ml/model-registry/)
- [Evidently: ML Model Monitoring Dashboard Tutorial](https://www.evidentlyai.com/blog/ml-model-monitoring-dashboard-tutorial)

### Python Testing & Plugin Systems
- [pytest-xdist: Running Tests in Parallel](https://www.statology.org/how-to-run-tests-parallel-pytest-xdist/)
- [Building a Plugin Architecture with Python (Medium)](https://mwax911.medium.com/building-a-plugin-architecture-with-python-7b4ab39ad4fc)
- [Python Registry Pattern: Clean Alternative to Factory Classes](https://dev.to/dentedlogic/stop-writing-giant-if-else-chains-master-the-python-registry-pattern-ldm)

### Research vs Production Insights
- [AI and Enterprise Technology Predictions 2026](https://solutionsreview.com/ai-and-enterprise-technology-predictions-from-industry-experts-for-2026/)
- [IBM: AI and Tech Trends 2026](https://www.ibm.com/think/news/ai-tech-trends-predictions-2026)

---
*Feature research for: Multi-Method Computer Vision Algorithm Comparison Framework (Tennis Rally Detection)*
*Researched: 2026-01-19*
