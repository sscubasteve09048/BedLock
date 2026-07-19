//
//  DeviceActivityMonitorExtension.swift
//  BedLockMonitor
//
//  This is a separate `DeviceActivityMonitor` extension target. iOS launches
//  this extension's process directly at the scheduled interval boundaries
//  registered by `ScheduleManager`, even if the main BedLock app isn't running.
//  It applies the ManagedSettings shield itself (extensions can create their own
//  ManagedSettingsStore with the same name) and writes the "restriction active"
//  flag to the shared App Group so the main app's Dashboard reflects it the next
//  time it's opened.
//
import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore(named: BedLockShared.shieldStoreName)
    private let persistence = PersistenceService()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == BedLockShared.activityName else { return }

        let selection = persistence.loadAppSelection()

        if selection.blockEverythingExceptAllowed {
            store.shield.applicationCategories = .all(except: selection.alwaysAllowedSelection.categoryTokens)
            store.shield.applications = nil
        } else {
            store.shield.applications = selection.blockedSelection.applicationTokens
                .subtracting(selection.alwaysAllowedSelection.applicationTokens)
            store.shield.applicationCategories = .specific(selection.blockedSelection.categoryTokens)
        }

        persistence.isRestrictionActive = true

        // Post a local notification directly from the extension so the user is
        // alerted even if BedLock's main app isn't running.
        NotificationService.shared.sendMorningLockNotification()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == BedLockShared.activityName else { return }

        // If the schedule has a defined end time and it passes without the user
        // verifying, we leave the shield in place (per spec: the user must prove
        // the bed is made to unlock) but stop tracking it as part of "today's"
        // active window. The shield itself is only removed by a successful
        // verification in the main app.
    }
}
