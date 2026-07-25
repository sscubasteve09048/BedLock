//
//  NotificationService.swift
//  BedLock
//
//  Wraps UNUserNotificationCenter for both permission requests and posting
//  BedLock's local notifications: the morning reminder and the "nice job"
//  confirmation after a successful verification.
//
import Foundation
import UserNotifications

final class NotificationService {

    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    /// Requests permission to show alerts, sounds, and badges.
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Fires immediately: the morning reminder to verify your bed.
    func sendMorningReminderNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Good morning!"
        content.body = "Time to verify your bed and keep your streak going."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "bedlock.morningReminder.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    /// Fires immediately: a successful verification.
    func sendVerifiedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Nice job!"
        content.body = "Your bed is verified. Keep the streak alive!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "bedlock.verified.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    /// Fires immediately: verification failed, prompting a retry.
    func sendVerificationFailedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Not quite made yet"
        content.body = "Your bed doesn't appear to be made. Please try again."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "bedlock.failed.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}
