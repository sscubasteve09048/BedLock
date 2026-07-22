//
//  CoreMLBedVerificationService.swift
//  BedLock
//
//  Drop-in replacement for `VisionBedVerificationService`. Train a custom
//  image classifier on YOUR bed specifically (see TRAIN_CUSTOM_MODEL.md) with
//  exactly two classes named "made" and "not_made".
//
//  Two ways to get the model into the app, checked in this order:
//  1. **Imported at runtime** (`ModelImportService`) — pick a `.mlmodel`/
//     `.mlpackage` file via Settings → Import Custom Model. Takes effect
//     immediately, no app rebuild or reinstall needed. This is how you
//     iterate on retraining without redownloading the app each time.
//  2. **Baked into the app bundle at build time** — add
//     `BedMadeClassifier.mlpackage` to the Xcode project (see
//     `scripts/add_ml_model_to_xcodeproj.py`) so it's compiled into every
//     build. Useful as the model that ships with a fresh install, but does
//     require rebuilding/reinstalling the app to update.
//
//  If neither is present, `verify` throws `VerificationError.modelUnavailable`
//  so callers fall back to `VisionBedVerificationService`.
//
import Foundation
import UIKit
import Vision
import CoreML

final class CoreMLBedVerificationService: BedVerifying {

    /// Whether a custom-trained model is present, from either source. Used
    /// by the Settings screen to show accurate status.
    static func isModelInstalled(modelFileName: String = "BedMadeClassifier") -> Bool {
        ModelImportService.isImportedModelPresent()
            || Bundle.main.url(forResource: modelFileName, withExtension: "mlmodelc") != nil
    }

    /// Exact (not substring) class label for "bed is made" in the trained
    /// model's output. IMPORTANT: this must be an exact match, not a
    /// `contains` check — "unmade".contains("made") is true in Swift, so a
    /// substring check would silently misclassify the negative class if it
    /// were ever named "unmade" instead of "not_made". Train your model with
    /// exactly these two class names to avoid any ambiguity.
    private let madeLabel = "made"

    private let modelFileName: String

    init(modelFileName: String = "BedMadeClassifier") {
        self.modelFileName = modelFileName
    }

    func verify(image: UIImage, threshold: Double) async throws -> VerificationResult {
        guard let cgImage = image.cgImage else {
            throw VerificationError.imageConversionFailed
        }

        let model = try loadModel()

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error {
                    continuation.resume(throwing: VerificationError.visionRequestFailed(error.localizedDescription))
                    return
                }
                guard let observations = request.results as? [VNClassificationObservation],
                      let best = observations.first else {
                    continuation.resume(throwing: VerificationError.noResults)
                    return
                }

                let isMade = best.identifier.lowercased() == self.madeLabel
                let confidence = isMade ? Double(best.confidence) : 1.0 - Double(best.confidence)

                continuation.resume(returning: VerificationResult(
                    confidence: confidence,
                    threshold: threshold,
                    label: best.identifier
                ))
            }
            request.imageCropAndScaleOption = .centerCrop

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: VerificationError.visionRequestFailed(error.localizedDescription))
            }
        }
    }

    private func loadModel() throws -> VNCoreMLModel {
        // Prefer an imported (no-rebuild) model over whatever's baked into
        // the app bundle, since it's by definition the most recently updated.
        let importedURL = ModelImportService.importedModelDirectory
        if FileManager.default.fileExists(atPath: importedURL.path) {
            let mlModel = try MLModel(contentsOf: importedURL)
            return try VNCoreMLModel(for: mlModel)
        }

        guard let compiledURL = Bundle.main.url(forResource: modelFileName, withExtension: "mlmodelc") else {
            throw VerificationError.modelUnavailable
        }
        let mlModel = try MLModel(contentsOf: compiledURL)
        return try VNCoreMLModel(for: mlModel)
    }
}
