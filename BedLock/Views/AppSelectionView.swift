//
//  AppSelectionView.swift
//  BedLock
//
//  Lets the user choose which apps get blocked during lock mode, and which
//  apps/categories should always remain reachable (in addition to the
//  system-level exemptions Apple enforces, like Emergency SOS).
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
                Form {
                    Section {
                        Picker("Blocking Mode", selection: bindingForMode(viewModel)) {
                            Text("Block Everything Except Allowed").tag(true)
                            Text("Block Only Selected Apps").tag(false)
                        }
                        .pickerStyle(.inline)
                    } footer: {
                        Text(viewModel.selection.blockEverythingExceptAllowed
                             ? "All apps and categories will be shielded except the apps you mark as always-allowed below."
                             : "Only the specific apps you choose below will be shielded; everything else stays reachable.")
                    }

                    if !viewModel.selection.blockEverythingExceptAllowed {
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

                    Section("Always Exempt by iOS") {
                        ForEach(viewModel.systemExemptApps) { app in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.rawValue).font(.subheadline.bold())
                                Text(app.explanation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    } footer: {
                        Text("Apple's Screen Time APIs do not allow third-party apps to shield these system features. BedLock never attempts to bypass this limitation.")
                    }

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
                .familyActivityPicker(
                    isPresented: Binding(
                        get: { viewModel.isPresentingBlockedPicker },
                        set: { viewModel.isPresentingBlockedPicker = $0 }
                    ),
                    selection: Binding(
                        get: { viewModel.selection.blockedSelection },
                        set: { viewModel.selection.blockedSelection = $0 }
                    )
                )
                .familyActivityPicker(
                    isPresented: Binding(
                        get: { viewModel.isPresentingAllowedPicker },
                        set: { viewModel.isPresentingAllowedPicker = $0 }
                    ),
                    selection: Binding(
                        get: { viewModel.selection.alwaysAllowedSelection },
                        set: { viewModel.selection.alwaysAllowedSelection = $0 }
                    )
                )
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

    private func bindingForMode(_ viewModel: AppSelectionViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.blockEverythingExceptAllowed },
            set: { viewModel.blockEverythingExceptAllowed = $0 }
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
