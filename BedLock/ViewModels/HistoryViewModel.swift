//
//  HistoryViewModel.swift
//  BedLock
//
//  Drives the History screen, listing past verification attempts.
//
import Foundation
import Observation

@MainActor
@Observable
final class HistoryViewModel {

    private let appLockManager: AppLockManager

    init(appLockManager: AppLockManager) {
        self.appLockManager = appLockManager
    }

    var entries: [UnlockHistoryEntry] {
        appLockManager.history
    }

    var successCount: Int {
        entries.filter(\.wasSuccessful).count
    }

    var averageConfidence: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.reduce(0) { $0 + $1.confidence } / Double(entries.count)
    }

    func refresh() {
        appLockManager.syncWithSharedState()
    }

    func clearHistory() {
        appLockManager.clearHistory()
    }
}
