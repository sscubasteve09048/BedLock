//
//  HabitsView.swift
//  BedLock
//
//  Manage your custom morning habits — entirely user-defined. Each habit
//  contributes to the daily morning score and awards its own XP when
//  checked off on the Dashboard.
//
import SwiftUI

struct HabitsView: View {
    @Environment(HabitManager.self) private var habitManager

    @State private var viewModel: HabitsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                listContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Habits")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel?.beginAddingHabit()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = HabitsViewModel(habitManager: habitManager)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.isPresentingEditor ?? false },
            set: { viewModel?.isPresentingEditor = $0 }
        )) {
            if let viewModel {
                HabitEditorView(viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private func listContent(viewModel: HabitsViewModel) -> some View {
        if viewModel.habits.isEmpty {
            ContentUnavailableView(
                "No Habits Yet",
                systemImage: "checklist",
                description: Text("Add habits like stretching, drinking water, or journaling to build a full morning routine and earn extra XP.")
            )
        } else {
            List {
                Section {
                    ForEach(viewModel.habits) { habit in
                        habitRow(habit: habit, viewModel: viewModel)
                    }
                    .onDelete { viewModel.deleteHabits(at: $0) }
                    .onMove { viewModel.moveHabits(fromOffsets: $0, toOffset: $1) }
                } footer: {
                    Text("Inactive habits don't count toward your morning score or appear on the Dashboard.")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
        }
    }

    private func habitRow(habit: Habit, viewModel: HabitsViewModel) -> some View {
        Button {
            viewModel.beginEditingHabit(habit)
        } label: {
            HStack {
                Image(systemName: habit.iconName)
                    .foregroundStyle(habit.isActive ? Color.accentColor : Color.secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .foregroundStyle(.primary)
                    Text("+\(habit.xpValue) XP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { habit.isActive },
                    set: { _ in viewModel.toggleActive(habit) }
                ))
                .labelsHidden()
            }
        }
        .buttonStyle(.plain)
    }
}

private struct HabitEditorView: View {
    @Bindable var viewModel: HabitsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Name (e.g. Drink Water)", text: $viewModel.draftName)
                    Stepper("XP Value: \(viewModel.draftXPValue)", value: $viewModel.draftXPValue, in: 1...100, step: 5)
                }
                Section("Icon") {
                    iconGrid
                }
            }
            .navigationTitle(viewModel.editingHabit == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveDraft()
                    }
                    .disabled(!viewModel.canSaveDraft)
                }
            }
        }
    }

    private var iconGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
            ForEach(HabitIconOption.allCases) { option in
                Button {
                    viewModel.draftIconName = option.rawValue
                } label: {
                    Image(systemName: option.rawValue)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(
                            viewModel.draftIconName == option.rawValue
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .foregroundStyle(
                            viewModel.draftIconName == option.rawValue ? Color.accentColor : Color.primary
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        HabitsView()
    }
    .environment(HabitManager(persistence: PersistenceService()))
}
