---
phase: 06
plan: 02
subsystem: frontend
status: complete
completed: 2026-01-21

tags: [react, vite, react-router, frontend, ui, api-client]

requires: [06-01]
provides: [react-dashboard, video-selection-ui, run-triggering-ui, results-page]
affects: [06-03]

tech-stack:
  added: [react, react-router-dom, vite]
  patterns: [component-architecture, api-service-layer, status-polling]

key-files:
  created:
    - frontend/src/services/api.js
    - frontend/src/pages/Home.jsx
    - frontend/src/pages/Results.jsx
    - frontend/src/components/VideoSelector.jsx
    - frontend/src/components/MethodSelector.jsx
    - frontend/src/components/RunTrigger.jsx
  modified: []

decisions:
  - slug: vite-react-setup
    title: Vite for React Build Tooling
    rationale: Fast dev server, excellent HMR, modern ESM-native approach
  - slug: vite-proxy-backend
    title: Vite Proxy for API Calls
    rationale: Avoids CORS issues in development, transparent to frontend code
  - slug: component-based-architecture
    title: Component-Based UI Architecture
    rationale: Separation of concerns, reusable components, maintainable codebase
  - slug: status-polling-2s
    title: 2-Second Status Polling Interval
    rationale: Balance between responsiveness and server load
  - slug: 4min-timeout
    title: 4-Minute Timeout for Run Processing
    rationale: Accommodates long test videos while preventing infinite polling

metrics:
  duration: 5min
  commits: 3
  files-created: 15
---

# Phase 6 Plan 02: React Dashboard Summary

**React dashboard with video selection dropdown, file upload, SpectralFlux method selector, run triggering with status polling, and results page displaying run metadata with placeholders for timeline/video player**

## What Was Built

Created a complete React frontend using Vite that provides a web UI for triggering segmentation runs and viewing results. The dashboard consists of:

1. **Home Page**: Video selection (dropdown + upload), method selection (hardcoded SpectralFlux), and run triggering with status polling
2. **Results Page**: Run metadata display with placeholders for Timeline and VideoPlayer components (to be built in Plan 06-03)
3. **API Service Layer**: Centralized API client with error handling for all backend communication
4. **Component Architecture**: Modular, reusable components (VideoSelector, MethodSelector, RunTrigger)

## Implementation Details

### Project Setup

- **Framework**: React 18 with Vite 7 for build tooling
- **Routing**: React Router v6 with BrowserRouter for client-side routing
- **Styling**: CSS modules with dark/light mode support via prefers-color-scheme
- **Proxy Configuration**: Vite dev server proxies /api requests to backend (localhost:3000)

### API Service Layer

Created `frontend/src/services/api.js` with centralized error handling:

- **fetchVideos()**: GET /api/videos - Lists test videos from TestResources
- **uploadVideo(file)**: POST /api/videos/upload - Uploads video via FormData
- **createRun()**: POST /api/runs - Creates new segmentation run
- **getRun(runId)**: GET /api/runs/:id - Fetches run status and details
- **checkHealth()**: GET /api/health - Backend/Runner health check

All functions use custom APIError class for consistent error handling with HTTP status codes.

### Home Page Components

**VideoSelector Component**:
- Dropdown populated from fetchVideos() showing test video filenames
- File upload input accepting .mp4, .mov, .m4v files
- Upload button with loading state during upload
- Success feedback showing uploaded filename
- Error display for failed operations
- Emits onChange(videoPath) when video selected

**MethodSelector Component**:
- Hardcoded to "SpectralFlux" for Phase 6
- Displays method description: "Audio + Visual Validation"
- Note indicating additional methods coming in Phase 7
- Emits onChange(method) on mount with "SpectralFlux"

**RunTrigger Component**:
- "Process Video" button (disabled until video selected)
- Loading spinner with status text during execution
- Error display on failure
- Hint text when no video selected

**Home Page Integration**:
- Manages state for selectedVideo, selectedMethod, isProcessing, error
- Calls createRun() with sport="tennis", sportMode="shot"
- Polls getRun() every 2 seconds until status is completed or failed
- 4-minute timeout for long-running videos (120 attempts × 2 seconds)
- Auto-navigates to /results/:runId on completion

### Results Page

**Features**:
- Fetches run details using useParams() to get runId from URL
- Loading spinner while fetching run data
- Error handling for failed requests and missing runs
- Displays comprehensive run metadata:
  - Run ID, video filename, method, sport/mode, status
  - Segment count
  - Created and completed timestamps
- Status-based styling (green for completed, red for failed, yellow for running, blue for queued)
- Placeholder sections for Timeline and VideoPlayer with clear messaging about Plan 06-03
- Responsive grid layout for metadata
- Dark/light mode support

