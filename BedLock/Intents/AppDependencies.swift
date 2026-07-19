//
//  AppDependencies.swift
//  BedLock
//
//  App Intents run outside the normal SwiftUI environment, so they can't read
//  `@Environment` values. This tiny singleton gives `VerifyBedMadeIntent` a way
//  to reach the same `AppRouter` instance that `BedLockApp` injects into the
//  view hierarchy, so triggering the intent and tapping the Dashboard button
//  produce identical behavior.
//
import Foundation

@MainActor
final class AppDependencies {
    static let shared = AppDependencies()

    let router = AppRouter()

    private init() {}
}
