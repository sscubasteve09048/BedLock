//
//  DailyProgress.swift
//  BedLock
//
//  One record per calendar day, aggregating that day's bed verification and
//  habit completions — the backing data for the morning score, streak,
//  calendar view, and monthly stats.
//
import Foundation

struct DailyProgress: Codable, Equatable {
    /// Normalized to the start of the day (midnight, local time) so a single
    /// record per calendar day is guaranteed regardless of what time
    /// verification happened.
    let dayStart: Date

    var bedVerified: Bool
    var bedConfidence: Double?
    var completedHabitIDs: Set<UUID>
    var xpEarned: Int

    init(dayStart: Date, bedVerified: Bool = false, bedConfidence: Double? = nil, completedHabitIDs: Set<UUID> = [], xpEarned: Int = 0) {
        self.dayStart = dayStart
        self.bedVerified = bedVerified
        self.bedConfidence = bedConfidence
        self.completedHabitIDs = completedHabitIDs
        self.xpEarned = xpEarned
    }

    static func startOfDay(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Morning score out of 100: bed verification counts as its own share of
    /// the total, split with whatever active habits exist. If there are no
    /// active habits at all, the score is simply 100 for a verified bed and
    /// 0 otherwise — the core feature works identically with zero habits
    /// configured.
    func score(bedXP: Int, activeHabits: [Habit]) -> Int {
        let habitMax = activeHabits.reduce(0) { $0 + $1.xpValue }
        let maxPossible = bedXP + habitMax
        guard maxPossible > 0 else { return 0 }

        let earnedFromBed = bedVerified ? bedXP : 0
        let earnedFromHabits = activeHabits
            .filter { completedHabitIDs.contains($0.id) }
            .reduce(0) { $0 + $1.xpValue }

        let percentage = Double(earnedFromBed + earnedFromHabits) / Double(maxPossible)
        return Int((percentage * 100).rounded())
    }
}
