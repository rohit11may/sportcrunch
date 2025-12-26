# Prompt: Design iOS App Mockups for SportCrunch

## Context & Overview

You are designing **SportCrunch** — an iOS app that automatically creates highlight videos from raw sports recordings. The app removes "dead time" (ball retrieval, changeovers, timeouts, replays) and keeps only the action.

The technology works by analyzing the audio track to detect distinctive action sounds (racket hits, bat cracks) and validates with video motion analysis. Users don't need to know any of this—it should feel like magic.

**Target Users:** 
- Amateur athletes who record their own games
- Parents filming their kids' sports matches  
- Coaches wanting quick game recaps
- Social media creators who need shareable sports clips

**Core Value Proposition:** Turn a 2-hour tennis match into a 15-minute highlight reel with one tap. No editing skills required.

---

## Technical Design Note

**Use native SwiftUI components throughout the design.** The mockups should reflect iOS-native patterns that translate directly to SwiftUI implementation:
- `NavigationStack` for navigation hierarchy
- `TabView` for bottom navigation if needed
- Native `PhotosPicker` for video selection
- `Sheet` and `fullScreenCover` for modals
- `ProgressView` patterns for loading states
- SF Symbols for iconography where appropriate
- Native `ShareLink` for export/sharing

Design with SwiftUI's declarative patterns in mind—components should map cleanly to Views, ViewModifiers, and standard iOS patterns.

---

## Design Requirements

### Supported Sports (Presets)

Design the app to support these sports, each with an appropriate icon and color accent:

| Sport | Action Being Detected |
|-------|----------------------|
| 🎾 Tennis | Racket-ball impacts |
| 🏏 Cricket | Bat-ball contacts, bowling impacts |

Users simply select a sport—no tuning parameters exposed.

---

### Core User Flows

Design mockups for these flows:

#### Flow 1: First-Time User Onboarding (2-3 screens max)
- Brief value proposition
- Request photo library access permission
- Optional: Sign up / skip to try

#### Flow 2: Main Home Screen
- Show recent projects (video thumbnails with before/after duration)
- Prominent "Create Highlight" action
- Access to settings/profile

#### Flow 3: Creating a Highlight (Primary Flow)
1. **Select Video** — From camera roll using native PhotosPicker
2. **Choose Sport** — Visual selection of Tennis or Cricket
3. **Processing** — Show progress with engaging animation (this takes 1-3 minutes)
4. **Preview Results** — Scrubable timeline showing what's kept vs. removed
5. **Export/Share** — Save to camera roll, share to social

#### Flow 4: Export Options
- Quality presets: "Social" (compressed, square/9:16), "Full Quality" (original resolution)
- Add simple title card or watermark
- Direct share to Instagram Reels, TikTok, YouTube Shorts

---

### UI/UX Principles

**Simplicity First:**
- One-tap operation for the basic flow (select video → select sport → done)
- No jargon: Use friendly labels like "Highlight Intensity" not technical terms
- Minimal decisions required

**Visual Feedback:**
- Show the "magic" happening with timeline visualizations
- Display stats users care about: "3 hr → 18 min" or "Removed 2h 42m of downtime"
- Before/after preview comparison

**Speed Perception:**
- Processing takes 1-3 minutes—make this feel fast with:
  - Progress bar with stages ("Analyzing audio..." → "Detecting action..." → "Creating clips...")
  - Tip cards or fun facts about the sport while waiting
  - Allow backgrounding with push notification on completion

**Trust Building:**
- Preview before committing (don't auto-save over original)
- "Original video unchanged" reassurance

---

### Visual Design Direction

Create a modern, sporty aesthetic that feels:
- **Energetic** but not chaotic
- **Premium** but accessible
- **Clean** with bold accent colors

**Typography:** Use a geometric sans-serif with good weight variety. Consider something distinctive like Outfit, Plus Jakarta Sans, or Clash Display for headings—or use SF Pro with intentional weight/size hierarchy.

**Color Palette Suggestions:**
- Primary: Vibrant coral/orange (#FF6B35) or electric blue (#0066FF)
- Dark mode first (athletes often review footage in low-light)
- Use sport-specific accent colors: green/yellow for Tennis, blue/red for Cricket

**Iconography:**
- Prefer SF Symbols where available
- Custom sport icons for Tennis and Cricket
- Rounded, friendly shapes
- Consistent visual weight

**Motion:**
- Smooth transitions between screens using SwiftUI's built-in animations
- Timeline scrubbing should feel tactile
- Celebrate successful exports (confetti? checkmark burst?)

---

### Screens to Design

Please create high-fidelity mockups for:

1. **Splash/Loading Screen** — App launch branding
2. **Onboarding Flow** (2-3 screens) — Value prop, permissions
3. **Home Screen** — Empty state + populated state with 2-3 recent projects
4. **Video Selection** — Integration with native PhotosPicker
5. **Sport Selection** — Choice between Tennis and Cricket
6. **Processing Screen** — Progress with stages and engagement
7. **Preview/Review Screen** — Timeline showing kept segments, playback controls
8. **Export Modal** — Quality and destination options (as a SwiftUI Sheet)
9. **Success/Share Screen** — Post-export celebration and share actions
10. **Settings Screen** — Account, storage, default preferences

---

### Platform Considerations

- Design for iPhone 14/15 Pro dimensions (393 × 852 pt)
- Support Dynamic Island awareness
- Use iOS 17+ SwiftUI patterns (NavigationStack, sheets, confirmationDialogs)
- Ensure accessibility (Dynamic Type support, sufficient contrast)
- Consider both Light and Dark mode (prioritize Dark)
- All components should map directly to SwiftUI Views

---

### Deliverables

1. **High-fidelity mockups** for all screens listed above (Figma, Sketch, or equivalent)
2. **Clickable prototype** demonstrating the primary "Create Highlight" flow
3. **Component library** with buttons, cards, timeline UI, sport badges—annotated with corresponding SwiftUI components
4. **Micro-interaction specs** for key moments (processing animation, timeline scrub, export celebration)

---

### What NOT to Include

- No exposed technical parameters (bandpass frequencies, threshold lambdas, motion area thresholds)
- No waveform visualizations or audio spectrum displays
- No developer-focused debugging tools
- No per-segment detailed timecode editing
- No manual clip trimming or segment toggling
- No subscription/paywall UI (can be added later)

---

### Inspiration References

For aesthetic direction, look at:
- **Strava** — Clean sports app with bold stats
- **Fitness+** — Premium feel, video-centric
- **CapCut** — Simple video editing with powerful results
- **Loom** — Effortless video processing
- **Opal** — Beautiful iOS-native dark UI

---

## Summary

Design **SportCrunch**, an iOS app that makes creating sports highlight videos as easy as applying a photo filter. Users pick a video, choose Tennis or Cricket, and get a polished highlight reel in minutes. The interface should be so simple that a parent filming their kid's match can use it courtside, and so polished that a content creator would be proud to share the results. All designs should translate cleanly to SwiftUI implementation.

