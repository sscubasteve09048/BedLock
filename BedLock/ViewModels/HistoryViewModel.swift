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

    private let gamificationManager: GamificationManager

    init(gamificationManager: GamificationManager) {
        self.gamificationManager = gamificationManager
    }

    var entries: [UnlockHistoryEntry] {
        gamificationManager.history
    }

    var successCount: Int {
        entries.filter(\.wasSuccessful).count
    }

    var averageConfidence: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.reduce(0) { $0 + $1.confidence } / Double(entries.count)
    }

    func refresh() {
        gamificationManager.syncWithSharedState()
    }

    func clearHistory() {
        gamificationManager.clearHistory()
    }
}
