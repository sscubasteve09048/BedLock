//
//  DashboardViewModel.swift
//  BedLock
//
//  Drives the Dashboard screen: current lock state, schedule summary, and quick
//  access to the verification flow.
//
import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {

    let appLockManager: AppLockManager
    let screenTimeManager: ScreenTimeManager
    private let persistence: PersistenceService

    var schedule: ScheduleModel
    var showingVerification = false
    var showingAuthorizationAlert = false

    init(appLockManager: AppLockManager, screenTimeManager: ScreenTimeManager, persistence: PersistenceService) {
        self.appLockManager = appLockManager
        self.screenTimeManager = screenTimeManager
        self.persistence = persistence
        self.schedule = persistence.loadSchedule()
    }

    var isLocked: Bool { appLockManager.isLocked }

    var lastVerificationText: String {
        guard let date = appLockManager.lastVerificationDate else {
            return "No verification yet"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Last unlocked \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    var needsAuthorization: Bool {
        screenTimeManager.authorizationStatus != .approved
    }

    func refresh() {
        appLockManager.syncWithSharedState()
        schedule = persistence.loadSchedule()
        screenTimeManager.refreshAuthorizationStatus()
    }

    func requestAuthorizationIfNeeded() async {
        if screenTimeManager.authorizationStatus == .notDetermined {
            await screenTimeManager.requestAuthorization()
        }
        if screenTimeManager.authorizationStatus != .approved {
            showingAuthorizationAlert = true
        }
    }

    func beginVerification() {
        showingVerification = true
    }
}
