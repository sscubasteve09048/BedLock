//
//  SettingsView.swift
//  BedLock
//
//  Settings hub: navigation to Schedule/App Selection, permission status,
//  confidence threshold, and the large "Test Verification" button.
//
import SwiftUI

struct SettingsView: View {
    @Environment(PersistenceService.self) private var persistence
    @Environment(ScreenTimeManager.self) private var screenTimeManager

    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                Form {
                    Section {
                        NavigationLink {
                            ScheduleView()
                        } label: {
                            Label("Schedule", systemImage: "calendar.badge.clock")
                        }
                        NavigationLink {
                            AppSelectionView()
                        } label: {
                            Label("Apps", systemImage: "square.grid.2x2")
                        }
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Verification Threshold")
                                Spacer()
                                Text("\(Int(viewModel.threshold * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { viewModel.threshold },
                                    set: { viewModel.threshold = $0 }
                                ),
                                in: 0.5...0.99,
                                step: 0.01
                            )
                        }
                    } footer: {
                        Text("How confident BedLock's bed-detection must be before it unlocks your phone. Higher is stricter.")
                    }

                    Section {
                        permissionRow(title: "Screen Time", isGranted: screenTimeManager.authorizationStatus == .approved)
                        permissionRow(title: "Camera", isGranted: viewModel.cameraAuthorized)
                        permissionRow(title: "Notifications", isGranted: viewModel.notificationsAuthorized)
                    } header: {
                        Text("Permissions")
                    }

                    Section {
                        Button {
                            viewModel.beginTestVerification()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Test Verification", systemImage: "camera.viewfinder")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    } footer: {
                        Text("Locks your apps immediately (ignoring the schedule), opens the camera, and runs the exact same verification used every morning.")
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Settings")
        .task {
            if viewModel == nil {
                viewModel = SettingsViewModel(persistence: persistence, screenTimeManager: screenTimeManager)
            }
            await viewModel?.refreshPermissionStatuses()
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel?.showingTestVerification ?? false },
            set: { viewModel?.showingTestVerification = $0 }
        )) {
            CameraVerificationView(isTestMode: true)
        }
    }

    private func permissionRow(title: String, isGranted: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isGranted ? .green : .red)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(PersistenceService())
    .environment(ScreenTimeManager())
}
