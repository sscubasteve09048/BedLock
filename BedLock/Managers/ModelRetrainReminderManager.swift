//
//  ModelRetrainReminderManager.swift
//  BedLock
//
//  Schedules a local notification nudging you to recollect photos and
//  retrain your custom bed-classifier model (see TRAIN_CUSTOM_MODEL.md) —
//  useful because lighting, room layout, or bedding changes over time can
//  quietly degrade a model trained months ago. Uses a plain
//  `UNTimeIntervalNotificationTrigger`, a fully public/free API.
//
//  The reminder is re-armed every time the app becomes active (see
//  BedLockApp.swift), computing "time remaining until the interval elapses"
//  from `lastModelTrainingDate` each time — simpler and more robust than
//  trying to maintain one long-lived repeating trigger across app launches.
//
import Foundation
import UserNotifications
import Observation

@MainActor
@Observable
final class ModelRetrainReminderManager {

    private static let identifier = "bedlock.retrainReminder"

    private let persistence: PersistenceService

    init(persistence: PersistenceService) {
        self.persistence = persistence
    }

    /// (Re)registers the reminder based on current settings. Safe to call any
    /// time the user changes the toggle/interval, or on every app launch.
    func applyReminderSettings() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])

        guard persistence.retrainReminderEnabled else { return }

        let intervalDays = max(persistence.retrainIntervalDays, 1)
        let fullInterval = TimeInterval(intervalDays) * 86_400
        let elapsed = persistence.lastModelTrainingDate.map { Date().timeIntervalSince($0) } ?? 0
        let secondsUntilFire = max(fullInterval - elapsed, 60)

        let content = UNMutableNotificationContent()
        content.title = "Time to retrain BedLock?"
        content.body = "Lighting and bedding change over time — recollect a few photos and retrain your bed-recognition model for the best accuracy. See TRAIN_CUSTOM_MODEL.md."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secondsUntilFire, repeats: false)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        center.add(request)
    }

    /// Called when the user taps "I Just Retrained" — resets the clock and
    /// reschedules the reminder for a full interval from now.
    func markRetrainedNow() {
        persistence.lastModelTrainingDate = Date()
        applyReminderSettings()
    }

    func stopReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }

    /// How many days ago the model was last (self-reported) retrained, for
    /// display in Settings. `nil` if never recorded.
    var daysSinceLastTraining: Int? {
        guard let last = persistence.lastModelTrainingDate else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day
    }
}
