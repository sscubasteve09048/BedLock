//
//  UnlockHistoryEntry.swift
//  BedLock
//
//  A single record of a verification attempt, stored for the History screen.
//

import Foundation

struct UnlockHistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let confidence: Double
    let wasSuccessful: Bool
    /// True if this entry was created via the "Test Verification" button rather than the
    /// real morning schedule.
    let wasTest: Bool

    init(id: UUID = UUID(), date: Date = Date(), confidence: Double, wasSuccessful: Bool, wasTest: Bool) {
        self.id = id
        self.date = date
        self.confidence = confidence
        self.wasSuccessful = wasSuccessful
        self.wasTest = wasTest
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var formattedConfidence: String {
        String(format: "%.0f%%", confidence * 100)
    }
}
