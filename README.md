# BedLock

A SwiftUI iOS app that helps you build the habit of making your bed (and any
other morning habits you want to track), gamified with XP, levels, streaks,
badges, and quests. It verifies a photo of your bed each morning using
Apple's Vision framework. BedLock does not and cannot lock or unlock other
apps on your phone — it tracks your own verification streak and progress. To
pair it with actual app restriction, see iOS's free **Screen Time →
Downtime** feature, covered in `FREE_LOCKING.md`.

## What's included

- **BedLock** — a single-target app with Dashboard, Progress, History, and
  Settings tabs, built with SwiftUI + the Observation framework +
  NavigationStack, MVVM throughout.
- **Gamification**: a daily Morning Score (0-100) combining bed verification
  with any custom habits you add, an XP/leveling system, current/longest
  streak tracking, a calendar view, unlockable badges, and daily/weekly
  quests — all computed from your own local data, nothing server-side.
- **Custom habits**: add, edit, and reorder your own morning habits (Settings
  → Habits) — BedLock ships with zero preset habits beyond bed verification
  itself.
- Modular bed-verification pipeline: `BedVerifying` protocol →
  `VisionBedVerificationService` (ships today, built on Apple's on-device
  `VNClassifyImageRequest` + `VNDetectRectanglesRequest`) →
  `CoreMLBedVerificationService` (drop in a trained `.mlmodelc` later, zero
  other code changes) → `BedVerificationService` facade that prefers the
  custom model and falls back automatically.
- **Siri Shortcuts / App Intents integration** (`VerifyBedMadeIntent`) — say
  "Hey Siri, verify my bed with BedLock," trigger it from the Shortcuts app,
  or a Personal Automation, to open straight to the camera.
- Local, repeating reminder notifications (`ScheduleManager`) using
  `UNCalendarNotificationTrigger` — no background wake-up entitlement needed.

## No paid Apple Developer account required

Earlier versions of this project used `FamilyControls`/`ManagedSettings` (a
`DeviceActivityMonitor` extension target) to have the app itself shield other
apps on the device. That API requires a paid ($99/yr) Apple Developer Program
membership *and* an Apple-approved capability request — a real source of
friction and build fragility. This version removes that entirely:

- **Zero entitlements.** No App Group, no Family Controls capability.
- **Single target.** No extension, no shared container, no cross-process state.
- **Builds and runs on a free ("Personal Team") Apple ID.** Open the project
  in Xcode, select your own free Apple ID as the team, and run — no capability
  requests, no waiting on Apple approval.
- **Camera, Vision, local notifications, and App Intents/Siri Shortcuts** are
  all fully public APIs with no special entitlement, so all of BedLock's core
  functionality — verification, history, reminders, Siri triggers — works
  exactly the same either way.

The one thing a free account genuinely can't do is have BedLock itself block
other apps at the OS level — no app can do that without the paid, approved
entitlement. Instead, pair BedLock with iOS's own free Screen Time → Downtime
feature, configured directly in Settings. **Read `FREE_LOCKING.md` for the
full walkthrough** — it's the actual "locking" mechanism for this project.

## Setup

1. Open `BedLock.xcodeproj` in Xcode 16+ (needed for the iOS 18 SDK,
   `Tab(_:systemImage:)`, and Observation APIs used here).
2. In *Signing & Capabilities*, set your **Team** (a free Apple ID works) and
   change the **Bundle Identifier** away from the placeholder `com.bedlock.app`
   to something under your own identifier prefix.
3. Build and run on a physical iPhone or the Simulator, iOS 18+.
4. On first launch, grant Camera and Notification permissions when prompted.
5. Follow `FREE_LOCKING.md` to configure Screen Time Downtime for the actual
   app-blocking behavior.

## Using the app

1. **Settings → Habits**: add any custom morning habits you want tracked
   (stretching, drinking water, journaling — anything). Each has its own XP
   value and contributes to your daily Morning Score.
2. **Settings → Schedule**: set the reminder time, optional second reminder,
   and active days.
3. Every morning at the scheduled time, BedLock sends "Good morning! Time to
   verify your bed and keep your streak going." (You can also trigger this
   on demand via Siri or the Shortcuts app — see `FREE_LOCKING.md`.)
4. Open BedLock, tap **Verify Your Bed**, take a photo. If confidence ≥ your
   threshold (default 60%, adjustable in Settings), you earn XP and your
   streak continues. Otherwise you're asked to retake the photo.
5. **Dashboard** shows today's Morning Score, level/XP progress, current and
   longest streak, today's habit checklist, and quest progress — with
   confetti on a perfect day or a new badge.
6. **Progress tab** shows a streak calendar, monthly stats, and your
   achievements grid.
7. **Settings → Test Verification** runs the identical camera + verification
   pipeline any time of day — useful for checking your camera/model, but it
   never affects your real XP, streak, or score.
8. **History tab** shows every attempt: date, time, confidence, and
   pass/fail, with TEST attempts flagged.

## Known limitation (by design, not a bug)

The bundled `VisionBedVerificationService` is a heuristic (scene
classification + rectangle/flatness detection), not a model specifically
trained on "made vs. unmade" beds, since no such public Core ML model exists.
**See `TRAIN_CUSTOM_MODEL.md` for a full guide to training a personal model
on photos of your own bed** — it's a much easier problem than general bed
detection, and the app already prefers a custom model over the heuristic
automatically once one is added (`CoreMLBedVerificationService.swift`).

## Project structure

```
BedLock.xcodeproj
BedLock/
  BedLockApp.swift
  Managers/                  GamificationManager, HabitManager, ScheduleManager, ModelRetrainReminderManager
  Services/                  BedVerifying + Vision/CoreML implementations, CameraService, ModelImportService
  Intents/                   VerifyBedMadeIntent, AppRouter, AppDependencies (Siri/Shortcuts)
  ViewModels/                one per screen, @Observable
  Views/                     one per screen, SwiftUI (Dashboard, Progress, Habits, History, Schedule, Settings, Camera, Confetti)
  Shared/Models/             Habit, DailyProgress, Achievement, LevelInfo, Quest, ScheduleModel, UnlockHistoryEntry, VerificationResult
  Shared/                    PersistenceService + NotificationService
  Resources/Assets.xcassets  AppIcon (placeholder) + AccentColor
  Info.plist
```
