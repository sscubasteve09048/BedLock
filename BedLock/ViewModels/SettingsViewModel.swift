//
//  SettingsViewModel.swift
//  BedLock
//
//  Drives the Settings screen: notification/camera permission status, the
//  verification confidence threshold, and the Test Verification entry point.
//
import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {

    private let persistence: PersistenceService

    var threshold: Double {
        didSet { persistence.verificationThreshold = threshold }
    }

    var showingTestVerification = false
    var notificationsAuthorized = false
    var cameraAuthorized = false

    init(persistence: PersistenceService) {
        self.persistence = persistence
        self.threshold = persistence.verificationThreshold
    }

    func beginTestVerification() {
        showingTestVerification = true
    }

    func refreshPermissionStatuses() async {
        notificationsAuthorized = await NotificationService.shared.requestAuthorization()
        let cameraService = CameraService()
        cameraAuthorized = cameraService.currentAuthorizationStatus == .authorized
    }
}
