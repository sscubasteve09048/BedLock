//
//  PersistenceService.swift
//  BedLock
//
//  Centralizes all local persistence. Uses an App Group `UserDefaults` suite so
//  that both the main app and the `BedLockMonitorExtension` (DeviceActivityMonitor
//  target) read/write the same schedule, app selection, lock state, and history.
//
//  Replace `appGroupIdentifier` with your own App Group ID configured in both
//  targets' Signing & Capabilities tab before building.
//
import Foundation
import FamilyControls
import Observation

/// Marked `@Observable` (even though its own stored properties rarely change)
/// solely so it can be injected via SwiftUI's `.environment(_:)` modifier
/// alongside the other manager types.
@Observable
final class PersistenceService {

    static let appGroupIdentifier = "group.com.bedlock.shared"

    private enum Keys {
        static let schedule = "bedlock.schedule"
        static let appSelection = "bedlock.appSelection"
        static let history = "bedlock.history"
        static let lastVerificationDate = "bedlock.lastVerificationDate"
        static let isRestrictionActive = "bedlock.isRestrictionActive"
        static let verificationThreshold = "bedlock.verificationThreshold"
    }

    private let defaults: UserDefaults

    init() {
        self.defaults = UserDefaults(suiteName: Self.appGroupIdentifier) ?? .standard
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

    // MARK: - App selection

    func loadAppSelection() -> AppSelectionModel {
        guard let data = defaults.data(forKey: Keys.appSelection),
              let decoded = try? JSONDecoder().decode(AppSelectionModel.self, from: data) else {
            return .default
        }
        return decoded
    }

    func saveAppSelection(_ selection: AppSelectionModel) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: Keys.appSelection)
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

    var isRestrictionActive: Bool {
        get { defaults.bool(forKey: Keys.isRestrictionActive) }
        set { defaults.set(newValue, forKey: Keys.isRestrictionActive) }
    }

    var verificationThreshold: Double {
        get {
            let stored = defaults.double(forKey: Keys.verificationThreshold)
            return stored == 0 ? 0.85 : stored
        }
        set { defaults.set(newValue, forKey: Keys.verificationThreshold) }
    }
}
