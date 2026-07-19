# Locking apps for free (no paid developer account, no entitlement)

The Family Controls entitlement (what the `ScreenTimeManager`/`ManagedSettings`
code in this project uses) is the only piece of BedLock that genuinely
requires Apple's paid Developer Program + an approved capability request.
Everything else — camera capture, Vision-based bed verification, history,
local notifications, and now Siri Shortcuts integration — is built on fully
public APIs and costs nothing.

This doc describes a free alternative locking mechanism built entirely out of
features already on your iPhone, plus the two new files this update adds:

- `Intents/VerifyBedMadeIntent.swift` — exposes an **App Intent** ("Verify My
  Bed Is Made") that Siri, Shortcuts, Spotlight, and the Action Button (on
  iPhone 15 Pro/16 and later) can all trigger. It opens BedLock straight to the
  camera verification screen. App Intents require no entitlement — any app can
  ship them.
- `Intents/AppRouter.swift` / `Intents/AppDependencies.swift` — small plumbing
  so that intent can tell the already-open (or freshly launched) app to
  present the verification screen.

## The free locking recipe: native Screen Time Downtime

iOS has had a free, no-entitlement-required app-blocking feature built into
Settings since iOS 12: **Screen Time → Downtime** (and **App Limits**), locally
on a single device, no Family Sharing required.

### One-time setup (all in the Settings app, ~5 minutes)

1. **Settings → Screen Time → Turn On Screen Time** (if not already on).
2. **Set a Screen Time passcode** you don't use anywhere else (Settings →
   Screen Time → "Use Screen Time Passcode"). This is what makes the
   restriction hold — without a passcode, anyone can just turn Downtime off.
3. **Settings → Screen Time → Downtime → Scheduled**, set it to start at your
   wake-up time (e.g. 7:00 AM). Leave the end time far enough out that
   Downtime is still active when you'd normally be tempted to scroll (e.g.
   ends at a time you're realistically already up and moving, like 9:00 AM) —
   or set it to run nearly all day if you want it to persist until you
   manually intervene.
4. **Settings → Screen Time → Always Allowed**: add **BedLock**, **Shortcuts**,
   **Phone**, and **Messages**. Everything not in this list gets shielded
   during Downtime — this is the same "everyone blocked except X" behavior
   the paid version implements with `ManagedSettings`, just driven by Apple's
   own first-party Screen Time UI instead of a third-party entitlement.

That's it — this part requires zero code and zero dollars. From here,
Downtime will engage every scheduled morning with no app of yours needing to
run at all, and it's genuinely enforced by iOS (you'd need the Screen Time
passcode to disable it early).

### Wiring BedLock into it

Downtime lifts automatically at its scheduled end time regardless of whether
you made your bed — Apple's Screen Time has no concept of "unlock early if a
condition is met." To recreate BedLock's "prove it to unlock" behavior for
free, pick one of these:

**Option A — Accountability partner (recommended, strongest)**
Give your Screen Time passcode to someone you trust (partner, roommate,
friend) instead of yourself, or don't memorize it and only write it down
somewhere you can't get to quickly. Then:
1. Every morning, trigger `VerifyBedMadeIntent` — say "Hey Siri, verify my bed
   with BedLock," tap the Shortcuts app, or (iPhone 15 Pro+) assign it to the
   Action Button.
2. BedLock opens straight to the camera, takes and scores the photo exactly as
   before, and logs it to History.
3. If it passes, text a screenshot of the success screen (Messages is in your
   Always Allowed list, so it's reachable during Downtime) to your
   accountability partner, who replies with the Screen Time passcode so you
   can disable Downtime for the day.

This is genuinely hard to cheat (you don't have the passcode), costs nothing,
and reuses all of BedLock's existing verification/history code as-is.

**Option B — Honor system (simplest, weakest)**
Just use BedLock purely as a verification + history tracker: you know your
own Screen Time passcode, take the photo each morning via the Action
Button/Shortcut, and manually toggle Downtime off once BedLock confirms
success. There's no hard technical gate — you're trusting yourself not to
toggle it off first — but for a lot of people the habit-tracking + friction of
"I have to go find Screen Time and disable this" is enough.

**Option C — A second free Apple ID as "parent" (Family Sharing)**
Set up Family Sharing with a second, free Apple ID as the organizer (an old
iPad, a Mac, or even just a browser session at icloud.com on another device
works), and mark your iPhone as a "child" device. From the organizer side you
can schedule Downtime remotely and approve/deny "Ask For More Time" requests
that pop up on the child device when a shielded app is tapped. This is fully
native and free, and doesn't require you personally to hold a passcode you
don't know, but it does require a second device or careful juggling of two
Apple IDs on one device.

## What you get either way

| Feature | Free path (Downtime) | Paid path (Family Controls) |
|---|---|---|
| Camera + Vision bed verification | ✅ | ✅ |
| History log | ✅ | ✅ |
| Notifications | ✅ | ✅ |
| Siri/Shortcuts/Action Button trigger | ✅ (new) | ✅ (new) |
| Automatic schedule (no user action) | Downtime engages itself, free | `DeviceActivityMonitor` extension engages the shield, free once entitled |
| Hard "can't disable without proof" gate | Only with an accountability partner (Option A/C) | Yes, natively — the app itself controls the shield |
| Cost | $0 | $99/year Apple Developer Program |

If you later decide to pursue the paid entitlement, nothing here conflicts —
`ScreenTimeManager`/`ManagedSettingsStore` and this free path can coexist; you'd
just be choosing which one actually drives the "lock" while keeping the same
verification core.
