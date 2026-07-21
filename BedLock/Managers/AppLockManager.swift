//
//  AppLockManager.swift
//  BedLock
//
//  BedLock's own notion of "locked" — driven entirely by app state, not by any
//  Screen Time API. It's used for the Dashboard status card, the History log,
//  and habit tracking. To actually restrict other apps on the phone, pair this
//  with iOS's native Screen Time → Downtime feature, configured directly in
//  Settings (no Apple Developer account or entitlement needed) — see
//  FREE_LOCKING.md for the full walkthrough. BedLock's role is to gate *you*
//  reaching for the Screen Time passcode (via an accountability partner, or
//  simply your own honor system) until you've proven your bed is made.
//
import Foundation
import Observation

@MainActor
@Observable
final class AppLockManager {

    private(set) var isLocked: Bool
    private(set) var lastVerificationDate: Date?
    private(set) var history: [UnlockHistoryEntry]

    let persistence: PersistenceService

    init(persistence: PersistenceService) {
        self.persistence = persistence
        self.isLocked = persistence.isRestrictionActive
        self.lastVerificationDate = persistence.lastVerificationDate
        self.history = persistence.loadHistory()
    }

    /// Marks BedLock as "locked" and fires the morning notification. Call this
    /// when the schedule's reminder notification fires, or from the Test
    /// Verification flow.
    func lockNow() {
        isLocked = true
        persistence.isRestrictionActive = true
        NotificationService.shared.sendMorningLockNotification()
    }

    /// Marks BedLock as unlocked and records a successful history entry.
    func unlock(result: VerificationResult, isTest: Bool) {
        isLocked = false
        persistence.isRestrictionActive = false

        let now = Date()
        lastVerificationDate = now
        persistence.lastVerificationDate = now

        let entry = UnlockHistoryEntry(
            date: now,
            confidence: result.confidence,
            wasSuccessful: true,
            wasTest: isTest
        )
        persistence.appendHistoryEntry(entry)
        history = persistence.loadHistory()

        NotificationService.shared.sendUnlockedNotification()
    }

    /// Records a failed verification attempt without unlocking anything.
    func recordFailedAttempt(result: VerificationResult, isTest: Bool) {
        let entry = UnlockHistoryEntry(
            date: Date(),
            confidence: result.confidence,
            wasSuccessful: false,
            wasTest: isTest
        )
        persistence.appendHistoryEntry(entry)
        history = persistence.loadHistory()
    }

    /// Re-reads persisted state — call on `scenePhase` becoming `.active`.
    func syncWithSharedState() {
        isLocked = persistence.isRestrictionActive
        history = persistence.loadHistory()
        lastVerificationDate = persistence.lastVerificationDate
    }

    func clearHistory() {
        persistence.saveHistory([])
        history = []
    }
}
