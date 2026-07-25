//
//  ProgressStatsViewModel.swift
//  BedLock
//
//  Drives the Progress screen: calendar view, monthly stats, and the
//  achievements/badges grid.
//
import Foundation
import Observation

@MainActor
@Observable
final class ProgressStatsViewModel {

    private let gamificationManager: GamificationManager

    /// The month currently displayed in the calendar (always normalized to
    /// the 1st of that month).
    var displayedMonth: Date

    init(gamificationManager: GamificationManager) {
        self.gamificationManager = gamificationManager
        let calendar = Calendar.current
        self.displayedMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
    }

    var currentStreak: Int { gamificationManager.currentStreak }
    var longestStreak: Int { gamificationManager.longestStreak }
    var completionPercentageThisMonth: Double { gamificationManager.completionPercentageThisMonth }
    var xpEarnedThisMonth: Int { gamificationManager.xpEarnedThisMonth }
    var achievements: [(achievement: Achievement, isUnlocked: Bool)] { gamificationManager.achievements }
    var monthlyGoal: QuestProgress { gamificationManager.monthlyGoal }

    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    /// Days to render in the calendar grid, padded with `nil` for leading
    /// empty cells so the first real day lines up under the correct weekday.
    var calendarDays: [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: displayedMonth)
        let leadingBlanks = Array(repeating: Date?.none, count: firstWeekday - 1)
        let days = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: displayedMonth)
        }
        return leadingBlanks + days.map { $0 }
    }

    func status(for day: Date) -> DayStatus {
        guard let record = gamificationManager.record(for: day) else { return .none }
        if record.bedVerified { return .verified }
        return .attempted
    }

    func goToPreviousMonth() {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = newMonth
    }

    func goToNextMonth() {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        let calendar = Calendar.current
        // Don't allow navigating past the current month.
        if newMonth <= (calendar.dateInterval(of: .month, for: Date())?.start ?? Date()) {
            displayedMonth = newMonth
        }
    }

    enum DayStatus {
        case none
        case attempted
        case verified
    }
}
