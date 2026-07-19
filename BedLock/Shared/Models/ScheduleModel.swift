//
//  ScheduleModel.swift
//  BedLock
//
//  Defines the user-configurable morning lock schedule.
//

import Foundation

/// Represents a single weekday, mapped to `Calendar` weekday numbering (1 = Sunday ... 7 = Saturday).
enum Weekday: Int, CaseIterable, Codable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

/// The user's configuration for when BedLock should automatically restrict apps.
struct ScheduleModel: Codable, Equatable {
    /// Hour/minute the lock engages (e.g. 7:00 AM).
    var startHour: Int
    var startMinute: Int

    /// Whether an end time is configured. If false, the lock stays active until verification succeeds,
    /// regardless of time of day.
    var hasEndTime: Bool
    var endHour: Int
    var endMinute: Int

    /// Days of the week the schedule is active.
    var activeDays: Set<Weekday>

    /// Whether the schedule is enabled at all.
    var isEnabled: Bool

    static let `default` = ScheduleModel(
        startHour: 7,
        startMinute: 0,
        hasEndTime: false,
        endHour: 9,
        endMinute: 0,
        activeDays: Set(Weekday.allCases),
        isEnabled: true
    )

    /// A `DateComponents` representation of the start time, suitable for `DeviceActivitySchedule`.
    var startComponents: DateComponents {
        DateComponents(hour: startHour, minute: startMinute)
    }

    /// A `DateComponents` representation of the end time.
    var endComponents: DateComponents {
        if hasEndTime {
            return DateComponents(hour: endHour, minute: endMinute)
        }
        // If no explicit end time, default the DeviceActivity window to just before midnight
        // so the restriction persists until the user verifies, regardless of time of day.
        return DateComponents(hour: 23, minute: 59)
    }

    /// Human-readable summary, e.g. "7:00 AM · Mon, Tue, Wed, Thu, Fri".
    var summary: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        let time = Self.timeString(hour: startHour, minute: startMinute)
        let days = Weekday.allCases
            .filter { activeDays.contains($0) }
            .map(\.shortName)
            .joined(separator: ", ")
        return "\(time) · \(days.isEmpty ? "No days selected" : days)"
    }

    static func timeString(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let calendar = Calendar.current
        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
