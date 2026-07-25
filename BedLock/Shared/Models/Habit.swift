//
//  Habit.swift
//  BedLock
//
//  A user-defined habit for the morning routine. Entirely custom — BedLock
//  ships with zero preset habits beyond the core bed-verification itself;
//  the user creates whatever they want tracked (examples: drink water,
//  stretch, journal — but genuinely anything).
//
import Foundation

struct Habit: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    /// SF Symbol name for display.
    var iconName: String
    /// XP awarded when this habit is checked off for the day. User-defined
    /// per habit so more effortful habits can be worth more.
    var xpValue: Int
    var isActive: Bool
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "checkmark.circle",
        xpValue: Int = 10,
        isActive: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.xpValue = xpValue
        self.isActive = isActive
        self.sortOrder = sortOrder
    }
}

/// A small curated set of SF Symbols offered when creating a habit, purely
/// to make the picker approachable — the name/XP value are still entirely
/// up to the user.
enum HabitIconOption: String, CaseIterable, Identifiable {
    case checkmark = "checkmark.circle"
    case water = "drop.fill"
    case book = "book.fill"
    case dumbbell = "dumbbell.fill"
    case figureRun = "figure.run"
    case figureStretch = "figure.flexibility"
    case pencil = "pencil"
    case sun = "sun.max.fill"
    case leaf = "leaf.fill"
    case heart = "heart.fill"
    case brain = "brain.head.profile"
    case sparkles = "sparkles"
    case alarm = "alarm.fill"
    case cup = "cup.and.saucer.fill"

    var id: String { rawValue }
}
