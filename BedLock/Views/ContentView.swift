//
//  ContentView.swift
//  BedLock
//
//  Root tab container. Each tab hosts its own NavigationStack per Apple's
//  recommended tab-bar navigation pattern.
//
import SwiftUI

struct ContentView: View {
    @Environment(AppRouter.self) private var router
    @State private var showingVerificationFromIntent = false

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "bed.double.fill") {
                NavigationStack {
                    DashboardView()
                }
            }

            Tab("Progress", systemImage: "chart.bar.fill") {
                NavigationStack {
                    ProgressStatsView()
                }
            }

            Tab("History", systemImage: "clock.arrow.circlepath") {
                NavigationStack {
                    HistoryView()
                }
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .onChange(of: router.wantsToPresentVerification) { _, wantsToPresent in
            if wantsToPresent {
                showingVerificationFromIntent = true
                router.wantsToPresentVerification = false
            }
        }
        .fullScreenCover(isPresented: $showingVerificationFromIntent) {
            CameraVerificationView(isTestMode: false)
        }
    }
}

#Preview {
    let persistence = PersistenceService()
    let habitManager = HabitManager(persistence: persistence)
    return ContentView()
        .environment(persistence)
        .environment(habitManager)
        .environment(GamificationManager(persistence: persistence, habitManager: habitManager))
        .environment(ScheduleManager(persistence: persistence))
        .environment(AppRouter())
}
