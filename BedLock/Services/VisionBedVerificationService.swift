//
//  VisionBedVerificationService.swift
//  BedLock
//
//  Default implementation of `BedVerifying` built entirely on Apple's on-device
//  Vision framework (no network calls, no custom training required to ship v1).
//
//  Approach:
//  1. `VNClassifyImageRequest` runs Apple's built-in general-purpose scene/object
//     classifier to confirm the photo plausibly shows a bed/bedroom/domestic
//     interior. This uses *substring* matching against a broad keyword list
//     across *all* returned observations (not just the single top label),
//     because Apple's classifier vocabulary uses many different exact phrases
//     ("four poster bed", "daybed", "linens", "bedclothes", etc.) and a strict
//     exact-match against a short list badly under-recognizes real photos.
//  2. `VNDetectRectanglesRequest` looks for large, well-defined flat rectangular
//     surfaces as a mild secondary signal. This is intentionally weighted low
//     and given a neutral (not punishing) fallback: rectangle detection is
//     tuned for hard-edged geometry like documents and cards, and often finds
//     nothing at all on soft fabric/bedding even when the bed is genuinely
//     made — so an empty result should not tank the score.
//  3. The two signals are combined as a weighted average with forgiving
//     floors, not a multiplicative penalty, so a single weak signal doesn't
//     crater an otherwise-good photo.
//
//  This is intentionally the *weakest* link in the pipeline and is designed to
//  be swapped out: to upgrade accuracy, create a Core ML image classifier
//  trained on made/unmade bed photos, drop the compiled `.mlmodelc` into the
//  app bundle, and point `BedLockApp` at `CoreMLBedVerificationService`
//  instead of this type. No other code needs to change because both conform
//  to `BedVerifying`.
//
import Foundation
import UIKit
import Vision

final class VisionBedVerificationService: BedVerifying {

    /// Substrings (not exact matches) checked against every classification
    /// identifier Vision returns. Deliberately broad — anything suggesting a
    /// bed, bedding, or a bedroom-like domestic interior counts as a plausible
    /// scene match, since Apple's classifier vocabulary is large and phrased
    /// in ways that don't line up with a short exact-match list.
    private let bedRelatedKeywords: [String] = [
        "bed", "mattress", "pillow", "blanket", "linen", "sheet", "comforter",
        "quilt", "duvet", "bedding", "bedclothes", "bedroom", "headboard",
        "nightstand", "furniture", "textile", "fabric", "cushion", "room",
        "interior", "curtain", "rug", "carpet", "home", "house", "apartment",
        "indoor", "domestic"
    ]

    /// A tighter set of strong, unambiguous keywords. A confident match here
    /// gets a small score boost, since these leave little doubt the photo
    /// really is of a bed rather than just a bedroom-adjacent object.
    private let strongKeywords: [String] = [
        "bed", "mattress", "bedding", "bedclothes", "comforter", "duvet", "quilt"
    ]

    func verify(image: UIImage, threshold: Double) async throws -> VerificationResult {
        guard let cgImage = image.cgImage else {
            throw VerificationError.imageConversionFailed
        }

        async let sceneScore = classifyScene(cgImage: cgImage)
        async let neatnessScore = detectNeatness(cgImage: cgImage)

        let (scene, neatness) = try await (sceneScore, neatnessScore)

        // Weighted average with forgiving floors — a weak rectangle-detection
        // result shouldn't be able to drag down an otherwise confident scene
        // match, and vice versa.
        let combined = (scene.confidence * 0.75) + (neatness * 0.25)
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
            let request = VNClassifyImageRequest { [weak self] request, error in
                guard let self else { return }
                if let error {
                    continuation.resume(throwing: VerificationError.visionRequestFailed(error.localizedDescription))
                    return
                }
                guard let observations = request.results as? [VNClassificationObservation],
                      !observations.isEmpty else {
                    continuation.resume(throwing: VerificationError.noResults)
                    return
                }

                // Search every returned observation (Vision typically returns
                // hundreds, sorted by confidence) for any identifier that
                // *contains* one of our keywords, rather than requiring an
                // exact match on just the single top label.
                var bestMatch: (confidence: Double, identifier: String, isStrong: Bool)?

                for observation in observations {
                    let identifier = observation.identifier.lowercased()
                    let confidence = Double(observation.confidence)

                    let isStrong = self.strongKeywords.contains { identifier.contains($0) }
                    let isMatch = isStrong || self.bedRelatedKeywords.contains { identifier.contains($0) }

                    guard isMatch else { continue }

                    if bestMatch == nil || confidence > bestMatch!.confidence {
                        bestMatch = (confidence, observation.identifier, isStrong)
                    }
                }

                if let match = bestMatch {
                    // Apple's classifier tends to spread confidence across many
                    // overlapping/co-occurring labels for a single scene, so a
                    // "correct" match often reports a modest confidence even
                    // when it's clearly right. Scale up a bit, more so for
                    // strong/unambiguous keywords, and clamp to 1.0.
                    let boost = match.isStrong ? 1.6 : 1.3
                    let scaled = min(match.confidence * boost, 1.0)
                    continuation.resume(returning: SceneClassification(
                        confidence: scaled,
                        label: match.identifier
                    ))
                } else {
                    // No bed/bedroom-ish keyword anywhere in the results. This
                    // is a genuine signal the photo probably isn't a bed, but
                    // we still don't want to crush the score to near-zero on
                    // its own — the neatness signal gets a chance to weigh in,
                    // and a false negative here (e.g. an odd camera angle) is
                    // far worse for the user than a slightly-too-lenient pass.
                    let top = observations.max(by: { $0.confidence < $1.confidence })
                    continuation.resume(returning: SceneClassification(
                        confidence: 0.35,
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
                guard let observations = request.results as? [VNRectangleObservation],
                      !observations.isEmpty else {
                    // Soft bedding frequently produces no crisp rectangles at
                    // all, even when neatly made — this is a weak, unreliable
                    // signal, so "nothing found" gets a neutral score rather
                    // than a penalty.
                    continuation.resume(returning: 0.5)
                    return
                }

                // Score based on the largest rectangle's area (as a fraction of the
                // frame) and its detection confidence. A big, confident rectangle
                // suggests a large flat smoothed surface, i.e. a made bed.
                let largest = observations.max { lhs, rhs in
                    Self.area(of: lhs) < Self.area(of: rhs)
                }

                guard let largest else {
                    continuation.resume(returning: 0.5)
                    return
                }

                let areaScore = min(Self.area(of: largest) * 2.2, 1.0) // area is 0...1 of frame
                let confidenceScore = Double(largest.confidence)
                let combined = (areaScore * 0.6) + (confidenceScore * 0.4)
                // Blend with the neutral floor so a single mediocre rectangle
                // detection doesn't score much worse than "nothing detected".
                continuation.resume(returning: max(min(combined, 1.0), 0.5))
            }

            request.minimumAspectRatio = 0.25
            request.maximumAspectRatio = 1.0
            request.minimumSize = 0.1
            request.minimumConfidence = 0.3
            request.maximumObservations = 6

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
