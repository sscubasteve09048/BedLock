//
//  SettingsViewModel.swift
//  BedLock
//
//  Drives the Settings screen: notification/camera/Screen Time permission
//  status, the verification confidence threshold, and the Test Verification
//  entry point.
//
import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {

    private let persistence: PersistenceService
    let screenTimeManager: ScreenTimeManager

    var threshold: Double {
        didSet { persistence.verificationThreshold = threshold }
    }

    var showingTestVerification = false
    var notificationsAuthorized = false
    var cameraAuthorized = false

    init(persistence: PersistenceService, screenTimeManager: ScreenTimeManager) {
        self.persistence = persistence
        self.screenTimeManager = screenTimeManager
        self.threshold = persistence.verificationThreshold
    }

    func beginTestVerification() {
        showingTestVerification = true
    }

    func refreshPermissionStatuses() async {
        notificationsAuthorized = await NotificationService.shared.requestAuthorization()
        let cameraService = CameraService()
        cameraAuthorized = cameraService.currentAuthorizationStatus == .authorized
        screenTimeManager.refreshAuthorizationStatus()
    }
}
