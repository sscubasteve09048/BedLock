//
//  CameraVerificationViewModel.swift
//  BedLock
//
//  Drives the full verification flow: request camera permission, present the
//  camera, run the photo through BedVerifying, then unlock (or ask for a retry).
//  Also used by the Test Verification button in Settings, in which case
//  `isTestMode` is true: the flow first force-locks the apps exactly like the
//  real schedule would, then runs the identical verification path.
//
import Foundation
import UIKit
import Observation

enum VerificationStage: Equatable {
    case idle
    case awaitingCameraPermission
    case cameraPermissionDenied
    case showingCamera
    case processing
    case success(VerificationResult)
    case failure(VerificationResult)
    case error(String)
}

@MainActor
@Observable
final class CameraVerificationViewModel {

    private(set) var stage: VerificationStage = .idle
    var capturedImage: UIImage?

    let isTestMode: Bool

    private let verificationService: BedVerifying
    private let cameraService: CameraService
    private let appLockManager: AppLockManager
    private let selectionProvider: () -> AppSelectionModel
    private let threshold: Double

    init(
        isTestMode: Bool,
        verificationService: BedVerifying,
        cameraService: CameraService,
        appLockManager: AppLockManager,
        threshold: Double,
        selectionProvider: @escaping () -> AppSelectionModel
    ) {
        self.isTestMode = isTestMode
        self.verificationService = verificationService
        self.cameraService = cameraService
        self.appLockManager = appLockManager
        self.threshold = threshold
        self.selectionProvider = selectionProvider
    }

    /// Entry point called when the verification screen appears.
    func start() async {
        if isTestMode {
            // Test Verification ignores the schedule and locks immediately,
            // exactly like the morning trigger would.
            appLockManager.lockNow(selection: selectionProvider())
        }

        stage = .awaitingCameraPermission
        let status = await cameraService.requestAuthorization()
        switch status {
        case .authorized:
            stage = .showingCamera
        case .denied, .notDetermined:
            stage = .cameraPermissionDenied
        }
    }

    func handleCapture(_ image: UIImage) {
        capturedImage = image
        stage = .processing
        Task {
            await runVerification(on: image)
        }
    }

    func handleCameraCancelled() {
        stage = .idle
    }

    /// Called when the user taps "Try Again" after a failed attempt.
    func retake() {
        capturedImage = nil
        stage = .showingCamera
    }

    private func runVerification(on image: UIImage) async {
        do {
            let result = try await verificationService.verify(image: image, threshold: threshold)
            if result.isSuccessful {
                appLockManager.unlock(result: result, isTest: isTestMode)
                stage = .success(result)
            } else {
                appLockManager.recordFailedAttempt(result: result, isTest: isTestMode)
                NotificationService.shared.sendVerificationFailedNotification()
                stage = .failure(result)
            }
        } catch {
            stage = .error(error.localizedDescription)
        }
    }
}
