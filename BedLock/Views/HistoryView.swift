//
//  HistoryView.swift
//  BedLock
//
//  Lists past verification attempts with date, time, and confidence.
//
import SwiftUI

struct HistoryView: View {
    @Environment(AppLockManager.self) private var appLockManager

    @State private var viewModel: HistoryViewModel?
    @State private var showingClearConfirmation = false

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.entries.isEmpty {
                    ContentUnavailableView(
                        "No History Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Verified unlocks will show up here.")
                    )
                } else {
                    List {
                        Section {
                            statsRow(viewModel: viewModel)
                        }
                        Section("Attempts") {
                            ForEach(viewModel.entries) { entry in
                                HistoryRow(entry: entry)
                            }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("History")
        .toolbar {
            if let viewModel, !viewModel.entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", role: .destructive) {
                        showingClearConfirmation = true
                    }
                }
            }
        }
        .confirmationDialog(
            "Clear all history?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) {
                viewModel?.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            if viewModel == nil {
                viewModel = HistoryViewModel(appLockManager: appLockManager)
            }
            viewModel?.refresh()
        }
        .onAppear {
            viewModel?.refresh()
        }
    }

    private func statsRow(viewModel: HistoryViewModel) -> some View {
        HStack {
            statItem(title: "Total", value: "\(viewModel.entries.count)")
            Divider()
            statItem(title: "Successful", value: "\(viewModel.successCount)")
            Divider()
            statItem(title: "Avg. Confidence", value: String(format: "%.0f%%", viewModel.averageConfidence * 100))
        }
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HistoryRow: View {
    let entry: UnlockHistoryEntry

    var body: some View {
        HStack {
            Image(systemName: entry.wasSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(entry.wasSuccessful ? .green : .red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.formattedDate)
                        .font(.subheadline.bold())
                    if entry.wasTest {
                        Text("TEST")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.2), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                Text(entry.formattedTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.formattedConfidence)
                .font(.headline)
                .foregroundStyle(entry.wasSuccessful ? .green : .red)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .environment(AppLockManager(screenTimeManager: ScreenTimeManager(), persistence: PersistenceService()))
}
