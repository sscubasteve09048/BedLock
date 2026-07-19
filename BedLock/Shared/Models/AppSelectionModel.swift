//
//  AppSelectionModel.swift
//  BedLock
//
//  Wraps FamilyActivitySelection so it can be persisted and reasoned about
//  independently of the Screen Time picker UI.
//

import Foundation
import FamilyControls
import ManagedSettings

/// Represents which apps/categories the user has chosen. Two selections are tracked:
/// - `blockedSelection`: apps the user explicitly wants to block (if empty, BedLock blocks
///   everything on the device except the always-exempt system apps).
/// - `alwaysAllowedSelection`: apps the user wants to always keep unlocked, even during
///   restriction mode (in addition to the system-mandated exemptions like Phone/Emergency).
struct AppSelectionModel: Codable, Equatable {
    var blockedSelection: FamilyActivitySelection
    var alwaysAllowedSelection: FamilyActivitySelection

    /// Whether the user wants to block "everything except allowed apps" (the common case)
    /// versus only blocking a specific explicit list.
    var blockEverythingExceptAllowed: Bool

    static let `default` = AppSelectionModel(
        blockedSelection: FamilyActivitySelection(),
        alwaysAllowedSelection: FamilyActivitySelection(),
        blockEverythingExceptAllowed: true
    )
}

/// Apps that Apple's ManagedSettings framework will not allow BedLock to restrict, or that
/// BedLock deliberately never restricts for safety reasons (Emergency SOS, Phone, Clock alarms,
/// Messages). Screen Time's `ManagedSettingsStore` applies shields at the category/app-token
/// level supplied by the user through `FamilyActivityPicker`; Apple does not expose a way to
/// enumerate "system apps" by bundle identifier due to privacy design, so these are tracked
/// here only for display/documentation purposes in the UI.
enum SystemExemptApp: String, CaseIterable, Identifiable {
    case messages = "Messages (iMessage)"
    case clock = "Clock (Alarms)"
    case phone = "Phone"
    case emergencySOS = "Emergency SOS / Emergency Call"

    var id: String { rawValue }

    var explanation: String {
        switch self {
        case .messages:
            return "Always reachable so you can be contacted in an emergency."
        case .clock:
            return "Alarms must keep working even while your phone is locked."
        case .phone:
            return "Phone calls are never blocked by BedLock."
        case .emergencySOS:
            return "iOS never allows Screen Time restrictions to block Emergency SOS. This is enforced by Apple, not BedLock."
        }
    }
}
