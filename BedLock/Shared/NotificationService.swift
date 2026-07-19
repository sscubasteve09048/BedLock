//
//  NotificationService.swift
//  BedLock
//
//  Wraps UNUserNotificationCenter for both permission requests and posting the
//  two local notifications BedLock sends: the morning wake-up prompt and the
//  "you're unlocked" confirmation.
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

    /// Fires immediately: "Good morning! Make your bed to unlock your phone."
    func sendMorningLockNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Good morning!"
        content.body = "Make your bed to unlock your phone."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "bedlock.morningLock.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    /// Fires immediately: "Nice job! Your phone is unlocked."
    func sendUnlockedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Nice job!"
        content.body = "Your phone is unlocked."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "bedlock.unlocked.\(UUID().uuidString)",
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
