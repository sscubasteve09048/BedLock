//
//  Achievement.swift
//  BedLock
//
//  A small fixed catalog of unlockable badges. Rules are evaluated against
//  current stats (streak, total verifications, level) rather than stored
//  procedurally, so the catalog can grow over time without a migration.
//
import Foundation

struct Achievement: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let iconName: String

    /// Whether this achievement is unlocked given current stats.
    func isUnlocked(stats: AchievementStats) -> Bool {
        switch id {
        case "first_verification":
            return stats.totalVerifications >= 1
        case "streak_3":
            return stats.longestStreak >= 3
        case "streak_7":
            return stats.longestStreak >= 7
        case "streak_30":
            return stats.longestStreak >= 30
        case "streak_100":
            return stats.longestStreak >= 100
        case "level_5":
            return stats.level >= 5
        case "level_10":
            return stats.level >= 10
        case "century":
            return stats.totalVerifications >= 100
        case "perfect_week":
            return stats.hasPerfectWeek
        default:
            return false
        }
    }

    static let all: [Achievement] = [
        Achievement(id: "first_verification", title: "First Steps", description: "Verify your bed for the first time.", iconName: "star.fill"),
        Achievement(id: "streak_3", title: "Getting Started", description: "Reach a 3-day streak.", iconName: "flame"),
        Achievement(id: "streak_7", title: "One Week Strong", description: "Reach a 7-day streak.", iconName: "flame.fill"),
        Achievement(id: "streak_30", title: "Habit Formed", description: "Reach a 30-day streak.", iconName: "flame.circle.fill"),
        Achievement(id: "streak_100", title: "Unstoppable", description: "Reach a 100-day streak.", iconName: "crown.fill"),
        Achievement(id: "level_5", title: "Rising Star", description: "Reach Level 5.", iconName: "arrow.up.circle.fill"),
        Achievement(id: "level_10", title: "Veteran", description: "Reach Level 10.", iconName: "trophy.fill"),
        Achievement(id: "century", title: "Century Club", description: "Verify your bed 100 times total.", iconName: "medal.fill"),
        Achievement(id: "perfect_week", title: "Perfect Week", description: "Score 100 every day for a full week.", iconName: "checkmark.seal.fill"),
    ]
}

/// The inputs needed to evaluate every achievement's unlock rule, gathered
/// in one place so `GamificationManager` only has to build this once.
struct AchievementStats: Equatable {
    let totalVerifications: Int
    let longestStreak: Int
    let level: Int
    let hasPerfectWeek: Bool
}
