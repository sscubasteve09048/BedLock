//
//  ScheduleView.swift
//  BedLock
//
//  Lets the user configure start/end time and active days for the automatic
//  morning lock.
//
import SwiftUI

struct ScheduleView: View {
    @Environment(PersistenceService.self) private var persistence
    @Environment(ScheduleManager.self) private var scheduleManager

    @State private var viewModel: ScheduleViewModel?

    var body: some View {
        Group {
            if let viewModel {
                Form {
                    Section {
                        Toggle("Enable Morning Lock", isOn: bindingFor(viewModel).isEnabled)
                    }

                    Section("Start Time") {
                        DatePicker(
                            "Lock at",
                            selection: bindingFor(viewModel).startTime,
                            displayedComponents: .hourAndMinute
                        )
                    }

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

                    Section("Active Days") {
                        ForEach(Weekday.allCases) { day in
                            Button {
                                viewModel.toggleDay(day)
                            } label: {
                                HStack {
                                    Text(day.fullName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if viewModel.schedule.activeDays.contains(day) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.accentColor)
                                    }
                                }
                            }
                        }
                    }

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
