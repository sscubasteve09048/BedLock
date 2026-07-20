//
//  AppSelectionView.swift
//  BedLock
//
//  Lets the user choose which apps get blocked during lock mode, and which
//  apps/categories should always remain reachable (in addition to the
//  system-level exemptions Apple enforces, like Emergency SOS).
//
//  NOTE: Each Form section is broken out into its own @ViewBuilder function.
//  A single `var body` containing this many nested Sections/Pickers/Bindings
//  is enough to make the Swift type-checker time out ("unable to type-check
//  this expression in reasonable time") — splitting it up gives the compiler
//  much smaller expressions to solve individually.
//
import SwiftUI
import FamilyControls

struct AppSelectionView: View {
    @Environment(PersistenceService.self) private var persistence
    @Environment(ScreenTimeManager.self) private var screenTimeManager

    @State private var viewModel: AppSelectionViewModel?

    var body: some View {
        Group {
            if let viewModel {
                formContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Apps")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = AppSelectionViewModel(persistence: persistence, screenTimeManager: screenTimeManager)
            }
        }
    }

    @ViewBuilder
    private func formContent(viewModel: AppSelectionViewModel) -> some View {
        Form {
            blockingModeSection(viewModel: viewModel)
            if !viewModel.selection.blockEverythingExceptAllowed {
                blockedAppsSection(viewModel: viewModel)
            }
            alwaysAllowedSection(viewModel: viewModel)
            systemExemptSection(viewModel: viewModel)
            saveSection(viewModel: viewModel)
        }
        .familyActivityPicker(
            isPresented: blockedPickerBinding(viewModel),
            selection: blockedSelectionBinding(viewModel)
        )
        .familyActivityPicker(
            isPresented: allowedPickerBinding(viewModel),
            selection: allowedSelectionBinding(viewModel)
        )
    }

    @ViewBuilder
    private func blockingModeSection(viewModel: AppSelectionViewModel) -> some View {
        Section {
            Picker("Blocking Mode", selection: bindingForMode(viewModel)) {
                Text("Block Everything Except Allowed").tag(true)
                Text("Block Only Selected Apps").tag(false)
            }
            .pickerStyle(.inline)
        } footer: {
            Text(blockingModeFooterText(viewModel: viewModel))
        }
    }

    private func blockingModeFooterText(viewModel: AppSelectionViewModel) -> String {
        viewModel.selection.blockEverythingExceptAllowed
            ? "All apps and categories will be shielded except the apps you mark as always-allowed below."
            : "Only the specific apps you choose below will be shielded; everything else stays reachable."
    }

    @ViewBuilder
    private func blockedAppsSection(viewModel: AppSelectionViewModel) -> some View {
        Section("Apps to Block") {
            Button {
                viewModel.isPresentingBlockedPicker = true
            } label: {
                HStack {
                    Text("Choose Apps to Block")
                    Spacer()
                    Text("\(viewModel.blockedAppCount) selected")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func alwaysAllowedSection(viewModel: AppSelectionViewModel) -> some View {
        Section("Always Allowed") {
            Button {
                viewModel.isPresentingAllowedPicker = true
            } label: {
                HStack {
                    Text("Choose Apps to Keep Unlocked")
                    Spacer()
                    Text("\(viewModel.allowedAppCount) selected")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func systemExemptSection(viewModel: AppSelectionViewModel) -> some View {
        Section("Always Exempt by iOS") {
            ForEach(viewModel.systemExemptApps) { app in
                exemptAppRow(app: app)
            }
        } footer: {
            Text("Apple's Screen Time APIs do not allow third-party apps to shield these system features. BedLock never attempts to bypass this limitation.")
        }
    }

    private func exemptAppRow(app: SystemExemptApp) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(app.rawValue).font(.subheadline.bold())
            Text(app.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func saveSection(viewModel: AppSelectionViewModel) -> some View {
        Section {
            Button {
                viewModel.save()
            } label: {
                Text("Save Selection")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Bindings

    private func bindingForMode(_ viewModel: AppSelectionViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.blockEverythingExceptAllowed },
            set: { viewModel.blockEverythingExceptAllowed = $0 }
        )
    }

    private func blockedPickerBinding(_ viewModel: AppSelectionViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.isPresentingBlockedPicker },
            set: { viewModel.isPresentingBlockedPicker = $0 }
        )
    }

    private func allowedPickerBinding(_ viewModel: AppSelectionViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.isPresentingAllowedPicker },
            set: { viewModel.isPresentingAllowedPicker = $0 }
        )
    }

    private func blockedSelectionBinding(_ viewModel: AppSelectionViewModel) -> Binding<FamilyActivitySelection> {
        Binding(
            get: { viewModel.selection.blockedSelection },
            set: { viewModel.selection.blockedSelection = $0 }
        )
    }

    private func allowedSelectionBinding(_ viewModel: AppSelectionViewModel) -> Binding<FamilyActivitySelection> {
        Binding(
            get: { viewModel.selection.alwaysAllowedSelection },
            set: { viewModel.selection.alwaysAllowedSelection = $0 }
        )
    }
}

#Preview {
    NavigationStack {
        AppSelectionView()
    }
    .environment(PersistenceService())
    .environment(ScreenTimeManager())
}
