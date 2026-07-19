//
//  AppLockManager.swift
//  BedLock
//
//  The single source of truth for "is BedLock currently restricting apps".
//  Coordinates ScreenTimeManager (applies the actual shield), PersistenceService
//  (remembers state/history across launches and processes), and
//  NotificationService (user-facing alerts). ViewModels talk to this instead of
//  touching ManagedSettings/UserDefaults directly.
//
import Foundation
import Observation

@MainActor
@Observable
final class AppLockManager {

    private(set) var isLocked: Bool
    private(set) var lastVerificationDate: Date?
    private(set) var history: [UnlockHistoryEntry]

    let screenTimeManager: ScreenTimeManager
    let persistence: PersistenceService

    init(screenTimeManager: ScreenTimeManager, persistence: PersistenceService) {
        self.screenTimeManager = screenTimeManager
        self.persistence = persistence
        self.isLocked = persistence.isRestrictionActive
        self.lastVerificationDate = persistence.lastVerificationDate
        self.history = persistence.loadHistory()
    }

    /// Engages the shield immediately, using the current app selection. Called by
    /// the schedule (via the DeviceActivityMonitor extension setting the shared
    /// flag, then the app syncing on next foreground) or by the Test Verification
    /// flow.
    func lockNow(selection: AppSelectionModel) {
        screenTimeManager.applyRestrictions(selection: selection)
        isLocked = true
        persistence.isRestrictionActive = true
        NotificationService.shared.sendMorningLockNotification()
    }

    /// Removes the shield and records a history entry describing why.
    func unlock(result: VerificationResult, isTest: Bool) {
        screenTimeManager.removeRestrictions()
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

    /// Re-reads shared state — call on `scenePhase` becoming `.active` so the app
    /// picks up a lock that the DeviceActivityMonitor extension engaged while the
    /// app wasn't running.
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
