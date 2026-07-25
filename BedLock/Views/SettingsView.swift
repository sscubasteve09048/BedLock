//
//  SettingsView.swift
//  BedLock
//
//  Settings hub: navigation to Schedule, permission status, confidence
//  threshold, custom bed-recognition model status/import/retrain reminder,
//  and the large "Test Verification" button.
//
//  NOTE: sections are split into small @ViewBuilder functions rather than one
//  large `body` — a single Form with this many Sections/Sliders/Bindings can
//  make the Swift type-checker time out.
//
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(PersistenceService.self) private var persistence
    @Environment(ModelRetrainReminderManager.self) private var retrainReminderManager

    @State private var viewModel: SettingsViewModel?

    /// Accepted file types for the model importer: both the raw `.mlmodel`
    /// single-file format and the newer `.mlpackage` bundle format that the
    /// Colab training script in TRAIN_CUSTOM_MODEL.md produces.
    private var modelContentTypes: [UTType] {
        [
            UTType(filenameExtension: "mlmodel") ?? .data,
            UTType(filenameExtension: "mlpackage") ?? .package,
        ]
    }

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
                viewModel = SettingsViewModel(persistence: persistence, retrainReminderManager: retrainReminderManager)
            }
            await viewModel?.refreshPermissionStatuses()
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel?.showingTestVerification ?? false },
            set: { viewModel?.showingTestVerification = $0 }
        )) {
            CameraVerificationView(isTestMode: true)
        }
        .fileImporter(
            isPresented: Binding(
                get: { viewModel?.showingModelImporter ?? false },
                set: { viewModel?.showingModelImporter = $0 }
            ),
            allowedContentTypes: modelContentTypes
        ) { result in
            Task { await viewModel?.handleModelImportResult(result) }
        }
        .alert(
            "Couldn't Import Model",
            isPresented: Binding(
                get: { viewModel?.modelImportErrorMessage != nil },
                set: { if !$0 { viewModel?.modelImportErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel?.modelImportErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private func formContent(viewModel: SettingsViewModel) -> some View {
        Form {
            navigationSection()
            thresholdSection(viewModel: viewModel)
            customModelSection(viewModel: viewModel)
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
            NavigationLink {
                HabitsView()
            } label: {
                Label("Habits", systemImage: "checklist")
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
    private func customModelSection(viewModel: SettingsViewModel) -> some View {
        Section {
            modelStatusRow(viewModel: viewModel)
            importModelButton(viewModel: viewModel)
            if viewModel.isModelImported {
                Button("Remove Imported Model", role: .destructive) {
                    viewModel.removeImportedModel()
                }
            }
            if viewModel.isCustomModelInstalled {
                Toggle("Remind Me to Retrain", isOn: Binding(
                    get: { viewModel.retrainReminderEnabled },
                    set: { viewModel.retrainReminderEnabled = $0 }
                ))
                if viewModel.retrainReminderEnabled {
                    retrainIntervalPicker(viewModel: viewModel)
                }
                Button("I Just Retrained") {
                    viewModel.markRetrainedNow()
                }
            }
        } header: {
            Text("Bed-Recognition Model")
        } footer: {
            Text(customModelFooterText(viewModel: viewModel))
        }
    }

    private func modelStatusRow(viewModel: SettingsViewModel) -> some View {
        HStack {
            Text("Status")
            Spacer()
            if viewModel.isModelImported {
                Label("Imported Model", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color.green)
            } else if viewModel.isCustomModelInstalled {
                Label("Bundled Model", systemImage: "checkmark.seal")
                    .foregroundStyle(Color.green)
            } else {
                Label("Built-in Heuristic", systemImage: "wand.and.stars")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func importModelButton(viewModel: SettingsViewModel) -> some View {
        Button {
            viewModel.beginModelImport()
        } label: {
            HStack {
                Label("Import Custom Model", systemImage: "square.and.arrow.down")
                if viewModel.isImportingModel {
                    Spacer()
                    ProgressView()
                }
            }
        }
        .disabled(viewModel.isImportingModel)
    }

    private func retrainIntervalPicker(viewModel: SettingsViewModel) -> some View {
        Picker("Remind Every", selection: Binding(
            get: { viewModel.retrainIntervalDays },
            set: { viewModel.retrainIntervalDays = $0 }
        )) {
            Text("30 Days").tag(30)
            Text("60 Days").tag(60)
            Text("90 Days").tag(90)
            Text("180 Days").tag(180)
        }
    }

    private func customModelFooterText(viewModel: SettingsViewModel) -> String {
        if viewModel.isModelImported {
            let trained = viewModel.daysSinceLastTraining.map { "Trained \($0) day\($0 == 1 ? "" : "s") ago. " } ?? ""
            return trained + "Imported directly on this device — retraining again just needs a re-import here, no app reinstall required."
        } else if viewModel.isCustomModelInstalled {
            return "This model was baked into the app at build time, so updating it means rebuilding and reinstalling the app — or just tap Import Custom Model above to swap one in without any of that."
        } else {
            return "You're using the built-in Vision heuristic, which works but isn't as accurate as a model trained on your own bed. See TRAIN_CUSTOM_MODEL.md for a free, no-Mac-required guide to training one, then import it above."
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
            Text("Opens the camera and runs the exact same verification pipeline used every morning — but doesn't affect your real XP, streak, or score. Use it to check your camera and model are working.")
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
    .environment(ModelRetrainReminderManager(persistence: PersistenceService()))
}
