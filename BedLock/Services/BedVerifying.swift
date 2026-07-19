//
//  BedVerifying.swift
//  BedLock
//
//  Protocol that any bed-making verification engine must conform to. This is the
//  seam that lets us start with Apple's built-in Vision classifier and later swap
//  in a custom-trained Core ML model without touching CameraVerificationViewModel
//  or any UI code.
//

import Foundation
import UIKit

protocol BedVerifying {
    /// Analyze the given photo and return a confidence score that the bed is made.
    /// - Parameter image: the captured photo.
    /// - Parameter threshold: the confidence threshold (0...1) used to decide success.
    func verify(image: UIImage, threshold: Double) async throws -> VerificationResult
}
