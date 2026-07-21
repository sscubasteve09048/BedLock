//
//  PersistenceService.swift
//  BedLock
//
//  Centralizes all local persistence using plain `UserDefaults`. BedLock is a
//  single-target app with no extension process to share state with, so there's
//  no need for an App Group container or any Screen Time entitlement here —
//  everything in this file works on a completely free Apple ID with no
//  Developer Program enrollment required.
//
import Foundation
import Observation

/// Marked `@Observable` (even though its own stored properties rarely change)
/// solely so it can be injected via SwiftUI's `.environment(_:)` modifier
/// alongside the other manager types.
@Observable
final class PersistenceService {

    private enum Keys {
        static let schedule = "bedlock.schedule"
        static let history = "bedlock.history"
        static let lastVerificationDate = "bedlock.lastVerificationDate"
        static let isRestrictionActive = "bedlock.isRestrictionActive"
        static let verificationThreshold = "bedlock.verificationThreshold"
    }

    private let defaults: UserDefaults

    init() {
        self.defaults = .standard
    }

    // MARK: - Schedule

    func loadSchedule() -> ScheduleModel {
        guard let data = defaults.data(forKey: Keys.schedule),
              let decoded = try? JSONDecoder().decode(ScheduleModel.self, from: data) else {
            return .default
        }
        return decoded
    }

    func saveSchedule(_ schedule: ScheduleModel) {
        guard let data = try? JSONEncoder().encode(schedule) else { return }
        defaults.set(data, forKey: Keys.schedule)
    }

    // MARK: - History

    func loadHistory() -> [UnlockHistoryEntry] {
        guard let data = defaults.data(forKey: Keys.history),
              let decoded = try? JSONDecoder().decode([UnlockHistoryEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    func saveHistory(_ history: [UnlockHistoryEntry]) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Keys.history)
    }

    func appendHistoryEntry(_ entry: UnlockHistoryEntry) {
        var history = loadHistory()
        history.insert(entry, at: 0)
        // Keep the last 200 entries so storage doesn't grow unbounded.
        if history.count > 200 {
            history = Array(history.prefix(200))
        }
        saveHistory(history)
    }

    // MARK: - Verification state

    var lastVerificationDate: Date? {
        get { defaults.object(forKey: Keys.lastVerificationDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastVerificationDate) }
    }

    /// Tracks BedLock's own notion of "locked" purely for the Dashboard/History
    /// UI and habit-tracking — it does not itself restrict any other app. Real
    /// app blocking is handled by iOS's native Screen Time Downtime feature,
    /// configured directly in Settings (see FREE_LOCKING.md).
    var isRestrictionActive: Bool {
        get { defaults.bool(forKey: Keys.isRestrictionActive) }
        set { defaults.set(newValue, forKey: Keys.isRestrictionActive) }
    }

    var verificationThreshold: Double {
        get {
            let stored = defaults.double(forKey: Keys.verificationThreshold)
            // 0.6 is a more realistic default for the free heuristic verifier
            // than a stricter value — Apple's general-purpose scene classifier
            // rarely reports very high confidence even for a clear match, and
            // treating this as a hard security gate isn't the goal; catching
            // an obviously-not-a-bed photo is. Raise it in Settings if you
            // want stricter checking, especially once a custom-trained model
            // is in place (see CoreMLBedVerificationService.swift).
            return stored == 0 ? 0.6 : stored
        }
        set { defaults.set(newValue, forKey: Keys.verificationThreshold) }
    }
}
