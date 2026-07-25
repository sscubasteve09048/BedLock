//
//  HabitManager.swift
//  BedLock
//
//  CRUD for the user's custom habits. BedLock ships with none preset — every
//  habit shown anywhere in the app is one the user created themselves.
//
import Foundation
import Observation

@MainActor
@Observable
final class HabitManager {

    private(set) var habits: [Habit]

    private let persistence: PersistenceService

    init(persistence: PersistenceService) {
        self.persistence = persistence
        self.habits = persistence.loadHabits().sorted { $0.sortOrder < $1.sortOrder }
    }

    var activeHabits: [Habit] {
        habits.filter(\.isActive)
    }

    func addHabit(name: String, iconName: String, xpValue: Int) {
        let habit = Habit(
            name: name,
            iconName: iconName,
            xpValue: xpValue,
            isActive: true,
            sortOrder: (habits.map(\.sortOrder).max() ?? -1) + 1
        )
        habits.append(habit)
        persist()
    }

    func updateHabit(_ habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index] = habit
        persist()
    }

    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        persist()
    }

    func moveHabit(fromOffsets source: IndexSet, toOffset destination: Int) {
        habits.move(fromOffsets: source, toOffset: destination)
        for (index, _) in habits.enumerated() {
            habits[index].sortOrder = index
        }
        persist()
    }

    private func persist() {
        persistence.saveHabits(habits)
    }
}
