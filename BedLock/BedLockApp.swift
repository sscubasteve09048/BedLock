//
//  BedLockApp.swift
//  BedLock
//
//  App entry point. Constructs the shared service/manager graph once and
//  injects it down through the view hierarchy. Note there's no Screen Time /
//  Family Controls manager here — BedLock is a single-target app that works
//  entirely on a free Apple ID and cannot lock or unlock other apps. Pair it
//  with iOS's native Screen Time → Downtime feature for actual app
//  restriction (see FREE_LOCKING.md); BedLock itself tracks your own
//  verification streak, XP, and habits.
//
import SwiftUI

@main
struct BedLockApp: App {

    @State private var persistence: PersistenceService
    @State private var habitManager: HabitManager
    @State private var gamificationManager: GamificationManager
    @State private var scheduleManager: ScheduleManager
    @State private var retrainReminderManager: ModelRetrainReminderManager

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let persistence = PersistenceService()
        let habitManager = HabitManager(persistence: persistence)
        _persistence = State(initialValue: persistence)
        _habitManager = State(initialValue: habitManager)
        _gamificationManager = State(initialValue: GamificationManager(persistence: persistence, habitManager: habitManager))
        _scheduleManager = State(initialValue: ScheduleManager(persistence: persistence))
        _retrainReminderManager = State(initialValue: ModelRetrainReminderManager(persistence: persistence))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(persistence)
                .environment(habitManager)
                .environment(gamificationManager)
                .environment(scheduleManager)
                .environment(retrainReminderManager)
                .environment(AppDependencies.shared.router)
                .task {
                    // Re-register the reminder notifications on launch in case
                    // the user edited the schedule while the app was terminated.
                    scheduleManager.applySchedule(persistence.loadSchedule())
                    retrainReminderManager.applyReminderSettings()
                    _ = await NotificationService.shared.requestAuthorization()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        gamificationManager.syncWithSharedState()
                        retrainReminderManager.applyReminderSettings()
                    }
                }
        }
    }
}
