//
//  ScheduleView.swift
//  BedLock
//
//  Lets the user configure start/end time and active days for the automatic
//  morning lock.
//
//  NOTE: Each Form section is broken out into its own @ViewBuilder function.
//  A single `var body` containing this many nested Sections/Pickers/Bindings
//  is enough to make the Swift type-checker time out ("unable to type-check
//  this expression in reasonable time") — splitting it up gives the compiler
//  much smaller expressions to solve individually.
//
import SwiftUI

struct ScheduleView: View {
    @Environment(PersistenceService.self) private var persistence
    @Environment(ScheduleManager.self) private var scheduleManager

    @State private var viewModel: ScheduleViewModel?

    var body: some View {
        Group {
            if let viewModel {
                formContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = ScheduleViewModel(persistence: persistence, scheduleManager: scheduleManager)
            }
        }
        .alert("Schedule Saved", isPresented: Binding(
            get: { viewModel?.didSaveConfirmation ?? false },
            set: { viewModel?.didSaveConfirmation = $0 }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("BedLock will automatically lock your apps at the scheduled time on the days you selected.")
        }
    }

    @ViewBuilder
    private func formContent(viewModel: ScheduleViewModel) -> some View {
        Form {
            enableSection(viewModel: viewModel)
            startTimeSection(viewModel: viewModel)
            endTimeSection(viewModel: viewModel)
            activeDaysSection(viewModel: viewModel)
            saveSection(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func enableSection(viewModel: ScheduleViewModel) -> some View {
        Section {
            Toggle("Enable Morning Lock", isOn: bindingFor(viewModel).isEnabled)
        }
    }

    @ViewBuilder
    private func startTimeSection(viewModel: ScheduleViewModel) -> some View {
        Section("Start Time") {
            DatePicker(
                "Lock at",
                selection: bindingFor(viewModel).startTime,
                displayedComponents: .hourAndMinute
            )
        }
    }

    @ViewBuilder
    private func endTimeSection(viewModel: ScheduleViewModel) -> some View {
        Section {
            Toggle("Set an End Time", isOn: bindingFor(viewModel).hasEndTime)
            if viewModel.schedule.hasEndTime {
                DatePicker(
                    "Stop enforcing at",
                    selection: bindingFor(viewModel).endTime,
                    displayedComponents: .hourAndMinute
                )
            }
        } footer: {
            Text("If no end time is set, the lock stays active until you verify your bed is made, no matter how late in the day it is.")
        }
    }

    @ViewBuilder
    private func activeDaysSection(viewModel: ScheduleViewModel) -> some View {
        Section("Active Days") {
            ForEach(Weekday.allCases) { day in
                dayRow(day: day, viewModel: viewModel)
            }
        }
    }

    private func dayRow(day: Weekday, viewModel: ScheduleViewModel) -> some View {
        Button {
            viewModel.toggleDay(day)
        } label: {
            HStack {
                Text(day.fullName)
                    .foregroundStyle(.primary)
                Spacer()
                if viewModel.schedule.activeDays.contains(day) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    @ViewBuilder
    private func saveSection(viewModel: ScheduleViewModel) -> some View {
        Section {
            Button {
                viewModel.save()
            } label: {
                Text("Save Schedule")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    /// Small helper struct so nested bindings read cleanly in the Form above.
    private struct Bindings {
        var isEnabled: Binding<Bool>
        var startTime: Binding<Date>
        var hasEndTime: Binding<Bool>
        var endTime: Binding<Date>
    }

    private func bindingFor(_ viewModel: ScheduleViewModel) -> Bindings {
        Bindings(
            isEnabled: Binding(
                get: { viewModel.schedule.isEnabled },
                set: { viewModel.schedule.isEnabled = $0 }
            ),
            startTime: Binding(
                get: { viewModel.startTimeBinding },
                set: { viewModel.startTimeBinding = $0 }
            ),
            hasEndTime: Binding(
                get: { viewModel.schedule.hasEndTime },
                set: { viewModel.schedule.hasEndTime = $0 }
            ),
            endTime: Binding(
                get: { viewModel.endTimeBinding },
                set: { viewModel.endTimeBinding = $0 }
            )
        )
    }
}

#Preview {
    NavigationStack {
        ScheduleView()
    }
    .environment(PersistenceService())
    .environment(ScheduleManager(persistence: PersistenceService()))
}
