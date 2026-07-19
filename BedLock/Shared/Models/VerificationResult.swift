//
//  VerificationResult.swift
//  BedLock
//
//  The output of a bed-making verification pass, produced by any type conforming
//  to `BedVerifying`. Kept modular so the underlying model can be swapped without
//  touching any UI or manager code.
//

import Foundation

struct VerificationResult: Equatable {
    /// Confidence in the range 0.0...1.0 that the image shows a made bed.
    let confidence: Double
    /// The threshold used to decide pass/fail at the time of evaluation.
    let threshold: Double
    /// Free-text label from the underlying classifier, useful for debugging/history.
    let label: String

    var isSuccessful: Bool { confidence >= threshold }
}

/// Errors that can occur while trying to verify a bed-making photo.
enum VerificationError: Error, LocalizedError {
    case imageConversionFailed
    case modelUnavailable
    case visionRequestFailed(String)
    case noResults

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Couldn't process the captured photo. Please try again."
        case .modelUnavailable:
            return "The verification model isn't available right now."
        case .visionRequestFailed(let message):
            return "Verification failed: \(message)"
        case .noResults:
            return "The verification model returned no results."
        }
    }
}
