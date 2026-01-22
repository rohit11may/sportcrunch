---
phase: 07
plan: 04
subsystem: dashboard
tags: [dashboard, method-selection, ui, backend-api, localStorage]
dependencies:
  requires: [07-03]
  provides: [method-selection-ui, dashboard-method-api]
  affects: [08-comparison, 09-visualization]
tech-stack:
  added: []
  patterns: [localStorage-persistence, dynamic-forms, api-driven-ui]
key-files:
  created:
    - dashboard/backend/server.js (GET /api/methods endpoints)
    - dashboard/frontend/src/components/MethodSelector.jsx (dynamic component)
  modified:
    - dashboard/backend/server.js
    - dashboard/frontend/src/components/MethodSelector.jsx
    - dashboard/frontend/src/components/MethodSelector.css
    - dashboard/frontend/src/components/RunTrigger.jsx
    - dashboard/frontend/src/components/RunTrigger.css
    - dashboard/frontend/src/pages/Home.jsx
decisions:
  - id: method-selection-api
    what: Backend reads methods from app/methods/ directory via filesystem
    why: Dashboard is read-only, no method editing needed
    impact: Simple, direct access to method registry
  - id: method-flattening
    what: Flatten hierarchical methods into flat array in API response
    why: Easier frontend consumption, simpler selection UI
    impact: Frontend doesn't need to traverse family/version hierarchy
  - id: localStorage-persistence
    what: Persist last-used method selection in localStorage
    why: Better UX, remembers user's preference across sessions
    impact: Key "sportcrunch_method_selection" stores methodId and configName
  - id: method-object-passing
    what: Pass full method object {family, version, config, name} instead of string
    why: Runner needs family/version/config for registry lookup
    impact: More structured data flow, supports dynamic method loading
metrics:
  duration: 3 min
  completed: 2026-01-22
---

# Phase 07 Plan 04: Dashboard Method Selection UI Summary

**One-liner:** Dynamic method selection UI reading from app/methods/ registry with localStorage persistence and config variant support

## What Was Built

Implemented dashboard method selection UI that dynamically loads available methods from the filesystem registry and allows users to select method family, version, and configuration for each run.

### Components

**1. Backend Method API (server.js)**
- `GET /api/methods` - Returns flattened list of all methods from `_index.json`
- `GET /api/methods/:family/:version/configs/:config` - Returns specific config JSON
- Reads directly from `app/methods/` directory (read-only)
- Graceful handling if `_index.json` doesn't exist (returns empty arrays)

**2. Dynamic MethodSelector Component**
- Fetches methods from `/api/methods` on mount
- Displays dropdown of all available methods (e.g., "SpectralFlux", "SpectralFluxVisualValidation")
- Shows method description below dropdown
- Displays config selector when method has multiple configs
- Hides config selector for single-config methods (shows static indicator)
- Persists selection to localStorage with key `sportcrunch_method_selection`
- Restores last selection on page load
- Loading, error, and empty states

**3. Run Trigger Integration**
- Home page passes method selection object to RunTrigger
- RunTrigger displays selected method name ("Using: SpectralFlux")
- Backend forwards `methodFamily`, `methodVersion`, and `config` to Runner
- Defaults to `v2` for backwards compatibility if not specified

## Data Flow

```
User selects method → MethodSelector onChange → Home.handleMethodChange
                                               ↓
                                     localStorage.setItem
                                               ↓
                     methodSelection = { family, version, config, name }
                                               ↓
                     RunTrigger displays method.name
                                               ↓
                     createRun(family, version, config)
                                               ↓
                     POST /api/runs { method: family, methodVersion, config }
                                               ↓
                     Backend → Runner /runs endpoint
                                               ↓
                     RunExecutor uses MethodRegistry.createMethod(family, version)
```

## API Response Format

### GET /api/methods

```json
{
  "families": [
    {
      "family": "spectral_flux",
      "description": "...",
      "versions": [...]
    }
  ],
  "methods": [
    {
      "id": "spectral_flux/v1",
      "family": "spectral_flux",
      "version": "v1",
      "name": "SpectralFlux",
      "description": "Pure audio spectral flux onset detection...",
      "defaultConfig": "default.config.json",
      "configs": ["aggressive.config.json", "conservative.config.json", "default-v1.config.json"]
    },
    {
      "id": "spectral_flux/v2",
      "family": "spectral_flux",
      "version": "v2",
      "name": "SpectralFluxVisualValidation",
      "description": "Audio spectral flux onset detection enhanced with...",
      "defaultConfig": "default.config.json",
      "configs": ["default-v2.config.json", "tennis-individual.config.json", "tennis-rally.config.json"]
    }
  ]
}
```

