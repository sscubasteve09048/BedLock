//
//  ModelImportService.swift
//  BedLock
//
//  Lets you swap in a newly-retrained model directly on your phone — no app
//  rebuild, resign, or reinstall required. This is the fix for "do I have to
//  redownload the app every time I retrain?": no, as long as you import the
//  new model this way rather than only baking it into the app bundle at
//  build time.
//
//  How it works: `MLModel.compileModel(at:)` compiles a raw `.mlmodel` or
//  `.mlpackage` file into a `.mlmodelc` the same way Xcode would at build
//  time — but it can do this at runtime, from a file the user picks via the
//  Files app. Apple places the compiled output in a temporary location it
//  may clean up later, so we immediately copy it into Application Support,
//  which persists across app launches (though not across a full app
//  reinstall/delete — see the note in CoreMLBedVerificationService.swift).
//
import Foundation
import CoreML

enum ModelImportError: Error, LocalizedError {
    case accessDenied
    case compileFailed(String)
    case copyFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Couldn't access the selected file. Try picking it again."
        case .compileFailed(let message):
            return "Couldn't compile that file as a Core ML model: \(message)"
        case .copyFailed(let message):
            return "Compiled the model, but couldn't save it: \(message)"
        }
    }
}

final class ModelImportService {

    static let modelFileName = "BedMadeClassifier"

    /// Where an imported (in-app, no-rebuild) model is stored. Checked by
    /// `CoreMLBedVerificationService` *before* the app-bundle copy, so an
    /// imported model always takes priority the moment you import it.
    static var importedModelDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("\(modelFileName).mlmodelc")
    }

    static func isImportedModelPresent() -> Bool {
        FileManager.default.fileExists(atPath: importedModelDirectory.path)
    }

    static func removeImportedModel() throws {
        let destination = importedModelDirectory
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
    }

    /// Compiles and installs a user-picked `.mlmodel`/`.mlpackage` file so it
    /// takes effect on the very next verification — no rebuild required.
    func importModel(from sourceURL: URL) async throws {
        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let compiledURL: URL
        do {
            compiledURL = try await Task.detached(priority: .userInitiated) {
                try MLModel.compileModel(at: sourceURL)
            }.value
        } catch {
            throw ModelImportError.compileFailed(error.localizedDescription)
        }

        let destination = Self.importedModelDirectory
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: compiledURL, to: destination)
        } catch {
            throw ModelImportError.copyFailed(error.localizedDescription)
        }
    }
}
