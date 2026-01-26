# Context-Aware Modules Design: ROI & Activity Recognition

> **Date:** 2026-01-26
> **Status:** Draft
> **Focus:** Automated ROI Generation and Heuristic Activity Recognition

## 1. Overview
This design outlines the "Context Layer" of the computer vision pipeline. It addresses two critical requirements:
1.  **Performance:** Reducing pixel processing load via **Automated ROI** (Region of Interest).
2.  **Semantics:** Distinguishing "Active Play" from background noise using **Heuristic Activity Recognition**.

These modules are designed to operate independently of the core ball-tracking method, exposing services that can be orchestrated by a higher-level coordinator later.

---

## 2. Automated ROI (Reactive Segmentation)

**Goal:** Automatically identify the active court area to minimize processing area, robust to minor camera shakes and major shifts.

### 2.1 Strategy: Padded ROI with Shift Triggers
Instead of a single static ROI or a continuously expensive update, we use a **Reactive Segmentation** approach:
*   **Initialization:** Analyze a chunk of video to find the "hot" zone (court).
*   **Padding:** Add a 15% safety margin to absorb minor vibrations (wind, tripod sag).
*   **Monitoring:** Periodically check for major camera shifts (pans, bumps).

### 2.2 Components

#### `MotionHeatmapGenerator`
*   **Responsibility:** Consumes a sequence of sample frames to produce a bounding box.
*   **Algorithm:**
    1.  **Sampling:** Selects frames at intervals (e.g., every 30s) within a target time range.
    2.  **Difference Accumulation:** Computes `|Frame_t - Frame_{t-1}|` and adds to a `Float32` accumulator.
    3.  **Normalization:** Scales accumulator to 0-255.
    4.  **Thresholding:** Applies `Mean + 2*StdDev` to isolate high-traffic areas.
    5.  **Bounding Box:** Finds the largest contour and expands it by **15%** (clamped to image bounds).

#### `ShiftDetector`
*   **Responsibility:** Detects if the camera has moved significantly since the ROI was generated.
*   **Mechanism:**
    *   **Anchor:** Stores a small $64 \times 64$ patch from the *start* of the segment (e.g., a high-contrast corner).
    *   **Check:** Every ~150 frames (5s), compares the current frame's patch to the anchor using Mean Squared Error (MSE).
    *   **Trigger:** If `MSE > Threshold`, returns `true` (Shift Detected).

#### `ROIManager`
*   **Responsibility:** Orchestrates the lifecycle of the ROI.
*   **Logic:**
    *   Maintains the `currentROI`.
    *   On `ShiftDetected` signal, invalidates `currentROI` and triggers `MotionHeatmapGenerator` for the *next* time segment.

---

## 3. Activity Recognition (Lazy Anchor Strategy)

**Goal:** Distinguish active play (rallies) from background motion (walking) using low-cost heuristics, triggered only on demand.

### 3.1 Strategy: The "Motion Hijack"
To avoid running expensive Neural Networks on every frame, we use a hybrid approach:
*   **Anchor Frames:** Run YOLOv8 Nano once every ~1 second to find ground-truth player positions.
*   **Motion Hijacking:** In intermediate frames, use the cheap **Motion Mask** (from the ball detector) to track the *centroid* of the player's movement.
*   **Heuristics:** Analyze the acceleration and "jerk" of this hybrid trajectory to calculate an "Energy Score."

### 3.2 Components

#### `YOLODetectorProtocol`
*   **Responsibility:** Abstract interface for the object detector.
*   **Method:** `detectPlayers(in frame: CGImage) -> [CGRect]`
*   **Note:** Implementation will eventually wrap CoreML YOLOv8 Nano. For now, we use a Mock.

#### `PlayerTracker` (The "Hijacker")
*   **Responsibility:** Fills the gaps between YOLO detections.
*   **Input:**
    *   `lastKnownPositions`: `[CGRect]` (from YOLO).
    *   `motionMask`: `vImage_Buffer` (binary mask of pixel changes).
*   **Logic:**
    1.  For each `lastKnownPosition`, search the `motionMask` for the largest connected component (blob) nearby.
    2.  If found, update the player's position to the blob's **Centroid**.
    3.  If not found (player standing still), keep position static.
    4.  Output: A sequence of `Point` (centroids) for each player.

#### `HeuristicAnalyzer`
*   **Responsibility:** computes the "Active Play" score.
*   **Metrics:**
    *   **Velocity:** $V_t = P_t - P_{t-1}$
    *   **Acceleration:** $A_t = V_t - V_{t-1}$
    *   **Jerk:** $J_t = A_t - A_{t-1}$
    *   **Energy Score:** $\sum (|A_t| + w \cdot |J_t|)$
*   **Aggregation:** `SceneEnergy = max(Player1_Energy, Player2_Energy, ...)`
    *   *Rationale:* If *any* player is moving explosively, the ball is likely in play.

#### `ActivityService`
*   **Responsibility:** The public facade.
*   **Method:** `validateActivity(at time: TimeInterval, window: TimeInterval) async -> Bool`
*   **Workflow:**
    1.  Identifies "Anchor Frame" near `time`.
    2.  Calls `YOLODetector`.
    3.  Iterates frames in `window`.
    4.  Calls `PlayerTracker` using motion masks.
    5.  Calls `HeuristicAnalyzer` on resulting trajectories.
    6.  Returns `true` if `SceneEnergy > Threshold`.

---

## 4. Implementation Plan

### Phase 1: ROI Module
1.  **`MotionHeatmapGenerator.swift`:** Implement accumulation and thresholding logic using Accelerate.
2.  **`ShiftDetector.swift`:** Implement MSE patch comparison.
3.  **`ROIManager.swift`:** Implement the state machine (Valid -> Shifted -> Recalculating).
4.  **Tests:** Synthetic video tests for robust ROI expansion.

### Phase 2: Activity Module
1.  **`YOLODetectorProtocol.swift`:** Define protocol and a `MockYOLODetector` (returns static boxes).
2.  **`PlayerTracker.swift`:** Implement blob-centroid tracking on `vImage` buffers.
3.  **`HeuristicAnalyzer.swift`:** Implement the physics math (Accel/Jerk).
4.  **`ActivityService.swift`:** Wire the components.
5.  **Tests:** "Mock Blob" tests to verify Energy Score thresholds (Walking vs. Sprinting).

### Phase 3: Integration (Future)
*   *Out of scope for this document.*
*   Will involve connecting `HoughMethod` to `ROIManager` (for cropping) and `ActivityService` (for validation).
