# SportCrunchRunner HTTP API

## Overview

SportCrunchRunner provides an HTTP API for triggering video segmentation runs. The API uses a method-based discovery pattern that scans the filesystem for available methods.

**Base URL:** `http://localhost:8080` (when running in simulator)

---

## Endpoints

### Health Check

**GET** `/health`

Returns server health status.

**Response:**
```
200 OK
Body: "OK"
```

---

### Method Discovery

**GET** `/methods`

List all available methods by scanning the `app/methods/` directory.

**Response:**
```json
[
  {
    "family": "spectral_flux",
    "version": "v1",
    "displayName": "Spectral Flux",
    "description": "Audio-based detection using spectral flux analysis",
    "configs": [
      {
        "name": "TennisRally",
        "displayName": "Tennis Rally",
        "description": "Groups consecutive shots into rallies"
      },
      {
        "name": "TennisIndividual",
        "displayName": "Tennis Individual",
        "description": "Captures each shot separately"
      }
    ]
  }
]
```

**Method Discovery Logic:**
- Scans `app/methods/` for method family directories (e.g., `spectral_flux/`)
- Scans `app/methods/<family>/configs/` for config files (e.g., `SpectralFluxTennisRally.swift`)
- Extracts config name by removing method family prefix from filename
- Returns structured JSON with method families and their available configs

---

### Run Management

**POST** `/runs`

Create a new segmentation run.

**Request Body:**
```json
{
  "videoPath": "/path/to/video.mp4",
  "method": "spectral_flux",
  "config": "TennisRally",
  "deviceTarget": "simulator"
}
```

**Parameters:**
- `videoPath` (required) - Absolute path to video file
- `method` (required) - Method family name (from `/methods`)
- `config` (required) - Config name (from `/methods` configs array)
- `deviceTarget` (required) - Target device ("simulator" or "device")

**Response:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "queued"
}
```

---

**GET** `/runs/:runId`

Get status and results for a run.

**Parameters:**
- `runId` (path) - Run UUID

**Response (queued/running):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "running",
  "videoPath": "/path/to/video.mp4",
  "method": "spectral_flux",
  "config": "TennisRally",
  "createdAt": "2026-01-25T12:00:00Z",
  "startedAt": "2026-01-25T12:00:05Z"
}
```

**Response (completed):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "completed",
  "videoPath": "/path/to/video.mp4",
  "method": "spectral_flux",
  "config": "TennisRally",
  "createdAt": "2026-01-25T12:00:00Z",
  "startedAt": "2026-01-25T12:00:05Z",
  "completedAt": "2026-01-25T12:00:45Z",
  "segments": [
    {
      "startTime": 5.2,
      "endTime": 12.8,
      "type": "segment"
    },
    {
      "startTime": 18.5,
      "endTime": 25.1,
      "type": "segment"
    }
  ],
  "artifactPaths": {
    "segmentsJSON": "/path/to/segments.json",
    "highlightVideo": null
  }
}
```

**Response (failed):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "failed",
  "videoPath": "/path/to/video.mp4",
  "method": "spectral_flux",
  "config": "TennisRally",
  "createdAt": "2026-01-25T12:00:00Z",
  "startedAt": "2026-01-25T12:00:05Z",
  "completedAt": "2026-01-25T12:00:10Z",
  "error": "Video file not found: /path/to/video.mp4"
}
```

---

**GET** `/runs`

List all runs.

**Response:**
```json
{
  "runs": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "status": "completed",
      "method": "spectral_flux",
      "config": "TennisRally",
      "createdAt": "2026-01-25T12:00:00Z"
    }
  ]
}
```

---

## Example Workflows

### Discover available methods

```bash
# Get all methods and configs
curl http://localhost:8080/methods | jq

# Result: spectral_flux has TennisRally + TennisIndividual configs
```

### Create and monitor a run

```bash
# Create run
curl -X POST http://localhost:8080/runs \
  -H "Content-Type: application/json" \
  -d '{
    "videoPath": "/path/to/tennis.mp4",
    "method": "spectral_flux",
    "config": "TennisRally",
    "deviceTarget": "simulator"
  }' | jq

# Get run ID from response
RUN_ID="550e8400-e29b-41d4-a716-446655440000"

# Poll for completion
while true; do
  STATUS=$(curl -s http://localhost:8080/runs/$RUN_ID | jq -r '.status')
  echo "Status: $STATUS"
  if [ "$STATUS" = "completed" ] || [ "$STATUS" = "failed" ]; then
    break
  fi
  sleep 2
done

# Get final results
curl http://localhost:8080/runs/$RUN_ID | jq
```

---

## Adding New Methods

To add a new method that will be discovered by the API:

1. Create method family directory: `app/methods/<method_family>/`
2. Implement method class: `<MethodFamily>Method.swift`
3. Implement config struct: `<MethodFamily>MethodConfig.swift`
4. Create config instances in `configs/` subdirectory:
   - Example: `configs/<MethodFamily><ConfigName>.swift`
   - Must define static `instance` property of config type
5. Update `RunExecutor.instantiateMethod()` to handle new method family
6. Restart SportCrunchRunner - new method will appear in `/methods` endpoint
