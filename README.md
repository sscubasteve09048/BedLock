# BedLock

A SwiftUI iOS app that helps you build the habit of making your bed: it
verifies a photo of your bed each morning using Apple's Vision framework, and
tracks a history of every attempt. It's designed to pair with iOS's own free
**Screen Time → Downtime** feature for actual app restriction — see
`FREE_LOCKING.md`.

## What's included

- **BedLock** — a single-target app (Dashboard, Schedule, Camera Verification,
  History, and Settings screens), built with SwiftUI + the Observation
  framework + NavigationStack, MVVM throughout.
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

1. **Settings → Schedule**: set the reminder time, optional second reminder,
   and active days.
2. Every morning at the scheduled time, BedLock sends "Good morning! Make
   your bed to unlock your phone." (You can also trigger this on demand via
   Siri or the Shortcuts app — see `FREE_LOCKING.md`.)
3. Open BedLock, tap **Make Your Bed to Unlock**, take a photo. If confidence
   ≥ your threshold (default 85%, adjustable in Settings), you get "Nice job!
   Your phone is unlocked." Otherwise you're asked to retake the photo.
4. **Settings → Test Verification** runs the identical camera + verification
   flow any time of day, ignoring the schedule.
5. **History tab** shows every attempt: date, time, confidence, and
   pass/fail, with TEST attempts flagged.

## Known limitation (by design, not a bug)

The bundled `VisionBedVerificationService` is a heuristic (scene
classification + rectangle/flatness detection), not a model specifically
trained on "made vs. unmade" beds, since no such public Core ML model exists.
Accuracy will improve once you train and drop in a custom model — see
`CoreMLBedVerificationService.swift`.

## Project structure

```
BedLock.xcodeproj
BedLock/
  BedLockApp.swift
  Managers/                  AppLockManager, ScheduleManager
  Services/                  BedVerifying + Vision/CoreML implementations, CameraService
  Intents/                   VerifyBedMadeIntent, AppRouter, AppDependencies (Siri/Shortcuts)
  ViewModels/                one per screen, @Observable
  Views/                     one per screen, SwiftUI
  Shared/                    Models + PersistenceService + NotificationService
  Resources/Assets.xcassets  AppIcon (placeholder) + AccentColor
  Info.plist
```
