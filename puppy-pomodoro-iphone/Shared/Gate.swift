// The unlock check: when you open an app, Pork's screen asks for a photo or a
// sentence first. It goes in your diary, then your apps open.
// - Apps you pick as "always open" (Phone, Messages, Maps, Wallet, Pork…)
//   never ask.
// - It asks again after the phone has been locked for a minute (the app
//   notices the lock, see App/LockWatcher.swift), or after 20 minutes as a
//   backup if iOS closed Pork in the background.
// - "Not now" always lets you in (saved in the diary as skipped).
// - "Skip today" turns it off until midnight.

import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

struct GateSettings: Codable, Equatable {
    var on = false          // turned on in Settings after picking the always-open apps
    var level = 1           // see DiaryLevel
    var graceSec = 60       // locked for less than this: no new check
    var backupMin = 20      // the check comes back after this, whatever happens
    var watchLock = true    // notice the lock (keeps Pork awake in the background)

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = GateSettings()
        on = try c.decodeIfPresent(Bool.self, forKey: .on) ?? d.on
        level = try c.decodeIfPresent(Int.self, forKey: .level) ?? d.level
        graceSec = try c.decodeIfPresent(Int.self, forKey: .graceSec) ?? d.graceSec
        backupMin = try c.decodeIfPresent(Int.self, forKey: .backupMin) ?? d.backupMin
        watchLock = try c.decodeIfPresent(Bool.self, forKey: .watchLock) ?? d.watchLock
    }

    func cleaned() -> GateSettings {
        var s = self
        s.level = min(4, max(1, level))
        s.graceSec = min(10 * 60, max(0, graceSec))
        s.backupMin = min(120, max(15, backupMin)) // Screen Time can't wake Pork sooner than 15 min
        return s
    }
}

enum Gate {
    static let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("porkGate"))
    static let backupActivity = DeviceActivityName("pork.gateBackup")
    static let dayActivity = DeviceActivityName("pork.gateDay")
    private static var d: UserDefaults { PorkStore.defaults }

    static var settings: GateSettings {
        get {
            guard let data = d.data(forKey: "gate"),
                  let s = try? JSONDecoder().decode(GateSettings.self, from: data) else { return GateSettings() }
            return s
        }
        set {
            if let data = try? JSONEncoder().encode(newValue.cleaned()) { d.set(data, forKey: "gate") }
        }
    }

    /// Apps that never ask (picked in Settings).
    static var alwaysOpen: FamilyActivitySelection {
        get {
            guard let data = d.data(forKey: "gateApps"),
                  let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else { return FamilyActivitySelection() }
            return sel
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { d.set(data, forKey: "gateApps") }
        }
    }

    /// Apps are open (no check) until this time.
    static var openUntil: Date? {
        get { d.object(forKey: "gateOpenUntil") as? Date }
        set { d.set(newValue, forKey: "gateOpenUntil") }
    }

    /// When the current check began (you tapped Pork's screen, or opened Pork).
    static var startedAt: Date? {
        get { d.object(forKey: "gateStartedAt") as? Date }
        set { d.set(newValue, forKey: "gateStartedAt") }
    }

    static func noteStart(_ now: Date = Date()) {
        if startedAt == nil || now.timeIntervalSince(startedAt!) > 30 * 60 { startedAt = now }
    }

    static var skippedToday: Bool { d.string(forKey: "gateSkipDay") == Days.key(Date()) }

    static func skipToday(_ on: Bool) {
        on ? d.set(Days.key(Date()), forKey: "gateSkipDay") : d.removeObject(forKey: "gateSkipDay")
        apply()
    }

    static func isOpen(_ now: Date = Date()) -> Bool { (openUntil ?? .distantPast) > now }

    /// Pork is asking now: the next app you open shows his screen.
    static func isAsking(_ now: Date = Date()) -> Bool {
        settings.on && ScreenTime.isOn && !skippedToday && !isOpen(now)
    }

    /// Put Pork's screen up (or take it down) to match the moment.
    static func apply(_ now: Date = Date()) {
        if isAsking(now) {
            store.shield.applicationCategories = .all(except: alwaysOpen.applicationTokens)
        } else {
            store.clearAllSettings()
        }
    }

    /// You wrote (or tapped "Not now"): apps open, and the backup check is set.
    static func open(_ now: Date = Date()) {
        let until = now.addingTimeInterval(TimeInterval(settings.backupMin * 60))
        openUntil = until
        startedAt = nil
        store.clearAllSettings()
        let center = DeviceActivityCenter()
        center.stopMonitoring([backupActivity])
        let cal = Calendar.current
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        try? center.startMonitoring(backupActivity, during: DeviceActivitySchedule(
            intervalStart: cal.dateComponents(parts, from: now),
            intervalEnd: cal.dateComponents(parts, from: until), repeats: false))
    }

    /// Ask again from now on (the phone was locked, or the backup time ran out).
    static func arm(_ now: Date = Date()) {
        openUntil = nil
        DeviceActivityCenter().stopMonitoring([backupActivity])
        apply(now)
    }

    /// "Not now": in the diary as skipped, and the apps open.
    static func notNow(_ now: Date = Date()) {
        Diary.add(DiaryEntry(started: startedAt ?? now, saved: now, kind: .skip, level: settings.level))
        open(now)
    }

    /// Wakes the monitor every midnight, so "Skip today" ends by itself.
    static func scheduleDay() {
        let center = DeviceActivityCenter()
        center.stopMonitoring([dayActivity])
        guard settings.on, ScreenTime.isOn else { return }
        try? center.startMonitoring(dayActivity, during: DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59), repeats: true))
    }

    /// Turned off in Settings: everything stops.
    static func stop() {
        store.clearAllSettings()
        DeviceActivityCenter().stopMonitoring([backupActivity, dayActivity])
    }
}
