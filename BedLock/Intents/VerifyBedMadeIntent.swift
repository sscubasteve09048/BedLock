//
//  VerifyBedMadeIntent.swift
//  BedLock
//
//  Exposes BedLock's verification flow to Siri, the Shortcuts app, Spotlight,
//  and (on supported hardware) the Action Button — all using the public
//  `AppIntents` framework, which requires no special entitlement or approval
//  from Apple. This is the free replacement for "the schedule automatically
//  unlocks the phone": instead, a Shortcuts Personal Automation (also free,
//  built into iOS) can run this every morning, or the user can just ask Siri
//  "Verify my bed with BedLock."
//
//  Because taking a photo requires UI, this intent opens the app to the
//  camera verification screen rather than trying to run headlessly.
//
import AppIntents

struct VerifyBedMadeIntent: AppIntent {
    static var title: LocalizedStringResource = "Verify My Bed Is Made"
    static var description = IntentDescription(
        "Opens BedLock's camera so you can prove your bed is made."
    )

    /// Ensures the app is brought to the foreground so the camera can be shown.
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppDependencies.shared.router.requestVerification()
        return .result()
    }
}

/// Registers the intent as an "App Shortcut" so it shows up automatically in
/// the Shortcuts app and responds to natural Siri phrases without the user
/// having to build anything themselves first.
struct BedLockAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: VerifyBedMadeIntent(),
            phrases: [
                "Verify my bed with \(.applicationName)",
                "Unlock my phone with \(.applicationName)",
                "Make my bed check with \(.applicationName)"
            ],
            shortTitle: "Verify Bed",
            systemImageName: "bed.double.fill"
        )
    }
}
