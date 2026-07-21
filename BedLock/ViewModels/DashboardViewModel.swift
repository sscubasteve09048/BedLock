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
    private let persistence: PersistenceService

    var schedule: ScheduleModel
    var showingVerification = false

    init(appLockManager: AppLockManager, persistence: PersistenceService) {
        self.appLockManager = appLockManager
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

    func refresh() {
        appLockManager.syncWithSharedState()
        schedule = persistence.loadSchedule()
    }

    func beginVerification() {
        showingVerification = true
    }
}
