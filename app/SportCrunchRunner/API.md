# SportCrunchRunner HTTP API

## Overview

SportCrunchRunner provides an HTTP API for triggering video segmentation runs. The API uses a sport + mode discovery pattern instead of method family/version.

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

### Sport Discovery

**GET** `/sports`

List all available sports and their modes.

**Response:**
```json
[
  {
    "id": "tennis",
    "displayName": "Tennis",
    "description": "Detects racket-ball impacts",
    "modes": [
      {
        "id": "rally",
        "displayName": "Rally Mode",
        "description": "Groups consecutive shots into rallies"
      },
      {
        "id": "individual",
        "displayName": "Shot Mode",
        "description": "Captures each shot separately"
      }
    ]
  },
  {
    "id": "cricket",
    "displayName": "Cricket",
    "description": "Detects bat-ball contacts",
    "modes": []
  }
]
```

---

**GET** `/sports/:sport`

Get details for a specific sport.

**Parameters:**
- `sport` (path) - Sport ID (e.g., "tennis", "cricket")

**Response:**
```json
{
  "id": "tennis",
  "displayName": "Tennis",
  "description": "Detects racket-ball impacts",
  "modes": [
    {
      "id": "rally",
      "displayName": "Rally Mode",
      "description": "Groups consecutive shots into rallies"
    },
    {
      "id": "individual",
      "displayName": "Shot Mode",
      "description": "Captures each shot separately"
    }
  ]
}
```

**Errors:**
- `400 Bad Request` - Invalid sport ID

---

### Run Management

**POST** `/runs`

Create a new segmentation run.

**Request Body:**
```json
{
  "videoPath": "/path/to/video.mp4",
  "sport": "tennis",
  "sportMode": "rally",
  "deviceTarget": "simulator"
}
```

**Parameters:**
- `videoPath` (required) - Absolute path to video file
- `sport` (required) - Sport ID (from `/sports`)
- `sportMode` (optional) - Mode ID (from `/sports/:sport/modes`)
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
  "sport": "tennis",
  "sportMode": "rally",
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
  "sport": "tennis",
  "sportMode": "rally",
  "createdAt": "2026-01-25T12:00:00Z",
  "startedAt": "2026-01-25T12:00:05Z",
  "completedAt": "2026-01-25T12:00:45Z",
  "segments": [
    {
      "startTime": 5.2,
      "endTime": 12.8,
      "type": "rally"
    },
    {
      "startTime": 18.5,
      "endTime": 25.1,
      "type": "rally"
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
  "sport": "tennis",
  "sportMode": "rally",
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
      "sport": "tennis",
      "sportMode": "rally",
      "createdAt": "2026-01-25T12:00:00Z"
    }
  ]
}
```

---

## Migration from Legacy API

If you were using the old method registry API:

**OLD:**
```bash
GET /methods
GET /methods/spectral_flux/v2
POST /runs { "method": "spectral_flux", ... }
```

**NEW:**
```bash
GET /sports
GET /sports/tennis
POST /runs { "sport": "tennis", "sportMode": "rally", ... }
```

**Key changes:**
1. Discovery is now sport-based, not method-based
2. Use `sport` + `sportMode` instead of `method`/`methodFamily`/`methodVersion`
3. No more method config parameters - configs are predetermined per sport/mode

---

## Example Workflows

### Discover available options

```bash
# Get all sports and modes
curl http://localhost:8080/sports | jq

# Result: tennis has rally + individual modes
```

### Create and monitor a run

```bash
# Create run
curl -X POST http://localhost:8080/runs \
  -H "Content-Type: application/json" \
  -d '{
    "videoPath": "/path/to/tennis.mp4",
    "sport": "tennis",
    "sportMode": "rally",
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
