//
//  GamificationManager.swift
//  BedLock
//
//  The central coordinator for everything gamification-related: recording
//  bed verifications and habit completions, computing the daily morning
//  score, tracking XP/levels/streaks, unlocking badges, and surfacing quest
//  progress. BedLock cannot and does not lock or unlock other apps — this
//  manager tracks *your own* verification streak and progress, nothing more.
//
import Foundation
import Observation

@MainActor
@Observable
final class GamificationManager {

    /// XP awarded for verifying your bed each day (first success only).
    static let bedVerificationXP = 25

    private let persistence: PersistenceService
    private let habitManager: HabitManager

    private(set) var history: [UnlockHistoryEntry]
    private(set) var dailyRecords: [DailyProgress]
    private(set) var totalXP: Int
    private(set) var longestStreak: Int
    private(set) var unlockedBadgeIDs: Set<String>
    private(set) var lastVerificationDate: Date?

    /// Toggled to true whenever something confetti-worthy happens (perfect
    /// day, new badge). Views observe this and reset it after animating.
    var showConfetti = false

    init(persistence: PersistenceService, habitManager: HabitManager) {
        self.persistence = persistence
        self.habitManager = habitManager
        self.history = persistence.loadHistory()
        self.dailyRecords = persistence.loadDailyProgress()
        self.totalXP = persistence.totalXP
        self.longestStreak = persistence.longestStreak
        self.unlockedBadgeIDs = persistence.loadUnlockedBadgeIDs()
        self.lastVerificationDate = persistence.lastVerificationDate
    }

    // MARK: - Today

    var todayRecord: DailyProgress {
        record(for: Date()) ?? DailyProgress(dayStart: DailyProgress.startOfDay(for: Date()))
    }

    var activeHabits: [Habit] {
        habitManager.activeHabits
    }

    var todayScore: Int {
        todayRecord.score(bedXP: Self.bedVerificationXP, activeHabits: activeHabits)
    }

    var isBedVerifiedToday: Bool {
        todayRecord.bedVerified
    }

    var level: LevelInfo {
        LevelInfo.from(totalXP: totalXP)
    }

    var currentStreak: Int {
        computeCurrentStreak()
    }

    // MARK: - Quests

    var dailyQuest: QuestProgress {
        QuestCalculator.dailyQuest(today: todayRecord, activeHabits: activeHabits, bedXP: Self.bedVerificationXP)
    }

    var weeklyChallenge: QuestProgress {
        QuestCalculator.weeklyChallenge(records: dailyRecords)
    }

    var monthlyGoal: QuestProgress {
        QuestCalculator.monthlyGoal(records: dailyRecords)
    }

    // MARK: - Achievements

    var achievements: [(achievement: Achievement, isUnlocked: Bool)] {
        let stats = currentAchievementStats()
        return Achievement.all.map { ($0, $0.isUnlocked(stats: stats)) }
    }

    // MARK: - Calendar / stats

    func record(for date: Date) -> DailyProgress? {
        let start = DailyProgress.startOfDay(for: date)
        return dailyRecords.first { $0.dayStart == start }
    }

    /// Fraction of days this month (so far) with a verified bed.
    var completionPercentageThisMonth: Double {
        let calendar = Calendar.current
        guard let monthStart = calendar.dateInterval(of: .month, for: Date())?.start else { return 0 }
        let today = calendar.startOfDay(for: Date())
        let daysElapsed = (calendar.dateComponents([.day], from: monthStart, to: today).day ?? 0) + 1
        guard daysElapsed > 0 else { return 0 }
        let verifiedDays = dailyRecords.filter { $0.dayStart >= monthStart && $0.bedVerified }.count
        return Double(verifiedDays) / Double(daysElapsed)
    }

    var xpEarnedThisMonth: Int {
        let calendar = Calendar.current
        guard let monthStart = calendar.dateInterval(of: .month, for: Date())?.start else { return 0 }
        return dailyRecords.filter { $0.dayStart >= monthStart }.reduce(0) { $0 + $1.xpEarned }
    }

    // MARK: - Recording verification

    /// Records a verification. For real (non-test) verifications, this awards
    /// XP once per day, updates the streak, checks for newly-unlocked badges,
    /// and queues confetti. Test Verification (`isTest == true`) still logs
    /// to history for visibility but never touches XP/streak/today's record —
    /// it's there to check the camera/model pipeline, not to farm progress.
    func recordSuccessfulVerification(result: VerificationResult, isTest: Bool) {
        let now = Date()

        if !isTest {
            lastVerificationDate = now
            persistence.lastVerificationDate = now

            var today = todayRecord
            let alreadyVerifiedToday = today.bedVerified
            today.bedVerified = true
            today.bedConfidence = result.confidence
            if !alreadyVerifiedToday {
                today.xpEarned += Self.bedVerificationXP
                addXP(Self.bedVerificationXP)
            }
            upsert(today)
        }

        let entry = UnlockHistoryEntry(date: now, confidence: result.confidence, wasSuccessful: true, wasTest: isTest)
        persistence.appendHistoryEntry(entry)
        history = persistence.loadHistory()

        NotificationService.shared.sendVerifiedNotification()

        if !isTest {
            recomputeStreakAndBadges(scoreJustHitPerfect: todayScore == 100)
        }
    }

