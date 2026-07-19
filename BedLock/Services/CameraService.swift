//
//  CameraService.swift
//  BedLock
//
//  Thin wrapper around AVCaptureDevice authorization. The actual capture UI is
//  implemented as a SwiftUI-wrapped UIImagePickerController in
//  CameraCaptureRepresentable.swift, since UIImagePickerController remains the
//  simplest Apple-supported way to present the system camera UI with a delivered
//  UIImage suitable for Vision processing.
//
import Foundation
import AVFoundation

final class CameraService {

    enum AuthorizationStatus {
        case authorized
        case denied
        case notDetermined
    }

    /// Requests camera authorization, returning once the user has responded
    /// (or immediately if already determined).
    func requestAuthorization() async -> AuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .authorized : .denied
        @unknown default:
            return .denied
        }
    }

    var currentAuthorizationStatus: AuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }
}
