//
//  HabitsViewModel.swift
//  BedLock
//
//  Drives the Habits management screen: add, edit, delete, reorder.
//
import Foundation
import Observation

@MainActor
@Observable
final class HabitsViewModel {

    private let habitManager: HabitManager

    var isPresentingEditor = false
    var editingHabit: Habit?

    var draftName: String = ""
    var draftIconName: String = HabitIconOption.checkmark.rawValue
    var draftXPValue: Int = 10

    init(habitManager: HabitManager) {
        self.habitManager = habitManager
    }

    var habits: [Habit] {
        habitManager.habits
    }

    func beginAddingHabit() {
        editingHabit = nil
        draftName = ""
        draftIconName = HabitIconOption.checkmark.rawValue
        draftXPValue = 10
        isPresentingEditor = true
    }

    func beginEditingHabit(_ habit: Habit) {
        editingHabit = habit
        draftName = habit.name
        draftIconName = habit.iconName
        draftXPValue = habit.xpValue
        isPresentingEditor = true
    }

    var canSaveDraft: Bool {
        !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveDraft() {
        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if var habit = editingHabit {
            habit.name = trimmedName
            habit.iconName = draftIconName
            habit.xpValue = max(draftXPValue, 1)
            habitManager.updateHabit(habit)
        } else {
            habitManager.addHabit(name: trimmedName, iconName: draftIconName, xpValue: max(draftXPValue, 1))
        }
        isPresentingEditor = false
    }

    func toggleActive(_ habit: Habit) {
        var updated = habit
        updated.isActive.toggle()
        habitManager.updateHabit(updated)
    }

    func deleteHabits(at offsets: IndexSet) {
        for index in offsets {
            habitManager.deleteHabit(habits[index])
        }
    }

    func moveHabits(fromOffsets source: IndexSet, toOffset destination: Int) {
        habitManager.moveHabit(fromOffsets: source, toOffset: destination)
    }
}
