//
//  ScheduleViewModel.swift
//  BedLock
//
//  Drives the Schedule editing screen, persisting changes and re-registering the
//  DeviceActivity monitoring schedule whenever the user saves.
//
import Foundation
import Observation

@MainActor
@Observable
final class ScheduleViewModel {

    var schedule: ScheduleModel
    var didSaveConfirmation = false

    private let persistence: PersistenceService
    private let scheduleManager: ScheduleManager

    init(persistence: PersistenceService, scheduleManager: ScheduleManager) {
        self.persistence = persistence
        self.scheduleManager = scheduleManager
        self.schedule = persistence.loadSchedule()
    }

    var startTimeBinding: Date {
        get {
            var components = DateComponents()
            components.hour = schedule.startHour
            components.minute = schedule.startMinute
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            schedule.startHour = components.hour ?? 7
            schedule.startMinute = components.minute ?? 0
        }
    }

    var endTimeBinding: Date {
        get {
            var components = DateComponents()
            components.hour = schedule.endHour
            components.minute = schedule.endMinute
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            schedule.endHour = components.hour ?? 9
            schedule.endMinute = components.minute ?? 0
        }
    }

    func toggleDay(_ day: Weekday) {
        if schedule.activeDays.contains(day) {
            schedule.activeDays.remove(day)
        } else {
            schedule.activeDays.insert(day)
        }
    }

    func save() {
        persistence.saveSchedule(schedule)
        scheduleManager.applySchedule(schedule)
        didSaveConfirmation = true
    }
}
