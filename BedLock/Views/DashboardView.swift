//
//  DashboardView.swift
//  BedLock
//
//  The home screen: shows whether the phone is currently locked, the active
//  schedule at a glance, and a big call-to-action to verify and unlock.
//
import SwiftUI

struct DashboardView: View {
    @Environment(AppLockManager.self) private var appLockManager
    @Environment(ScreenTimeManager.self) private var screenTimeManager
    @Environment(PersistenceService.self) private var persistence

    @State private var viewModel: DashboardViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statusCard
                if let viewModel, viewModel.needsAuthorization {
                    authorizationBanner(viewModel: viewModel)
                }
                if let viewModel {
                    scheduleSummaryCard(viewModel: viewModel)
                }
                Spacer(minLength: 12)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("BedLock")
        .task {
            if viewModel == nil {
                viewModel = DashboardViewModel(
                    appLockManager: appLockManager,
                    screenTimeManager: screenTimeManager,
                    persistence: persistence
                )
            }
            viewModel?.refresh()
        }
        .onAppear {
            viewModel?.refresh()
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel?.showingVerification ?? false },
            set: { viewModel?.showingVerification = $0 }
        )) {
            CameraVerificationView(isTestMode: false)
        }
        .alert("Screen Time Access Needed", isPresented: Binding(
            get: { viewModel?.showingAuthorizationAlert ?? false },
            set: { viewModel?.showingAuthorizationAlert = $0 }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("BedLock needs Screen Time permission to lock apps. Enable it in Settings > Screen Time > BedLock.")
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 140, height: 140)
                Image(systemName: (viewModel?.isLocked ?? false) ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(statusColor)
            }
            .padding(.top, 8)

            Text((viewModel?.isLocked ?? false) ? "Phone Locked" : "Phone Unlocked")
                .font(.title2.bold())

            Text(viewModel?.lastVerificationText ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if viewModel?.isLocked ?? false {
                Button {
                    viewModel?.beginVerification()
                } label: {
                    Label("Make Your Bed to Unlock", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }

    private var statusColor: Color {
        (viewModel?.isLocked ?? false) ? .red : .green
    }

    private func authorizationBanner(viewModel: DashboardViewModel) -> some View {
        Button {
            Task { await viewModel.requestAuthorizationIfNeeded() }
        } label: {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Screen Time Permission Needed")
                        .font(.subheadline.bold())
                    Text("Tap to grant access so BedLock can lock apps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func scheduleSummaryCard(viewModel: DashboardViewModel) -> some View {
        NavigationLink {
            ScheduleView()
        } label: {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(.accentColor)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Morning Schedule")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(viewModel.schedule.isEnabled ? viewModel.schedule.summary : "Disabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(PersistenceService())
    .environment(ScreenTimeManager())
    .environment(AppLockManager(screenTimeManager: ScreenTimeManager(), persistence: PersistenceService()))
}
