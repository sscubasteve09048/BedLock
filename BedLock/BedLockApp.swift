//
//  BedLockApp.swift
//  BedLock
//
//  App entry point. Constructs the shared service/manager graph once and injects
//  it down through the view hierarchy.
//
import SwiftUI

@main
struct BedLockApp: App {

    @State private var persistence: PersistenceService
    @State private var screenTimeManager: ScreenTimeManager
    @State private var appLockManager: AppLockManager
    @State private var scheduleManager: ScheduleManager

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let persistence = PersistenceService()
        let screenTimeManager = ScreenTimeManager()
        _persistence = State(initialValue: persistence)
        _screenTimeManager = State(initialValue: screenTimeManager)
        _appLockManager = State(initialValue: AppLockManager(screenTimeManager: screenTimeManager, persistence: persistence))
        _scheduleManager = State(initialValue: ScheduleManager(persistence: persistence))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(persistence)
                .environment(screenTimeManager)
                .environment(appLockManager)
                .environment(scheduleManager)
                .environment(AppDependencies.shared.router)
                .task {
                    // Re-register the DeviceActivity schedule on launch in case
                    // the user edited it while the app was terminated (e.g. via
                    // Shortcuts automation is not supported, but this keeps the
                    // schedule accurate after OS updates or reinstalls).
                    scheduleManager.applySchedule(persistence.loadSchedule())
                    _ = await NotificationService.shared.requestAuthorization()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        appLockManager.syncWithSharedState()
                        screenTimeManager.refreshAuthorizationStatus()
                    }
                }
        }
    }
}
