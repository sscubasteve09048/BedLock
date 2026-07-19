//
//  ScreenTimeManager.swift
//  BedLock
//
//  Owns all interaction with Apple's Screen Time APIs: requesting FamilyControls
//  authorization and applying/removing ManagedSettings shields (the actual app
//  restriction mechanism).
//
//  IMPORTANT LIMITATION (see item 13 in the spec): Apple's ManagedSettings APIs
//  work by shielding the *tokens* the user selects in `FamilyActivityPicker`
//  (ApplicationTokens / ActivityCategoryTokens). Apple does not expose bundle
//  identifiers to third-party apps for privacy reasons, and several built-in
//  system apps/features (Phone, Emergency SOS, and the system Clock alarm
//  delivery path) cannot be shielded at all by ManagedSettings — Apple silently
//  ignores attempts to shield them. BedLock does not attempt any private API or
//  workaround; it simply never asks the user to add those apps to the blocked
//  selection, and clearly documents this in the App Selection screen.
//
import Foundation
import FamilyControls
import ManagedSettings
import Observation

@MainActor
@Observable
final class ScreenTimeManager {

    enum AuthorizationStatus {
        case notDetermined
        case denied
        case approved
    }

    private(set) var authorizationStatus: AuthorizationStatus = .notDetermined

    private let store = ManagedSettingsStore(named: BedLockShared.shieldStoreName)
    private let center = AuthorizationCenter.shared

    init() {
        refreshAuthorizationStatus()
    }

    /// Requests Screen Time (FamilyControls) authorization. Must be called before
    /// the app can present `FamilyActivityPicker` or apply any shields.
    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
            refreshAuthorizationStatus()
        } catch {
            authorizationStatus = .denied
        }
    }

    func refreshAuthorizationStatus() {
        switch center.authorizationStatus {
        case .notDetermined:
            authorizationStatus = .notDetermined
        case .denied:
            authorizationStatus = .denied
        case .approved:
            authorizationStatus = .approved
        @unknown default:
            authorizationStatus = .notDetermined
        }
    }

    /// Applies the shield: blocks the apps/categories described by `selection`.
    ///
    /// `ShieldSettings.ActivityCategoryPolicy.all(except:)` takes *application*
    /// tokens as its exception set (not category tokens, despite living on the
    /// "categories" property) — so "shield every category on the device except
    /// these specific apps" genuinely works as a single call. This is more
    /// capable than an earlier version of this comment assumed.
    func applyRestrictions(selection: AppSelectionModel) {
        if selection.blockEverythingExceptAllowed {
            store.shield.applicationCategories = .all(except: selection.alwaysAllowedSelection.applicationTokens)
            store.shield.applications = nil
        } else {
            // Only shield the apps/categories the user explicitly picked.
            store.shield.applications = selection.blockedSelection.applicationTokens
                .subtracting(selection.alwaysAllowedSelection.applicationTokens)
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(
                selection.blockedSelection.categoryTokens
            )
        }
    }

    /// Removes all shields, unlocking every app immediately.
    func removeRestrictions() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    /// True if any shield is currently configured (used to drive the Dashboard's
    /// "locked" state without relying on a separate persisted flag alone).
    var isCurrentlyShielded: Bool {
        store.shield.applicationCategories != nil || store.shield.applications?.isEmpty == false
    }
}
