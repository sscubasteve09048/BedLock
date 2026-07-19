//
//  CoreMLBedVerificationService.swift
//  BedLock
//
//  Drop-in replacement for `VisionBedVerificationService`. Once you train a custom
//  image classifier (e.g. with Create ML) on labeled "made bed" / "unmade bed"
//  photos, export the compiled model as "BedMadeClassifier.mlmodelc" and add it to
//  the app bundle. This service will pick it up automatically and run it through
//  Vision's `VNCoreMLRequest`, producing a real confidence score with no other
//  code changes required — just switch which service is injected in `BedLockApp`.
//
//  If the model isn't present in the bundle (e.g. during initial development),
//  `verify` throws `VerificationError.modelUnavailable` so callers can fall back
//  to `VisionBedVerificationService`.
//
import Foundation
import UIKit
import Vision
import CoreML

final class CoreMLBedVerificationService: BedVerifying {

    /// Expected class label for a made bed in the trained model's output.
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

                let isMade = best.identifier.lowercased().contains(self.madeLabel)
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
        guard let compiledURL = Bundle.main.url(forResource: modelFileName, withExtension: "mlmodelc") else {
            throw VerificationError.modelUnavailable
        }
        let mlModel = try MLModel(contentsOf: compiledURL)
        return try VNCoreMLModel(for: mlModel)
    }
}
