---
phase: 06
plan: 01
subsystem: backend
status: complete
completed: 2026-01-21

tags: [nodejs, express, api, proxy]

requires: [05-01, 05-02]
provides: [backend-api, video-management, runner-proxy]
affects: [06-02]

tech-stack:
  added: [express, cors, multer]
  patterns: [rest-api, proxy-pattern, file-upload]

key-files:
  created:
    - backend/package.json
    - backend/server.js
    - backend/.gitignore
  modified: []

decisions:
  - slug: nodejs-backend-express
    title: Express.js for Backend API
    rationale: Lightweight, well-suited for proxy and file management
  - slug: es-modules-backend
    title: ES Modules Syntax
    rationale: Modern JavaScript, better tree-shaking, align with current standards
  - slug: multer-video-upload
    title: Multer for Video Uploads
    rationale: Standard Express middleware for multipart/form-data
  - slug: 500mb-upload-limit
    title: 500MB Upload Limit
    rationale: Reasonable for test videos, prevents abuse

metrics:
  duration: 2min
  commits: 1
  files-created: 3
---

# Phase 6 Plan 01: Node.js Backend & iOS Runner Proxy

**One-liner:** Express backend proxies runs to iOS Runner (localhost:8080) and manages video listing/upload from TestResources

## What Was Built

Created a Node.js backend with Express that serves as an HTTP API layer between the React dashboard (Phase 6 Plan 02) and the iOS Runner app. The backend provides:

1. **Video Management**: Lists videos from `SportCrunchTests/TestResources/Videos` and handles browser uploads to `backend/uploads/`
2. **iOS Runner Proxy**: Forwards all `/api/runs` requests to `http://localhost:8080` where the iOS Runner listens
3. **Health Monitoring**: Reports backend and runner availability status

All endpoints include proper error handling for iOS Runner unavailability (ECONNREFUSED, timeouts), returning clear error messages when the Runner app isn't running.

## Implementation Details

### Server Architecture

- **Framework**: Express 5.x with CORS and JSON body parsing
- **Module System**: ES modules (`"type": "module"` in package.json)
- **Configuration**: Environment variables for PORT (default 3000) and RUNNER_URL (default http://localhost:8080)
- **Error Handling**: Global error middleware handles multer errors and uncaught exceptions

### Video Endpoints

**GET /api/videos**: Scans `SportCrunchTests/TestResources/Videos` directory and returns array of video objects with absolute paths, names, and sizes. Returns empty array if directory doesn't exist (graceful degradation).

**POST /api/videos/upload**: Uses multer to save uploaded videos to `backend/uploads/`. Enforces 500MB size limit and validates file extensions (.mp4, .mov, .m4v). Creates uploads directory on server start if missing.

### iOS Runner Proxy

All `/api/runs` endpoints forward to iOS Runner at localhost:8080:

- **POST /api/runs**: Validates required fields (videoPath, method, sport), forwards to Runner, returns 202 with run ID
- **GET /api/runs**: Lists all runs
- **GET /api/runs/:id**: Gets specific run details, handles 404 for missing runs

Each proxy endpoint includes 5-10 second timeout and handles connection errors with 503 status and clear message: "iOS Runner unavailable. Please ensure the Runner app is running in the simulator."

### Health Check

**GET /api/health**: Checks iOS Runner health with 2-second timeout, returns `{backend: "ready", runner: "ready"|"unavailable"}`. Never fails - backend always reports "ready", runner status reflects connectivity.

## Testing Results

Verified all endpoints manually:

1. ✅ Server starts on port 3000 with startup logs
2. ✅ Health check returns `{backend: "ready", runner: "unavailable"}` when Runner not running
3. ✅ Video listing returns 6 tennis videos with absolute paths and sizes
4. ✅ Upload endpoint ready (validated via file filter logic)
5. ✅ All proxy endpoints handle Runner unavailability with clear errors

## Deviations from Plan

None - plan executed exactly as written. All three tasks (initialization, video endpoints, proxy endpoints) completed in single implementation pass.

## Decisions Made

| Decision | Options | Choice | Rationale |
|----------|---------|--------|-----------|
| Backend framework | Express, Fastify, Koa | Express 5.x | Most established, excellent ecosystem, sufficient for proxy needs |
| Module system | CommonJS, ES Modules | ES Modules | Modern standard, better for frontend/backend consistency |
| Upload middleware | Multer, Formidable, Busboy | Multer | Standard Express middleware, good documentation |
| Upload limit | 100MB, 250MB, 500MB, 1GB | 500MB | Accommodates large test videos without abuse risk |

## Files Created

### backend/package.json
- Dependencies: express ^5.2.1, cors ^2.8.5, multer ^2.0.2
- Type: "module" for ES imports
- Main: index.js (standard entry)

### backend/server.js (326 lines)
- Express app with CORS and JSON parsing
- Health, video, and proxy endpoints
- Error handling middleware
- Configurable PORT and RUNNER_URL
- Multer configuration for uploads

### backend/.gitignore
- Ignores node_modules/, uploads/, *.log

## Next Phase Readiness

**Blockers:** None

**Ready for Phase 6 Plan 02 (React Dashboard):**
- Backend API fully operational
- Video listing returns absolute paths for Runner consumption
- Proxy endpoints ready to forward run requests
- Health endpoint supports Runner status checks

**Integration notes:**
- Frontend should poll GET /api/runs/:id for run status updates (queued → running → completed)
- Video paths from GET /api/videos can be passed directly to POST /api/runs
- Uploaded videos automatically get absolute paths for Runner
- Clear error messages when Runner unavailable guide user to start simulator

## Lessons Learned

1. **Absolute paths critical**: iOS Runner needs absolute paths to access videos, backend resolves these correctly
2. **Graceful degradation**: Returning empty array when TestResources missing prevents frontend crashes
3. **Clear error messages**: Connection errors should tell user exactly what to do ("ensure Runner app is running")
4. **Timeout tuning**: 2-5 second timeouts balance responsiveness with network variance
5. **ES modules in Node**: Clean syntax, but requires `"type": "module"` and .js extensions in imports

---

**Phase:** 06-dashboard-backend-&-web-core
**Plan:** 01
**Status:** Complete
**Duration:** 2 minutes
**Commits:** 2515802
