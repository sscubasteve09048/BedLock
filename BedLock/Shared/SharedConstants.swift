//
//  SharedConstants.swift
//  Shared (BedLock app + BedLockMonitor extension)
//
//  Constants that must be identical across the main app and the
//  DeviceActivityMonitor extension so they refer to the same scheduled
//  activity and shield store.
//
import DeviceActivity
import ManagedSettings

enum BedLockShared {
    static let activityName = DeviceActivityName("BedLock.MorningLock")
    static let shieldStoreName = ManagedSettingsStore.Name("BedLockShield")
}
