//
//  ScheduleManager.swift
//  BedLock
//
//  Registers the user's morning schedule as repeating local notifications
//  (`UNCalendarNotificationTrigger`) — a fully public, free API that requires
//  no Apple Developer Program enrollment or entitlement. iOS delivers these
//  even if BedLock isn't running, on each selected weekday at the chosen time.
//
//  This intentionally does not attempt to restrict any other app on the
//  device — that's not something a free-signed app is able to do. Pair this
//  reminder with iOS's native Screen Time → Downtime feature (configured
//  directly in Settings, also free) for the actual "locking" behavior. See
//  FREE_LOCKING.md for the full setup.
//
import Foundation
import UserNotifications
import Observation

@MainActor
@Observable
final class ScheduleManager {

    private static let identifierPrefix = "bedlock.morningReminder."

    private let persistence: PersistenceService

    init(persistence: PersistenceService) {
        self.persistence = persistence
    }

    private static func identifier(for day: Weekday) -> String {
        "\(identifierPrefix)\(day.rawValue)"
    }

    private static var allIdentifiers: [String] {
        Weekday.allCases.map(identifier(for:))
    }

    /// (Re)registers the repeating reminder notifications using the given
    /// schedule. Safe to call any time the user edits their schedule; it
    /// replaces any previously registered notifications.
    func applySchedule(_ schedule: ScheduleModel) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.allIdentifiers)

        guard schedule.isEnabled, !schedule.activeDays.isEmpty else { return }

        for day in schedule.activeDays {
            var components = DateComponents()
            components.hour = schedule.startHour
            components.minute = schedule.startMinute
            components.weekday = day.rawValue

            let content = UNMutableNotificationContent()
            content.title = "Good morning!"
            content.body = "Time to verify your bed and keep your streak going."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: Self.identifier(for: day),
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    func stopSchedule() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Self.allIdentifiers)
    }
}
