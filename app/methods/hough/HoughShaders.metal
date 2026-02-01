//
//  HoughShaders.metal
//  SportCrunch
//
//  GPU-accelerated Hough line detection for motion streak analysis.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Shared Structures

/// Motion point passed from CPU
struct MotionPointGPU {
    float x;
    float y;
};

/// Detected line passed back to CPU
struct DetectedLineGPU {
    float rho;      // Distance from origin to line
    float theta;    // Angle of normal to line (radians)
    uint votes;     // Number of votes in accumulator
};

/// Hough transform parameters
struct HoughParams {
    float rhoStep;      // Resolution in rho (pixels)
    float thetaStep;    // Resolution in theta (radians)
    int numRhoSteps;    // Number of rho bins
    int numThetaSteps;  // Number of theta bins (typically 180)
    float maxRho;       // Maximum rho value (diagonal of image)
    int voteThreshold;  // Minimum votes to consider a line
};

// MARK: - Hough Voting Kernel

/// Each thread processes one motion point and votes for all possible lines through it.
/// Uses atomic operations to increment the accumulator.
kernel void houghVoteKernel(
    device const MotionPointGPU* points [[buffer(0)]],
    device atomic_uint* accumulator [[buffer(1)]],
    constant HoughParams& params [[buffer(2)]],
    constant uint& pointCount [[buffer(3)]],
    uint tid [[thread_position_in_grid]]
) {
    if (tid >= pointCount) return;

    float x = points[tid].x;
    float y = points[tid].y;

    // Vote for all theta values
    for (int thetaIdx = 0; thetaIdx < params.numThetaSteps; thetaIdx++) {
        float theta = float(thetaIdx) * params.thetaStep;

        // rho = x * cos(theta) + y * sin(theta)
        float rho = x * cos(theta) + y * sin(theta);

        // Convert to bin index (rho ranges from -maxRho to +maxRho)
        int rhoIdx = int((rho + params.maxRho) / params.rhoStep);

        if (rhoIdx >= 0 && rhoIdx < params.numRhoSteps) {
            int accumIdx = thetaIdx * params.numRhoSteps + rhoIdx;
            atomic_fetch_add_explicit(&accumulator[accumIdx], 1, memory_order_relaxed);
        }
    }
}

// MARK: - Peak Detection Kernel

/// Each thread checks one cell in the accumulator for local maximum.
/// Non-maximum suppression: only keep if greater than all 8 neighbors.
kernel void houghPeakKernel(
    device const atomic_uint* accumulator [[buffer(0)]],
    device DetectedLineGPU* peaks [[buffer(1)]],
    device atomic_uint* peakCount [[buffer(2)]],
    constant HoughParams& params [[buffer(3)]],
    constant uint& maxPeaks [[buffer(4)]],
    uint2 tid [[thread_position_in_grid]]
) {
    int thetaIdx = int(tid.x);
    int rhoIdx = int(tid.y);

    if (thetaIdx >= params.numThetaSteps || rhoIdx >= params.numRhoSteps) return;

    int idx = thetaIdx * params.numRhoSteps + rhoIdx;
    uint votes = atomic_load_explicit(&accumulator[idx], memory_order_relaxed);

    // Skip if below threshold
    if (votes < uint(params.voteThreshold)) return;

    // Non-maximum suppression: check 8 neighbors
    bool isLocalMax = true;
    for (int dt = -1; dt <= 1 && isLocalMax; dt++) {
        for (int dr = -1; dr <= 1 && isLocalMax; dr++) {
            if (dt == 0 && dr == 0) continue;

            int nt = thetaIdx + dt;
            int nr = rhoIdx + dr;

            // Handle theta wraparound (circular)
            if (nt < 0) nt += params.numThetaSteps;
            if (nt >= params.numThetaSteps) nt -= params.numThetaSteps;

            if (nr >= 0 && nr < params.numRhoSteps) {
                int neighborIdx = nt * params.numRhoSteps + nr;
                uint neighborVotes = atomic_load_explicit(&accumulator[neighborIdx], memory_order_relaxed);
                if (neighborVotes >= votes) {
                    isLocalMax = false;
                }
            }
        }
    }

    if (isLocalMax) {
        // Atomically claim a slot in the output array
        uint peakIdx = atomic_fetch_add_explicit(peakCount, 1, memory_order_relaxed);
        if (peakIdx < maxPeaks) {
            float theta = float(thetaIdx) * params.thetaStep;
            float rho = float(rhoIdx) * params.rhoStep - params.maxRho;

            peaks[peakIdx].rho = rho;
            peaks[peakIdx].theta = theta;
            peaks[peakIdx].votes = votes;
        }
    }
}

// MARK: - Accumulator Clear Kernel

/// Fast parallel clear of the accumulator between frames.
kernel void houghClearKernel(
    device atomic_uint* accumulator [[buffer(0)]],
    constant uint& size [[buffer(1)]],
    uint tid [[thread_position_in_grid]]
) {
    if (tid < size) {
        atomic_store_explicit(&accumulator[tid], 0, memory_order_relaxed);
    }
}
