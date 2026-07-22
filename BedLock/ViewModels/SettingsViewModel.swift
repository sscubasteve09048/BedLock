//
//  SettingsViewModel.swift
//  BedLock
//
//  Drives the Settings screen: notification/camera permission status, the
//  verification confidence threshold, custom-model status/retrain reminder,
//  and the Test Verification entry point.
//
import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {

    private let persistence: PersistenceService
    private let retrainReminderManager: ModelRetrainReminderManager

    var threshold: Double {
        didSet { persistence.verificationThreshold = threshold }
    }

    var showingTestVerification = false
    var notificationsAuthorized = false
    var cameraAuthorized = false

    /// Whether a custom-trained Core ML model is present, either imported at
    /// runtime (Settings → Import Custom Model) or baked into the app bundle
    /// at build time. Computed fresh each time rather than cached.
    var isCustomModelInstalled: Bool {
        CoreMLBedVerificationService.isModelInstalled()
    }

    /// Distinguishes an imported (swap anytime, no rebuild) model from one
    /// baked into the app bundle (requires a rebuild/reinstall to change),
    /// purely for clearer status text in Settings.
    var isModelImported: Bool {
        ModelImportService.isImportedModelPresent()
    }

    var showingModelImporter = false
    var modelImportErrorMessage: String?
    var isImportingModel = false

    private let modelImportService = ModelImportService()

    var retrainReminderEnabled: Bool {
        get { persistence.retrainReminderEnabled }
        set {
            persistence.retrainReminderEnabled = newValue
            retrainReminderManager.applyReminderSettings()
        }
    }

    var retrainIntervalDays: Int {
        get { persistence.retrainIntervalDays }
        set {
            persistence.retrainIntervalDays = newValue
            retrainReminderManager.applyReminderSettings()
        }
    }

    var daysSinceLastTraining: Int? {
        retrainReminderManager.daysSinceLastTraining
    }

    init(persistence: PersistenceService, retrainReminderManager: ModelRetrainReminderManager) {
        self.persistence = persistence
        self.retrainReminderManager = retrainReminderManager
        self.threshold = persistence.verificationThreshold
    }

    func beginTestVerification() {
        showingTestVerification = true
    }

    func beginModelImport() {
        modelImportErrorMessage = nil
        showingModelImporter = true
    }

    /// Handles the result of the `.fileImporter` sheet: compiles and installs
    /// the picked model file, taking effect immediately with no rebuild.
    func handleModelImportResult(_ result: Result<[URL], Error>) async {
        switch result {
        case .failure(let error):
            modelImportErrorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            isImportingModel = true
            defer { isImportingModel = false }
            do {
                try await modelImportService.importModel(from: url)
                markRetrainedNow()
            } catch {
                modelImportErrorMessage = error.localizedDescription
            }
        }
    }

    /// Removes an imported model, reverting to whatever's baked into the app
    /// bundle (or the built-in heuristic if nothing is bundled either) —
    /// useful to quickly back out of a retrain that made things worse,
    /// without needing to reinstall anything.
    func removeImportedModel() {
        try? ModelImportService.removeImportedModel()
    }

    func markRetrainedNow() {
        retrainReminderManager.markRetrainedNow()
    }

    func refreshPermissionStatuses() async {
        notificationsAuthorized = await NotificationService.shared.requestAuthorization()
        let cameraService = CameraService()
        cameraAuthorized = cameraService.currentAuthorizationStatus == .authorized
    }
}
