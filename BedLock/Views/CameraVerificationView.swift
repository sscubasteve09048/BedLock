//
//  CameraVerificationView.swift
//  BedLock
//
//  The verification screen: "Verify your bed is made," camera capture,
//  processing state, and success/failure results. Used both for the real
//  morning check-in and for Settings > Test Verification (`isTestMode`).
//
import SwiftUI
import UIKit

struct CameraVerificationView: View {
    let isTestMode: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(GamificationManager.self) private var gamificationManager
    @Environment(PersistenceService.self) private var persistence

    @State private var viewModel: CameraVerificationViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if let viewModel {
                    content(for: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(isTestMode ? "Test Verification" : "Verify")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = CameraVerificationViewModel(
                    isTestMode: isTestMode,
                    verificationService: BedVerificationService(),
                    cameraService: CameraService(),
                    gamificationManager: gamificationManager,
                    threshold: persistence.verificationThreshold
                )
                await viewModel?.start()
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: CameraVerificationViewModel) -> some View {
        switch viewModel.stage {
        case .idle, .awaitingCameraPermission:
            ProgressView("Preparing camera…")

        case .cameraPermissionDenied:
            permissionDeniedView

        case .showingCamera:
            CameraCaptureRepresentable(
                onCapture: { image in viewModel.handleCapture(image) },
                onCancel: { viewModel.handleCameraCancelled(); dismiss() }
            )
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                promptBanner
                    .padding(.top, 8)
            }

        case .processing:
            processingView

        case .success(let result):
            resultView(result: result, success: true, viewModel: viewModel)

        case .failure(let result):
            resultView(result: result, success: false, viewModel: viewModel)

        case .error(let message):
            errorView(message: message, viewModel: viewModel)
        }
    }

    private var promptBanner: some View {
        Text(isTestMode ? "Test verification — take a photo of your bed." : "Take a photo to verify your bed is made.")
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(.horizontal)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Camera Access Needed")
                .font(.title3.bold())
            Text("BedLock needs camera access to verify your bed is made. Please enable it in Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
        }
    }

    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Analyzing your bed…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func resultView(result: VerificationResult, success: Bool, viewModel: CameraVerificationViewModel) -> some View {
        VStack(spacing: 24) {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(success ? .green : .red)

            Text(resultTitle(success: success, viewModel: viewModel))
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if success && !viewModel.isTestMode {
                Label("+\(GamificationManager.bedVerificationXP) XP", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(.yellow)
            }

            VStack(spacing: 4) {
                Text("Confidence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.0f%%", result.confidence * 100))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(success ? .green : .red)
            }

            Text("Vision detected: \(result.label.capitalized)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if success {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
            } else {
                VStack(spacing: 12) {
                    Button {
                        viewModel.retake()
                    } label: {
                        Text("Try Again")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 40)
            }
        }
    }

    private func resultTitle(success: Bool, viewModel: CameraVerificationViewModel) -> String {
        if !success {
            return "Your bed doesn't appear to be made. Please try again."
        }
        return viewModel.isTestMode ? "Nice! The pipeline works." : "Nice job! Bed verified."
    }

    private func errorView(message: String, viewModel: CameraVerificationViewModel) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Something Went Wrong")
                .font(.title3.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button {
                viewModel.retake()
            } label: {
                Text("Try Again")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    CameraVerificationView(isTestMode: true)
        .environment(GamificationManager(persistence: PersistenceService(), habitManager: HabitManager(persistence: PersistenceService())))
        .environment(PersistenceService())
}
