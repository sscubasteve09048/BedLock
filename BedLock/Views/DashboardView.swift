//
//  DashboardView.swift
//  BedLock
//
//  The home screen: shows BedLock's own "locked" status, the active reminder
//  schedule at a glance, and a big call-to-action to verify and unlock. Actual
//  app restriction comes from iOS's native Screen Time → Downtime feature,
//  configured directly in Settings — see the info card below and
//  FREE_LOCKING.md for the full setup.
//
import SwiftUI

struct DashboardView: View {
    @Environment(AppLockManager.self) private var appLockManager
    @Environment(PersistenceService.self) private var persistence

    @State private var viewModel: DashboardViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statusCard
                if let viewModel {
                    scheduleSummaryCard(viewModel: viewModel)
                }
                infoCard
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
                .tint(Color.accentColor)
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

    private func scheduleSummaryCard(viewModel: DashboardViewModel) -> some View {
        NavigationLink {
            ScheduleView()
        } label: {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Morning Reminder")
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

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("How locking works", systemImage: "info.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(Color.accentColor)
            Text("BedLock verifies your bed and tracks your streak here for free. To actually restrict other apps, turn on Screen Time → Downtime in Settings and add BedLock to Always Allowed — see FREE_LOCKING.md in the project for the full walkthrough.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(PersistenceService())
    .environment(AppLockManager(persistence: PersistenceService()))
}
