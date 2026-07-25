//
//  LevelInfo.swift
//  BedLock
//
//  Converts a lifetime XP total into a level, and figures out progress
//  toward the next one. Uses a simple increasing-cost curve (each level
//  costs more XP than the last) so early levels come quickly and it takes
//  longer as you go, without needing any external tuning data.
//
import Foundation

struct LevelInfo: Equatable {
    let level: Int
    let xpIntoLevel: Int
    let xpNeededForLevel: Int
    let totalXP: Int

    var progress: Double {
        guard xpNeededForLevel > 0 else { return 1 }
        return Double(xpIntoLevel) / Double(xpNeededForLevel)
    }

    /// XP required to go from `level` to `level + 1`. Level 1 costs 100,
    /// level 2 costs 150, level 3 costs 200, etc. — a gentle linear ramp.
    private static func cost(ofLevel level: Int) -> Int {
        100 + (level - 1) * 50
    }

    static func from(totalXP: Int) -> LevelInfo {
        var remaining = max(totalXP, 0)
        var level = 1
        while remaining >= cost(ofLevel: level) {
            remaining -= cost(ofLevel: level)
            level += 1
        }
        return LevelInfo(
            level: level,
            xpIntoLevel: remaining,
            xpNeededForLevel: cost(ofLevel: level),
            totalXP: totalXP
        )
    }
}
