//
//  ProgressStatsView.swift
//  BedLock
//
//  Calendar view, monthly stats, and the achievements/badges grid.
//
import SwiftUI

struct ProgressStatsView: View {
    @Environment(GamificationManager.self) private var gamificationManager

    @State private var viewModel: ProgressStatsViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let viewModel {
                    statsCard(viewModel: viewModel)
                    calendarCard(viewModel: viewModel)
                    achievementsCard(viewModel: viewModel)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Progress")
        .task {
            if viewModel == nil {
                viewModel = ProgressStatsViewModel(gamificationManager: gamificationManager)
            }
        }
    }

    @ViewBuilder
    private func statsCard(viewModel: ProgressStatsViewModel) -> some View {
        HStack(spacing: 0) {
            statItem(value: "\(viewModel.currentStreak)", label: "Current Streak")
            Divider().frame(height: 40)
            statItem(value: "\(viewModel.longestStreak)", label: "Longest Streak")
            Divider().frame(height: 40)
            statItem(value: "\(Int(viewModel.completionPercentageThisMonth * 100))%", label: "This Month")
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func calendarCard(viewModel: ProgressStatsViewModel) -> some View {
        VStack(spacing: 12) {
            calendarHeader(viewModel: viewModel)
            weekdayLabelsRow
            calendarGrid(viewModel: viewModel)
            legendRow
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func calendarHeader(viewModel: ProgressStatsViewModel) -> some View {
        HStack {
            Button {
                viewModel.goToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(viewModel.monthTitle)
                .font(.headline)
            Spacer()
            Button {
                viewModel.goToNextMonth()
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var weekdayLabelsRow: some View {
        HStack {
            ForEach(Weekday.allCases) { day in
                Text(day.shortName.prefix(1))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func calendarGrid(viewModel: ProgressStatsViewModel) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(Array(viewModel.calendarDays.enumerated()), id: \.offset) { _, day in
                calendarCell(day: day, viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private func calendarCell(day: Date?, viewModel: ProgressStatsViewModel) -> some View {
        if let day {
            let status = viewModel.status(for: day)
            ZStack {
                Circle()
                    .fill(cellColor(status: status))
                Text(dayNumber(for: day))
                    .font(.caption2)
                    .foregroundStyle(status == .none ? Color.secondary : Color.white)
            }
            .frame(height: 32)
        } else {
            Color.clear.frame(height: 32)
        }
    }

    private func cellColor(status: ProgressStatsViewModel.DayStatus) -> Color {
        switch status {
        case .verified: return .green
        case .attempted: return .orange
        case .none: return Color.secondary.opacity(0.1)
        }
    }

    private func dayNumber(for date: Date) -> String {
        String(Calendar.current.component(.day, from: date))
    }

    private var legendRow: some View {
        HStack(spacing: 16) {
            legendItem(color: .green, label: "Verified")
            legendItem(color: Color.secondary.opacity(0.2), label: "No attempt")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    @ViewBuilder
    private func achievementsCard(viewModel: ProgressStatsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.achievements, id: \.achievement.id) { entry in
                    achievementBadge(entry: entry)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func achievementBadge(entry: (achievement: Achievement, isUnlocked: Bool)) -> some View {
        VStack(spacing: 6) {
            Image(systemName: entry.achievement.iconName)
                .font(.title2)
                .foregroundStyle(entry.isUnlocked ? Color.yellow : Color.secondary.opacity(0.4))
                .frame(width: 52, height: 52)
                .background(
                    entry.isUnlocked ? Color.yellow.opacity(0.15) : Color.secondary.opacity(0.08),
                    in: Circle()
                )
            Text(entry.achievement.title)
                .font(.caption2.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(entry.isUnlocked ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        ProgressStatsView()
    }
    .environment(GamificationManager(persistence: PersistenceService(), habitManager: HabitManager(persistence: PersistenceService())))
}
