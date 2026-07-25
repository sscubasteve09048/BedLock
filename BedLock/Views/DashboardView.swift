//
//  DashboardView.swift
//  BedLock
//
//  The home screen: today's morning score, level/XP, streak, today's habit
//  checklist, quest progress, and the verification entry point. BedLock does
//  not lock or unlock anything else on the device — this screen tracks your
//  own verification streak and progress only.
//
//  NOTE: broken into small @ViewBuilder functions rather than one large
//  `body` — a single body with this many nested views can make the Swift
//  type-checker time out.
//
import SwiftUI

struct DashboardView: View {
    @Environment(GamificationManager.self) private var gamificationManager
    @Environment(HabitManager.self) private var habitManager
    @Environment(PersistenceService.self) private var persistence

    @State private var viewModel: DashboardViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let viewModel {
                    scoreCard(viewModel: viewModel)
                    levelCard(viewModel: viewModel)
                    streakCard(viewModel: viewModel)
                    if !viewModel.activeHabits.isEmpty {
                        habitsCard(viewModel: viewModel)
                    }
                    questsCard(viewModel: viewModel)
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
                    gamificationManager: gamificationManager,
                    habitManager: habitManager,
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
        .overlay(
            ConfettiView(isActive: Binding(
                get: { gamificationManager.showConfetti },
                set: { if !$0 { gamificationManager.dismissConfetti() } }
            ))
        )
    }

    // MARK: - Score card

    @ViewBuilder
    private func scoreCard(viewModel: DashboardViewModel) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.todayScore) / 100)
                    .stroke(scoreColor(viewModel: viewModel), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: viewModel.todayScore)
                VStack(spacing: 2) {
                    Text("\(viewModel.todayScore)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("Morning Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)
            .padding(.top, 8)

            if viewModel.isBedVerifiedToday {
                Label("Bed Verified Today", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            } else {
                Button {
                    viewModel.beginVerification()
                } label: {
                    Label("Verify Your Bed", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
            }

            Text(viewModel.lastVerificationText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }

    private func scoreColor(viewModel: DashboardViewModel) -> Color {
        switch viewModel.todayScore {
        case 100: return .green
        case 50...: return .orange
        default: return .red
        }
    }

    // MARK: - Level card

    @ViewBuilder
    private func levelCard(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Level \(viewModel.level.level)", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(.yellow)
                Spacer()
                Text("\(viewModel.level.xpIntoLevel) / \(viewModel.level.xpNeededForLevel) XP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: viewModel.level.progress)
                .tint(.yellow)
                .animation(.easeOut(duration: 0.5), value: viewModel.level.progress)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Streak card

    @ViewBuilder
    private func streakCard(viewModel: DashboardViewModel) -> some View {
        HStack(spacing: 0) {
            streakStat(value: "\(viewModel.currentStreak)", label: "Current Streak", icon: "flame.fill", color: .orange)
            Divider().frame(height: 40)
            streakStat(value: "\(viewModel.longestStreak)", label: "Longest Streak", icon: "trophy.fill", color: .yellow)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func streakStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Habits card

    @ViewBuilder
    private func habitsCard(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Habits")
                .font(.headline)
            ForEach(viewModel.activeHabits) { habit in
                habitRow(habit: habit, viewModel: viewModel)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func habitRow(habit: Habit, viewModel: DashboardViewModel) -> some View {
        let completed = viewModel.isHabitCompleted(habit)
        return Button {
            withAnimation(.spring(response: 0.3)) {
                viewModel.toggleHabit(habit)
            }
        } label: {
            HStack {
                Image(systemName: habit.iconName)
                    .foregroundStyle(completed ? Color.green : Color.secondary)
                    .frame(width: 28)
                Text(habit.name)
                    .foregroundStyle(.primary)
                Spacer()
                Text("+\(habit.xpValue) XP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(completed ? Color.green : Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quests card

    @ViewBuilder
    private func questsCard(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quests")
                .font(.headline)
            questRow(quest: viewModel.dailyQuest)
            Divider()
            questRow(quest: viewModel.weeklyChallenge)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func questRow(quest: QuestProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(quest.title)
                    .font(.subheadline.bold())
                Spacer()
                if quest.isComplete {
                    Label("+\(quest.bonusXP) XP", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                } else {
                    Text("\(quest.current)/\(quest.target)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(quest.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: quest.progress)
                .tint(quest.isComplete ? .green : .accentColor)
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(PersistenceService())
    .environment(HabitManager(persistence: PersistenceService()))
    .environment(GamificationManager(persistence: PersistenceService(), habitManager: HabitManager(persistence: PersistenceService())))
}