    /// Records a failed verification attempt without any XP or streak change.
    func recordFailedAttempt(result: VerificationResult, isTest: Bool) {
        let entry = UnlockHistoryEntry(date: Date(), confidence: result.confidence, wasSuccessful: false, wasTest: isTest)
        persistence.appendHistoryEntry(entry)
        history = persistence.loadHistory()
    }

    // MARK: - Habits

    func isHabitCompletedToday(_ habit: Habit) -> Bool {
        todayRecord.completedHabitIDs.contains(habit.id)
    }

    /// Toggles a habit's completion for today, adjusting XP accordingly.
    func toggleHabit(_ habit: Habit) {
        var today = todayRecord
        let wasCompleted = today.completedHabitIDs.contains(habit.id)
        if wasCompleted {
            today.completedHabitIDs.remove(habit.id)
            today.xpEarned = max(today.xpEarned - habit.xpValue, 0)
            addXP(-habit.xpValue)
        } else {
            today.completedHabitIDs.insert(habit.id)
            today.xpEarned += habit.xpValue
            addXP(habit.xpValue)
        }
        upsert(today)

        let nowPerfect = !wasCompleted && today.score(bedXP: Self.bedVerificationXP, activeHabits: activeHabits) == 100
        recomputeStreakAndBadges(scoreJustHitPerfect: nowPerfect)
    }

    // MARK: - Lifecycle

    /// Re-reads persisted state — call on `scenePhase` becoming `.active` so
    /// a new calendar day (or any external change) is picked up.
    func syncWithSharedState() {
        history = persistence.loadHistory()
        dailyRecords = persistence.loadDailyProgress()
        totalXP = persistence.totalXP
        longestStreak = persistence.longestStreak
        unlockedBadgeIDs = persistence.loadUnlockedBadgeIDs()
        lastVerificationDate = persistence.lastVerificationDate
    }

    func clearHistory() {
        persistence.saveHistory([])
        history = []
    }

    func dismissConfetti() {
        showConfetti = false
    }

    // MARK: - Private

    private func addXP(_ amount: Int) {
        totalXP = max(totalXP + amount, 0)
        persistence.totalXP = totalXP
    }

    private func upsert(_ record: DailyProgress) {
        if let index = dailyRecords.firstIndex(where: { $0.dayStart == record.dayStart }) {
            dailyRecords[index] = record
        } else {
            dailyRecords.append(record)
        }
        persistence.saveDailyProgress(dailyRecords)
    }

    private func computeCurrentStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var cursor = calendar.startOfDay(for: Date())

        // If today isn't verified yet, the streak reflects consecutive prior
        // days — completing today is what *extends* it, not a requirement
        // for it to currently exist.
        if record(for: cursor)?.bedVerified != true {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        while let day = record(for: cursor), day.bedVerified {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private func recomputeStreakAndBadges(scoreJustHitPerfect: Bool) {
        let streak = computeCurrentStreak()
        if streak > longestStreak {
            longestStreak = streak
            persistence.longestStreak = streak
        }

        let stats = currentAchievementStats()
        let newlyUnlocked = Achievement.all.filter {
            !unlockedBadgeIDs.contains($0.id) && $0.isUnlocked(stats: stats)
        }
        if !newlyUnlocked.isEmpty {
            for badge in newlyUnlocked {
                unlockedBadgeIDs.insert(badge.id)
            }
            persistence.saveUnlockedBadgeIDs(unlockedBadgeIDs)
        }

        if scoreJustHitPerfect || !newlyUnlocked.isEmpty {
            showConfetti = true
        }
    }

    private func currentAchievementStats() -> AchievementStats {
        AchievementStats(
            totalVerifications: history.filter(\.wasSuccessful).count,
            longestStreak: longestStreak,
            level: level.level,
            hasPerfectWeek: hasPerfectScoreWeek()
        )
    }

    private func hasPerfectScoreWeek() -> Bool {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return false }
        let daysThisWeek = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
        let recordsThisWeek = daysThisWeek.compactMap { record(for: $0) }
        guard recordsThisWeek.count == 7 else { return false }
        return recordsThisWeek.allSatisfy {
            $0.score(bedXP: Self.bedVerificationXP, activeHabits: activeHabits) == 100
        }
    }
}