### Styling

All components include dedicated CSS files with:
- Dark mode by default (#1a1a1a background, #fff text)
- Light mode support via @media (prefers-color-scheme: light)
- Consistent spacing, borders, and visual hierarchy
- Loading states, error states, and success states with appropriate colors
- Responsive layouts with flexbox and grid

## Testing Results

Build verified successfully with no errors:
- Task 1: 44 modules transformed, 228.87 kB bundle size
- Task 2: 52 modules transformed, 233.46 kB bundle size
- Task 3: 53 modules transformed, 236.71 kB bundle size

All files compile without errors. Manual verification of dev server requires user to start backend and frontend (noted in verification section).

## Deviations from Plan

None - plan executed exactly as written. All three tasks completed in sequence:
1. Initialize React app with Vite
2. Create video selection and run triggering UI
3. Create Results page placeholder

## Decisions Made

| Decision | Options | Choice | Rationale |
|----------|---------|--------|-----------|
| Build tool | Create React App, Vite, Next.js | Vite | Fast dev server, excellent HMR, modern ESM-native |
| CSS approach | CSS-in-JS, Tailwind, plain CSS | Plain CSS with modules | Simple, no additional dependencies, good for Phase 6 scope |
| Polling interval | 1s, 2s, 5s | 2 seconds | Balance between responsiveness and server load |
| Timeout duration | 2min, 4min, 10min | 4 minutes | Accommodates long test videos without infinite polling |
| Error handling | Per-component, global, service layer | Service layer | Centralized, consistent error messages |

## Files Created/Modified

### Created (15 files)

**Frontend infrastructure:**
- `frontend/package.json` - React, React Router, Vite dependencies
- `frontend/vite.config.js` - Vite configuration with /api proxy
- `frontend/index.html` - Root HTML template
- `frontend/src/main.jsx` - React app entry point
- `frontend/src/App.jsx` - App root with BrowserRouter and routes

**Styling:**
- `frontend/src/index.css` - Global styles with dark/light mode
- `frontend/src/App.css` - App layout styles (header, main)

**API service:**
- `frontend/src/services/api.js` - API client with error handling (97 lines)

**Components:**
- `frontend/src/components/VideoSelector.jsx` - Video dropdown and upload (103 lines)
- `frontend/src/components/VideoSelector.css` - VideoSelector styles
- `frontend/src/components/MethodSelector.jsx` - Method display (24 lines)
- `frontend/src/components/MethodSelector.css` - MethodSelector styles
- `frontend/src/components/RunTrigger.jsx` - Process button and status (42 lines)
- `frontend/src/components/RunTrigger.css` - RunTrigger styles

**Pages:**
- `frontend/src/pages/Home.jsx` - Home page with component integration (99 lines)
- `frontend/src/pages/Home.css` - Home page layout
- `frontend/src/pages/Results.jsx` - Results page with run metadata (143 lines)
- `frontend/src/pages/Results.css` - Results page styles with placeholders

## Next Phase Readiness

**Blockers:** None

**Ready for Phase 6 Plan 03 (Timeline & Video Player):**
- React app structure established with routing
- Results page has placeholder divs for Timeline and VideoPlayer components
- API service layer ready for fetching run segments
- Component architecture supports adding new components
- Styling system consistent and extensible

**Integration notes:**
- Timeline component should be added to Results page in .timeline-section
- VideoPlayer component should be added to Results page in .video-section
- Both components will receive run.segments data from Results page state
- run.segments contains array of ExportedSegment objects with startTime, endTime, type

**Manual verification required:**
User should verify the dashboard works end-to-end:
1. Start backend: `cd backend && node server.js`
2. Start iOS Runner in simulator
3. Start frontend: `cd frontend && npm run dev`
4. Open http://localhost:5173
5. Select video, trigger run, verify auto-navigation to results page

## Lessons Learned

1. **Vite proxy configuration**: Simple one-liner in vite.config.js eliminates CORS issues in development
2. **Status polling pattern**: While loop with 2-second intervals works well for run monitoring
3. **Component separation**: VideoSelector, MethodSelector, RunTrigger as separate components keeps Home page clean
4. **Error handling in API layer**: Centralized error handling with custom APIError class provides consistent UX
5. **Dark/light mode support**: CSS prefers-color-scheme media query handles OS-level theme preference automatically
6. **Placeholder approach**: Dashed-border boxes with clear messaging set expectations for future work

---

**Phase:** 06-dashboard-backend-&-web-core
**Plan:** 02
**Status:** Complete
**Duration:** 5 minutes
**Commits:** 0743d14, 20e3dfb, 85c02f9
