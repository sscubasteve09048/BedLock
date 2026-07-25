//
//  Quest.swift
//  BedLock
//
//  Daily quests, weekly challenges, and monthly goals. These are computed
//  fresh from `DailyProgress` history rather than stored as separate state,
//  so there's nothing to migrate or get out of sync — the "quest" is just a
//  different lens on the same underlying data.
//
import Foundation

struct QuestProgress: Equatable {
    let title: String
    let detail: String
    let current: Int
    let target: Int
    let bonusXP: Int

    var isComplete: Bool { current >= target }
    var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1)
    }
}

enum QuestCalculator {

    /// Today's quest: verify your bed and complete every active habit.
    static func dailyQuest(today: DailyProgress?, activeHabits: [Habit], bedXP: Int) -> QuestProgress {
        let habitCount = activeHabits.count
        let target = 1 + habitCount // bed + each habit
        var current = 0
        if today?.bedVerified == true { current += 1 }
        if let today {
            current += activeHabits.filter { today.completedHabitIDs.contains($0.id) }.count
        }
        return QuestProgress(
            title: "Perfect Morning",
            detail: habitCount > 0 ? "Verify your bed and complete all \(habitCount) habits" : "Verify your bed",
            current: current,
            target: target,
            bonusXP: 15
        )
    }

    /// This week's challenge: verify your bed on at least 5 of the last 7 days
    /// (rolling week, Sunday-anchored to match Weekday numbering elsewhere).
    static func weeklyChallenge(records: [DailyProgress], calendar: Calendar = .current) -> QuestProgress {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let daysThisWeek = records.filter { $0.dayStart >= weekStart && $0.bedVerified }
        return QuestProgress(
            title: "Weekly Challenge",
            detail: "Verify your bed on 5 days this week",
            current: min(daysThisWeek.count, 5),
            target: 5,
            bonusXP: 50
        )
    }

    /// This month's goal: reach a target total XP earned within the current
    /// calendar month (a fixed, approachable target rather than scaling with
    /// level, so it stays legible).
    static func monthlyGoal(records: [DailyProgress], calendar: Calendar = .current) -> QuestProgress {
        let monthStart = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        let xpThisMonth = records
            .filter { $0.dayStart >= monthStart }
            .reduce(0) { $0 + $1.xpEarned }
        let target = 600
        return QuestProgress(
            title: "Monthly Goal",
            detail: "Earn \(target) XP this month",
            current: min(xpThisMonth, target),
            target: target,
            bonusXP: 100
        )
    }
}
