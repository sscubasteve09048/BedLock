# BedLock

A SwiftUI iOS app that locks your phone until you take a verified photo of your made bed.

## What's included

- **BedLock** (app target): Dashboard, Schedule, App Selection, Camera Verification, History, and Settings screens, built with SwiftUI + the Observation framework + NavigationStack, MVVM throughout.
- **BedLockMonitor** (DeviceActivityMonitor extension target): wakes up at your scheduled time and engages the Screen Time shield even if the app isn't running.
- **Shared** code (models + persistence + notifications) used by both targets via an App Group.
- Modular bed-verification pipeline: `BedVerifying` protocol → `VisionBedVerificationService` (ships today, built on Apple's on-device `VNClassifyImageRequest` + `VNDetectRectanglesRequest`) → `CoreMLBedVerificationService` (drop in a trained `.mlmodelc` later, zero other code changes) → `BedVerificationService` facade that prefers the custom model and falls back automatically.

## One-time setup before building (required)

Apple ties several things to your own Developer account. You must do these before the project will build and run on a device:

1. **Apple Developer Program membership** with Screen Time / Family Controls access. Apple requires you to request the **Family Controls (Distribution) capability** for your Team ID: https://developer.apple.com/contact/request/family-controls-distribution — approval isn't instant, so start this first. The `.development` scope of Family Controls (used for local testing at all) also requires this entitlement to be present on your provisioning profile.
2. **Open `BedLock.xcodeproj` in Xcode 16+** (needed for the iOS 18 SDK, `Tab(_:systemImage:)`, and Observation APIs used here).
3. For **both** targets (BedLock and BedLockMonitor), in *Signing & Capabilities*:
   - Set your **Team**.
   - Change the **Bundle Identifier** away from the placeholders (`com.bedlock.app` and `com.bedlock.app.BedLockMonitor`) to something under your own Team's identifier prefix — keep the extension's ID as `<appID>.BedLockMonitor`.
   - Add the **App Groups** capability and select/create a group (the code assumes `group.com.bedlock.shared` — either create that exact group or update `PersistenceService.appGroupIdentifier` and `*.entitlements` files to match your own).
   - Add the **Family Controls** capability to the **BedLock app target only** (not the extension).
4. Build and run on a **physical iPhone** running iOS 18+. `FamilyControls`/`ManagedSettings`/`DeviceActivity` do not work in the Simulator.
5. On first launch, grant Screen Time, Camera, and Notification permissions when prompted (Dashboard prompts for Screen Time; Settings shows live status for all three).

## Using the app

1. **Apps tab** (Settings → Apps): choose whether to block everything except an allow-list, or only block specific apps; pick which apps stay reachable.
2. **Schedule tab** (Settings → Schedule): set the lock start time, optional end time, and active days.
3. Every morning at the scheduled time, BedLockMonitor shields your apps and fires "Good morning! Make your bed to unlock your phone."
4. Open BedLock, tap **Make Your Bed to Unlock**, take a photo. If confidence ≥ your threshold (default 85%, adjustable in Settings), the shield lifts and you get "Nice job! Your phone is unlocked." Otherwise you're asked to retake the photo.
5. **Settings → Test Verification** locks your apps immediately (ignoring the schedule) and runs the identical camera + verification + unlock flow, for testing any time of day.
6. **History tab** shows every attempt: date, time, confidence, and pass/fail, with TEST attempts flagged.

## Known Apple-imposed limitations (by design, not a bug)

- **Emergency SOS, Phone, and system Clock alarms can never be shielded** by any third-party app — `ManagedSettings` silently ignores attempts to restrict them. BedLock never tries to route around this; the App Selection screen documents it.
- Apple does not expose bundle identifiers for installed apps to third parties, so app selection happens through the system `FamilyActivityPicker` (opaque tokens), not a custom list — this is intentional on Apple's part for privacy.
- The bundled `VisionBedVerificationService` is a heuristic (scene classification + rectangle/flatness detection), not a model specifically trained on "made vs. unmade" beds, since no such public Core ML model exists. Accuracy will improve once you train and drop in a custom model — see `CoreMLBedVerificationService.swift`.

## Project structure

```
BedLock.xcodeproj
BedLock/                     (app target)
  BedLockApp.swift
  Managers/                  ScreenTimeManager, ScheduleManager, AppLockManager
  Services/                  BedVerifying + Vision/CoreML implementations, CameraService
  ViewModels/                one per screen, @Observable
  Views/                     one per screen, SwiftUI
  Shared/                    Models + PersistenceService + NotificationService + SharedConstants
                             (also included in the BedLockMonitor target)
  Resources/Assets.xcassets  AppIcon (placeholder) + AccentColor
  Info.plist, BedLock.entitlements
BedLockMonitor/               (DeviceActivityMonitor extension target)
  DeviceActivityMonitorExtension.swift
  Info.plist, BedLockMonitor.entitlements
```
