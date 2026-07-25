//
//  DashboardViewModel.swift
//  BedLock
//
//  Drives the Dashboard screen: today's morning score, level/XP, streak,
//  today's habit checklist, quests, and the verification entry point.
//
import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {

    let gamificationManager: GamificationManager
    let habitManager: HabitManager
    private let persistence: PersistenceService

    var schedule: ScheduleModel
    var showingVerification = false

    init(gamificationManager: GamificationManager, habitManager: HabitManager, persistence: PersistenceService) {
        self.gamificationManager = gamificationManager
        self.habitManager = habitManager
        self.persistence = persistence
        self.schedule = persistence.loadSchedule()
    }

    var isBedVerifiedToday: Bool { gamificationManager.isBedVerifiedToday }
    var todayScore: Int { gamificationManager.todayScore }
    var level: LevelInfo { gamificationManager.level }
    var currentStreak: Int { gamificationManager.currentStreak }
    var longestStreak: Int { gamificationManager.longestStreak }
    var activeHabits: [Habit] { gamificationManager.activeHabits }
    var dailyQuest: QuestProgress { gamificationManager.dailyQuest }
    var weeklyChallenge: QuestProgress { gamificationManager.weeklyChallenge }

    var lastVerificationText: String {
        guard let date = gamificationManager.lastVerificationDate else {
            return "No verification yet"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Last verified \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    func isHabitCompleted(_ habit: Habit) -> Bool {
        gamificationManager.isHabitCompletedToday(habit)
    }

    func toggleHabit(_ habit: Habit) {
        gamificationManager.toggleHabit(habit)
    }

    func refresh() {
        gamificationManager.syncWithSharedState()
        schedule = persistence.loadSchedule()
    }

    func beginVerification() {
        showingVerification = true
    }
}
