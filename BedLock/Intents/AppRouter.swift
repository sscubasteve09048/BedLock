//
//  AppRouter.swift
//  BedLock
//
//  A tiny piece of shared state that lets a Siri Shortcut / App Intent tell
//  the already-running (or freshly launched) app "the user wants to verify
//  their bed right now" without needing any Screen Time entitlement at all —
//  App Intents are a fully public API available to any app, free of charge.
//
import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    /// Set to true by `VerifyBedMadeIntent` when the intent runs. ContentView
    /// observes this and presents the camera verification screen, then resets
    /// it back to false.
    var wantsToPresentVerification = false

    func requestVerification() {
        wantsToPresentVerification = true
    }
}
