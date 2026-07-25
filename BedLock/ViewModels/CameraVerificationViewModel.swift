//
//  CameraVerificationViewModel.swift
//  BedLock
//
//  Drives the full verification flow: request camera permission, present the
//  camera, run the photo through BedVerifying, then record the result. Also
//  used by the Test Verification button in Settings (`isTestMode == true`),
//  which runs the identical camera + model pipeline but never touches real
//  XP/streak progress — it's for checking the pipeline works, not the actual
//  morning check-in.
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
    private let gamificationManager: GamificationManager
    private let threshold: Double

    init(
        isTestMode: Bool,
        verificationService: BedVerifying,
        cameraService: CameraService,
        gamificationManager: GamificationManager,
        threshold: Double
    ) {
        self.isTestMode = isTestMode
        self.verificationService = verificationService
        self.cameraService = cameraService
        self.gamificationManager = gamificationManager
        self.threshold = threshold
    }

    /// Entry point called when the verification screen appears.
    func start() async {
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
                gamificationManager.recordSuccessfulVerification(result: result, isTest: isTestMode)
                stage = .success(result)
            } else {
                gamificationManager.recordFailedAttempt(result: result, isTest: isTestMode)
                NotificationService.shared.sendVerificationFailedNotification()
                stage = .failure(result)
            }
        } catch {
            stage = .error(error.localizedDescription)
        }
    }
}
