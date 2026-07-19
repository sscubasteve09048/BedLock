//
//  VisionBedVerificationService.swift
//  BedLock
//
//  Default implementation of `BedVerifying` built entirely on Apple's on-device
//  Vision framework (no network calls, no custom training required to ship v1).
//
//  Approach:
//  1. `VNClassifyImageRequest` runs Apple's built-in general-purpose scene/object
//     classifier (thousands of labels) to confirm the photo actually shows a bed
//     or bedroom scene at all. This guards against someone pointing the camera at
//     a random object to try to fake the unlock.
//  2. `VNDetectRectanglesRequest` looks for large, well-defined flat rectangular
//     surfaces. A neatly made bed tends to present large, high-confidence
//     rectangular planes (the flattened comforter/sheet), whereas an unmade bed
//     with bunched sheets and pillows produces fewer/lower-confidence rectangles.
//     This is a pragmatic heuristic, not a trained "made vs. unmade" classifier.
//  3. The two signals are combined into a single confidence score.
//
//  This is intentionally the *weakest* link in the pipeline and is designed to be
//  swapped out: to upgrade accuracy, create a Core ML image classifier trained on
//  made/unmade bed photos, drop the compiled `.mlmodelc` into the app bundle, and
//  point `BedLockApp` at `CoreMLBedVerificationService` instead of this type. No
//  other code needs to change because both conform to `BedVerifying`.
//
import Foundation
import UIKit
import Vision

final class VisionBedVerificationService: BedVerifying {

    /// Labels from Apple's built-in classifier that indicate the photo plausibly
    /// contains a bed or bedroom. Apple's classifier vocabulary includes general
    /// household/scene terms such as these.
    private let bedRelatedIdentifiers: Set<String> = [
        "bed", "beds", "bedroom", "bedding", "bedclothes", "blanket", "blankets",
        "pillow", "pillows", "linen", "linens", "sheet", "sheets", "comforter",
        "mattress", "quilt", "duvet", "furniture", "room"
    ]

    func verify(image: UIImage, threshold: Double) async throws -> VerificationResult {
        guard let cgImage = image.cgImage else {
            throw VerificationError.imageConversionFailed
        }

        async let sceneScore = classifyScene(cgImage: cgImage)
        async let neatnessScore = detectNeatness(cgImage: cgImage)

        let (scene, neatness) = try await (sceneScore, neatnessScore)

        // Weighted blend: scene confirmation matters most (are we even looking at a
        // bed?), neatness heuristic refines whether it looks "made".
        let combined = (scene.confidence * 0.55) + (neatness * 0.45)
        let clamped = min(max(combined, 0), 1)

        return VerificationResult(
            confidence: clamped,
            threshold: threshold,
            label: scene.label
        )
    }

    // MARK: - Scene classification

    private struct SceneClassification {
        let confidence: Double
        let label: String
    }

    private func classifyScene(cgImage: CGImage) async throws -> SceneClassification {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: VerificationError.visionRequestFailed(error.localizedDescription))
                    return
                }
                guard let observations = request.results as? [VNClassificationObservation],
                      !observations.isEmpty else {
                    continuation.resume(throwing: VerificationError.noResults)
                    return
                }

                // Find the highest-confidence observation whose identifier matches
                // a bed-related term. If none match, fall back to the top overall
                // observation but heavily discount its confidence, since the photo
                // likely isn't a bed at all.
                let bedMatches = observations
                    .filter { self.bedRelatedIdentifiers.contains($0.identifier.lowercased()) }
                    .sorted { $0.confidence > $1.confidence }

                if let best = bedMatches.first {
                    continuation.resume(returning: SceneClassification(
                        confidence: Double(best.confidence),
                        label: best.identifier
                    ))
                } else {
                    let top = observations.max(by: { $0.confidence < $1.confidence })
                    continuation.resume(returning: SceneClassification(
                        confidence: Double(top?.confidence ?? 0) * 0.2,
                        label: top?.identifier ?? "unknown"
                    ))
                }
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: VerificationError.visionRequestFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Neatness heuristic via rectangle detection

    private func detectNeatness(cgImage: CGImage) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error {
                    continuation.resume(throwing: VerificationError.visionRequestFailed(error.localizedDescription))
                    return
                }
                guard let observations = request.results as? [VNRectangleObservation] else {
                    continuation.resume(returning: 0)
                    return
                }
                if observations.isEmpty {
                    continuation.resume(returning: 0.2)
                    return
                }

                // Score based on the largest rectangle's area (as a fraction of the
                // frame) and its detection confidence. A big, confident rectangle
                // suggests a large flat smoothed surface, i.e. a made bed.
                let largest = observations.max { lhs, rhs in
                    Self.area(of: lhs) < Self.area(of: rhs)
                }

                guard let largest else {
                    continuation.resume(returning: 0.2)
                    return
                }

                let areaScore = min(Self.area(of: largest) * 2.2, 1.0) // area is 0...1 of frame
                let confidenceScore = Double(largest.confidence)
                let combined = (areaScore * 0.6) + (confidenceScore * 0.4)
                continuation.resume(returning: min(max(combined, 0), 1))
            }

            request.minimumAspectRatio = 0.3
            request.maximumAspectRatio = 1.0
            request.minimumSize = 0.15
            request.minimumConfidence = 0.5
            request.maximumObservations = 4

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: VerificationError.visionRequestFailed(error.localizedDescription))
            }
        }
    }

    private static func area(of observation: VNRectangleObservation) -> Double {
        let width = Double(observation.topRight.x - observation.topLeft.x)
        let height = Double(observation.topLeft.y - observation.bottomLeft.y)
        return abs(width * height)
    }
}
