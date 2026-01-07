# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS timer app built with SwiftUI for ADHD children to manage time across activities (iPad, reading, shower, homework). Features dynamic gradient backgrounds, circular progress rings with visual feedback, stars reward system, streaks, parent PIN verification, interactive tutorial, and iCloud sync.

## Building and Running

```bash
# Open in Xcode
open ADHDTimerApp.xcodeproj

# Run: Cmd+R in Xcode
# Clean build: Cmd+Shift+K
```

**Requirements:** iOS 16.0+, Swift 5.0, Xcode

## Architecture

### State Management

Two central `@MainActor @ObservableObject` singletons manage all app state:

1. **TimerViewModel** (`TimerViewModel.swift`) - Timer countdown, progress, completion flow
   - `timeRemaining`, `totalTime`, `isRunning` - Core timer state
   - `progress`, `relativeProgress` - For ring display and color transitions
   - `pendingSession` - Captures session data before verification
   - `awaitingVerification`, `showQualityRating`, `showPINSetupPrompt` - Completion flow gates
   - Completion flow: `finishEarly()` or timer completion → PIN verification (if enabled) → quality rating → `saveCompletedSession()`

2. **TimerSettings** (`TimerSettings.swift`) - Persistent settings via UserDefaults + iCloud
   - Preset durations: `ipadTime`, `readingTime`, `showerTime`, `homeworkTime`
   - `sessionHistory: [TimerSession]` - Completed sessions with allocated/actual time (capped at 100)
   - `totalStars`, `currentStreak`, `streakMultiplier` - Gamification
   - `parentPIN`, `skipPINSetupPermanently` - Optional verification gate
   - `childName`, `hasCompletedOnboarding` - Personalization
   - Tutorial tracking: `hasSeenClockBadgeTip`, `hasSeenStarsTip`, etc.
   - iCloud sync via `NSUbiquitousKeyValueStore` with merge logic for session history

### View Hierarchy

```
ContentView (main orchestrator, ~3400 lines)
├── Header bar (history button, stars badge, streak badge, tutorial button, settings)
├── Timer display (CircularProgressView + time + encouraging message)
├── Preset buttons (radial layout around custom timer button)
├── Control buttons (pause/play, "I'm Done!", stop with confirmation)
└── Sheet overlays:
    ├── SettingsSheet - App configuration
    ├── HistorySheet - Session history with time saved display
    ├── PINEntryView - Parent PIN verification
    ├── PINSetupView - Initial PIN configuration
    ├── OnboardingView - Child name entry
    ├── QualityRatingView - Post-completion task rating (amazing/good/needs work)
    └── EditSheet - Modify preset durations
```

### Key Files

- **ContentView.swift** - Main UI, all sheets/modals, session rows, completion celebration, tutorial system
- **CircularProgressView.swift** - Progress ring with segment markers, progress markers that fill up, color transitions
- **PresetButton.swift** - Animated preset buttons with sparkle effects on tap
- **SoundManager.swift** - System sounds via AudioServicesPlaySystemSound

### Color System ("Bright & Playful" Theme)

Background gradients transition based on `relativeProgress` (time remaining / total time):
- **Idle state**: Vivid purple-blue
- **>75%**: Periwinkle blue (calm)
- **50-75%**: Vibrant turquoise/cyan (energetic)
- **25-50%**: Sunny orange (attention)
- **10-25%**: Bright coral (urgency)
- **<10%**: Vibrant magenta-pink (exciting finish)

Colors defined in `TimerViewModel.backgroundGradientColors` and `CircularProgressView.currentColor`.

### Sound System

`SoundManager.swift` uses iOS system sounds (AudioServicesPlaySystemSound):
- **Completion** (1016): Plays twice with 0.3s delay, success haptic
- **Warning/1 minute** (1053): Medium impact haptic
- **Tick** (1104): Optional per-second sound when `tickSoundEnabled`
- **Milestone** (1054): Light impact haptic for halfway/time warnings

### Data Flow

1. User taps preset → `startTimer(minutes:activity:activityIcon:)`
2. Timer ticks → updates `timeRemaining`, triggers color/ring changes
3. User taps "I'm Done!" → `finishEarly()` captures `actualTimeSpent` and `timeSavedSeconds`
4. If PIN enabled → `awaitingVerification = true` → PIN entry → `confirmVerification()`
5. Quality rating shown → parent selects rating → `confirmVerificationWithRating()` awards stars
6. `saveCompletedSession()` → `settings.addSession()` → persists to UserDefaults + iCloud

### Interactive Tutorial System

`TutorialStep` enum defines 9-step interactive walkthrough:
1. startTimer → clockBadge → customTimer → starsBadge → (streakBadge if applicable) → doneButton → historyButton → settingsButton → pinSetupRow

Tutorial state managed by `activeTutorialStep` with pulsing highlight overlays. User can restart via "Tutorial" button.

## Adding a New Preset Activity

1. Add property to `TimerSettings.swift` with UserDefaults persistence and iCloud sync in `handleiCloudChange()`
2. Add case to `ActivityType` enum in `ContentView.swift`
3. Add to `presets` array in `presetButtons` view (title, icon, time, color, activity)
4. Handle in `activityName()` and `saveEditedTime()` functions
5. Update `init()` in TimerSettings to load from UserDefaults with default value

## Testing Notes

No unit tests currently. Manual testing required for:
- Timer accuracy over long durations
- Background/foreground transitions (timer resets on background)
- Sound playback in silent mode and low power mode
- iCloud sync between devices
- iPad vs iPhone layout differences
