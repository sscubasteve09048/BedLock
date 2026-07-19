//
//  ScheduleManager.swift
//  BedLock
//
//  Registers the user's morning schedule with `DeviceActivityCenter` so that the
//  restriction begins automatically at the configured time, even if BedLock isn't
//  running in the foreground. The actual shield is applied by
//  `BedLockMonitorExtension` (a `DeviceActivityMonitor` extension target) when it
//  receives `intervalDidStart`, because only code running in that extension's
//  process is guaranteed to be woken up by the system at the scheduled time.
//
//  The app and the extension share state (the current AppSelectionModel and the
//  "restriction active" flag) through an App Group container so both processes
//  see the same configuration.
//
import Foundation
import DeviceActivity
import Observation

@MainActor
@Observable
final class ScheduleManager {

    /// Alias kept for readability at call sites within the app target.
    static let activityName = BedLockShared.activityName

    private let center = DeviceActivityCenter()
    private let persistence: PersistenceService

    init(persistence: PersistenceService) {
        self.persistence = persistence
    }

    /// (Re)starts monitoring using the given schedule. Safe to call any time the
    /// user edits their schedule; it replaces any previously registered activity.
    func applySchedule(_ schedule: ScheduleModel) {
        center.stopMonitoring([Self.activityName])

        guard schedule.isEnabled, !schedule.activeDays.isEmpty else {
            return
        }

        let deviceSchedule = DeviceActivitySchedule(
            intervalStart: schedule.startComponents,
            intervalEnd: schedule.endComponents,
            repeats: true
        )

        do {
            try center.startMonitoring(Self.activityName, during: deviceSchedule)
        } catch {
            // Monitoring registration can fail if Screen Time authorization has
            // been revoked. Surface this by leaving monitoring stopped; the
            // Dashboard shows an authorization warning banner in that case.
            print("BedLock: failed to start DeviceActivity monitoring: \(error)")
        }
    }

    func stopSchedule() {
        center.stopMonitoring([Self.activityName])
    }
}
