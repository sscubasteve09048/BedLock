//
//  SettingsView.swift
//  BedLock
//
//  Settings hub: navigation to Schedule, permission status, confidence
//  threshold, and the large "Test Verification" button.
//
//  NOTE: sections are split into small @ViewBuilder functions rather than one
//  large `body` — a single Form with this many Sections/Sliders/Bindings can
//  make the Swift type-checker time out.
//
import SwiftUI

struct SettingsView: View {
    @Environment(PersistenceService.self) private var persistence

    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                formContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Settings")
        .task {
            if viewModel == nil {
                viewModel = SettingsViewModel(persistence: persistence)
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

    @ViewBuilder
    private func formContent(viewModel: SettingsViewModel) -> some View {
        Form {
            navigationSection()
            thresholdSection(viewModel: viewModel)
            permissionsSection(viewModel: viewModel)
            testVerificationSection(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func navigationSection() -> some View {
        Section {
            NavigationLink {
                ScheduleView()
            } label: {
                Label("Schedule", systemImage: "calendar.badge.clock")
            }
        }
    }

    @ViewBuilder
    private func thresholdSection(viewModel: SettingsViewModel) -> some View {
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
            Text("How confident BedLock's bed-detection must be before it counts as a successful verification. Higher is stricter.")
        }
    }

    @ViewBuilder
    private func permissionsSection(viewModel: SettingsViewModel) -> some View {
        Section {
            permissionRow(title: "Camera", isGranted: viewModel.cameraAuthorized)
            permissionRow(title: "Notifications", isGranted: viewModel.notificationsAuthorized)
        } header: {
            Text("Permissions")
        }
    }

    @ViewBuilder
    private func testVerificationSection(viewModel: SettingsViewModel) -> some View {
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
            Text("Marks BedLock as locked immediately (ignoring the schedule), opens the camera, and runs the exact same verification used every morning.")
        }
    }

    private func permissionRow(title: String, isGranted: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isGranted ? Color.green : Color.red)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(PersistenceService())
}
