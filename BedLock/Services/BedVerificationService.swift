//
//  BedVerificationService.swift
//  BedLock
//
//  Facade injected everywhere else in the app. Tries the custom Core ML model
//  first (if one has been added to the bundle); otherwise falls back to the
//  built-in Vision heuristic. This is the single point of configuration for
//  which verification engine is "live" — swap the model file in the bundle and
//  the app automatically upgrades, no code changes needed.
//
import Foundation
import UIKit

final class BedVerificationService: BedVerifying {
    private let primary: BedVerifying
    private let fallback: BedVerifying

    init(primary: BedVerifying = CoreMLBedVerificationService(),
         fallback: BedVerifying = VisionBedVerificationService()) {
        self.primary = primary
        self.fallback = fallback
    }

    func verify(image: UIImage, threshold: Double) async throws -> VerificationResult {
        do {
            return try await primary.verify(image: image, threshold: threshold)
        } catch VerificationError.modelUnavailable {
            return try await fallback.verify(image: image, threshold: threshold)
        } catch {
            // Any other failure from the primary engine still falls back so a
            // single bad frame doesn't strand the user unable to unlock their phone.
            return try await fallback.verify(image: image, threshold: threshold)
        }
    }
}
