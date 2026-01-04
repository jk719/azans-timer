# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current Work in Progress

**Left off on:** History page improvements and PIN page color review

### Pending Tasks:
1. **History Page (HistorySheet)** - Review and improve the display. Recent changes:
   - Fixed "0 min" display to round up properly
   - Changed "-29m" to "Saved 29m" with green checkmark (positive reinforcement)
   - May need further refinement based on user feedback

2. **PIN Page Colors** - Check color combinations for consistency with "Bright & Playful" theme
   - PIN Entry View (`PINEntryView`) - around line 1479 in ContentView.swift
   - PIN Setup View (`PINSetupView`) - around line 1945 in ContentView.swift
   - Background was updated to vibrant purple but needs verification

### Recent Changes (uncommitted):
- Removed milestone popup banners and sounds (kept encouraging message)
- Fixed History page session display (positive "Saved Xm" instead of "-Xm")

## Project Overview

iOS timer app built with SwiftUI for ADHD children to manage time across activities (iPad, reading, shower, homework). Features dynamic gradient backgrounds, progress rings with visual feedback, stars reward system, streaks, parent PIN verification, and iCloud sync.

## Building and Running

```bash
# Open in Xcode
open ADHDTimerApp/ADHDTimerApp.xcodeproj

# Run: Cmd+R in Xcode
# Clean build: Cmd+Shift+K
```

**Requirements:** iOS 16.0+, Swift 5.0, Xcode

## Architecture

### State Management

Two central `@ObservableObject` singletons manage all app state:

1. **TimerViewModel** (`TimerViewModel.swift`) - Timer countdown, progress, completion flow
   - `timeRemaining`, `totalTime`, `isRunning` - Core timer state
   - `progress`, `relativeProgress` - For ring display and color transitions
   - `pendingSession` - Captures session data before verification
   - Completion flow: `finishEarly()` → verification → `saveCompletedSession()`

2. **TimerSettings** (`TimerSettings.swift`) - Persistent settings via UserDefaults + iCloud
   - Preset durations: `ipadTime`, `readingTime`, `showerTime`, `homeworkTime`
   - `sessionHistory: [TimerSession]` - Completed sessions with allocated/actual time
   - `totalStars`, `currentStreak` - Gamification
   - `parentPIN` - Optional verification gate
   - iCloud sync via `NSUbiquitousKeyValueStore`

### View Hierarchy

```
ContentView (main orchestrator, ~3200 lines)
├── Header bar (stars, streak, settings, history buttons)
├── Timer display (CircularProgressView + time + activity)
├── Preset buttons (radial layout around custom timer)
├── Control buttons (pause/play, done, stop)
└── Sheet overlays (Settings, History, PIN, Onboarding, etc.)
```

### Key Files

- **ContentView.swift** - Main UI, all sheets/modals, session rows, completion celebration
- **CircularProgressView.swift** - Progress ring with markers, animations, color states
- **PresetButton.swift** - Animated preset buttons with sparkle effects
- **SoundManager.swift** - System sounds (IDs: 1016 completion, 1053 warning, 1104 tick)

### Color System

Background gradients transition based on `relativeProgress`:
- `>75%`: Blue (calm)
- `50-75%`: Turquoise (energetic)
- `25-50%`: Orange (attention)
- `10-25%`: Coral (urgency)
- `<10%`: Magenta-pink (excitement)

Colors defined in `TimerViewModel.backgroundGradientColors` and `CircularProgressView.currentColor`.

### Data Flow

1. User taps preset → `startTimer(minutes:activity:activityIcon:)`
2. Timer ticks → updates `timeRemaining`, triggers color/ring changes
3. User taps "Done" → `finishEarly()` captures `actualTimeSpent`
4. If PIN enabled → `awaitingVerification = true` → PIN entry → quality rating
5. `saveCompletedSession()` → `settings.addSession()` → persists to UserDefaults + iCloud

## Adding a New Preset Activity

1. Add property to `TimerSettings.swift` with UserDefaults persistence and iCloud sync
2. Add case to `ActivityType` enum in `ContentView.swift`
3. Add to `presets` array in `presetButtons` view (title, icon, time, color, activity)
4. Handle in `activityName()` and `saveEditedTime()` functions