## UI Behavior

**Method Selection:**
- Dropdown populated from API response
- Shows human-readable names ("SpectralFlux", not "spectral_flux/v1")
- Description appears below selection
- Config dropdown appears only when method has > 1 config

**Config Selection:**
- Displays config filenames without `.config.json` extension
- Defaults to method's `defaultConfig`
- Changes reset to default when switching methods

**Persistence:**
- Selection saved to localStorage on change
- Restored on page load
- Key: `sportcrunch_method_selection`
- Value: `{ methodId: "spectral_flux/v1", configName: "aggressive.config.json" }`

## Files Modified

### Backend
- `dashboard/backend/server.js`
  - Added `METHODS_PATH` constant
  - Added `GET /api/methods` endpoint
  - Added `GET /api/methods/:family/:version/configs/:config` endpoint
  - Modified `POST /api/runs` to extract and forward `methodVersion` and `config`

### Frontend Components
- `dashboard/frontend/src/components/MethodSelector.jsx` - Replaced hardcoded Phase 6 component with dynamic version (170 lines)
- `dashboard/frontend/src/components/MethodSelector.css` - Added form field styling, loading/error states
- `dashboard/frontend/src/components/RunTrigger.jsx` - Added method name display
- `dashboard/frontend/src/components/RunTrigger.css` - Added `.method-info` styling

### Frontend Pages
- `dashboard/frontend/src/pages/Home.jsx`
  - Changed `selectedMethod` (string) to `methodSelection` (object)
  - Updated `createRun` call to pass `methodSelection.family`, `.version`, `.config`
  - Updated `handleTriggerRun` validation to check `methodSelection` object

## Testing Performed

**Backend API:**
- ✅ `GET /api/methods` returns valid JSON with families and flattened methods array
- ✅ Server starts without errors
- ✅ Endpoint reads from `app/methods/_index.json`

**Frontend Build:**
- ✅ `npm run build` succeeds without errors or warnings
- ✅ No TypeScript/ESLint issues

**Integration:**
- ✅ MethodSelector.jsx fetches from `/api/methods`
- ✅ localStorage key `sportcrunch_method_selection` used
- ✅ Home.jsx passes `methodSelection` object to RunTrigger
- ✅ RunTrigger receives and displays `method.name`

## Success Criteria Met

- ✅ Backend `/api/methods` returns methods from `_index.json`
- ✅ MethodSelector shows dropdown populated from API
- ✅ Config selector appears when method has multiple configs
- ✅ Selection persists in localStorage
- ✅ Run trigger includes method family/version/config
- ✅ Dashboard is read-only (no editing of methods, just selection)

## Deviations from Plan

None - plan executed exactly as written.

## Known Limitations

1. **No config preview:** Dashboard doesn't show config parameter values before selection
2. **No method filtering:** All methods shown in single dropdown (filtering planned for future if needed)
3. **Backwards compatibility default:** Backend defaults to `v2` if methodVersion not provided (Phase 6 runs don't specify version)
4. **Single Runner target:** Config selection applies to next run, not stored per-method globally

## Next Steps

**Phase 8: Comparison & Ground Truth**
- Ground truth overlay on timeline
- Side-by-side method comparison
- Accuracy metrics (precision/recall)

**Phase 9: Intermediate Visualization & Polish**
- Spectral flux visualization (waveform + onset detection)
- Remaining device work (if needed)
- Final polish and testing

## Architecture Notes

**Read-only design:**
- Dashboard reads methods from filesystem
- No method creation/editing in dashboard
- Methods managed via JSON files in `app/methods/`
- Validation script ensures consistency

**Flat method list:**
- Backend flattens hierarchical structure for frontend
- Simpler UI implementation (dropdown, not tree)
- Frontend doesn't need to understand family/version hierarchy

**localStorage persistence:**
- Survives page refreshes
- Simple key-value storage
- No server-side session needed

**Config as filename reference:**
- Dashboard passes config filename (e.g., "aggressive.config.json")
- Runner loads config from bundle at runtime
- No config JSON transfer over HTTP during run creation

---

**Key Achievement:** Users can now select which detection method and configuration to use for each run, with the dashboard dynamically discovering available methods from the registry and persisting user preferences across sessions.
