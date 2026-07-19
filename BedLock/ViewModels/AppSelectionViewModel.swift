//
//  AppSelectionViewModel.swift
//  BedLock
//
//  Drives the App Selection screen, where the user picks which apps/categories
//  get blocked and which stay always-reachable.
//
import Foundation
import FamilyControls
import Observation

@MainActor
@Observable
final class AppSelectionViewModel {

    var selection: AppSelectionModel
    var isPresentingBlockedPicker = false
    var isPresentingAllowedPicker = false

    private let persistence: PersistenceService
    private let screenTimeManager: ScreenTimeManager

    init(persistence: PersistenceService, screenTimeManager: ScreenTimeManager) {
        self.persistence = persistence
        self.screenTimeManager = screenTimeManager
        self.selection = persistence.loadAppSelection()
    }

    var systemExemptApps: [SystemExemptApp] {
        SystemExemptApp.allCases
    }

    var blockEverythingExceptAllowed: Bool {
        get { selection.blockEverythingExceptAllowed }
        set { selection.blockEverythingExceptAllowed = newValue }
    }

    var blockedAppCount: Int {
        selection.blockedSelection.applicationTokens.count + selection.blockedSelection.categoryTokens.count
    }

    var allowedAppCount: Int {
        selection.alwaysAllowedSelection.applicationTokens.count
    }

    func save() {
        persistence.saveAppSelection(selection)
        // If a restriction is currently active, re-apply immediately so an edit
        // to the always-allowed list takes effect without waiting for the next
        // lock/unlock cycle.
        if screenTimeManager.isCurrentlyShielded {
            screenTimeManager.applyRestrictions(selection: selection)
        }
    }
}
