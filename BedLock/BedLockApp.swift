//
//  BedLockApp.swift
//  BedLock
//
//  App entry point. Constructs the shared service/manager graph once and
//  injects it down through the view hierarchy. Note there's no Screen Time /
//  Family Controls manager here — BedLock is a single-target app that works
//  entirely on a free Apple ID. Pair it with iOS's native Screen Time →
//  Downtime feature for actual app restriction (see FREE_LOCKING.md).
//
import SwiftUI

@main
struct BedLockApp: App {

    @State private var persistence: PersistenceService
    @State private var appLockManager: AppLockManager
    @State private var scheduleManager: ScheduleManager

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let persistence = PersistenceService()
        _persistence = State(initialValue: persistence)
        _appLockManager = State(initialValue: AppLockManager(persistence: persistence))
        _scheduleManager = State(initialValue: ScheduleManager(persistence: persistence))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(persistence)
                .environment(appLockManager)
                .environment(scheduleManager)
                .environment(AppDependencies.shared.router)
                .task {
                    // Re-register the reminder notifications on launch in case
                    // the user edited the schedule while the app was terminated.
                    scheduleManager.applySchedule(persistence.loadSchedule())
                    _ = await NotificationService.shared.requestAuthorization()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        appLockManager.syncWithSharedState()
                    }
                }
        }
    }
}
