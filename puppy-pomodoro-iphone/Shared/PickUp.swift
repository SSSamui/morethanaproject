// "This pick-up" (the distraction time since you passed Pork's gate) and the
// 30-minute pause. Shared by the app, the widgets and the Screen Time
// extensions.

import Foundation

/// ⏸ "Pause 30 min": no gates, reminders or blocking until it runs out.
enum PorkPause {
    private static var d: UserDefaults { PorkStore.defaults }

    static var until: Date? {
        guard let u = d.object(forKey: "pausedUntil") as? Date, u > Date() else { return nil }
        return u
    }
    static var isOn: Bool { until != nil }

    static func start(minutes: Int = 30, now: Date = Date()) {
        d.set(now.addingTimeInterval(TimeInterval(minutes * 60)), forKey: "pausedUntil")
    }

    static func end() { d.removeObject(forKey: "pausedUntil") }
}

/// One pick-up on distraction apps. It starts with the first distraction app
/// and ends when you open a focus app, or after 20 quiet minutes.
enum PickUp {
    private static var d: UserDefaults { PorkStore.defaults }
    static let quiet: TimeInterval = 20 * 60

    static var start: Date? { d.object(forKey: "pickupStart") as? Date }
    static var lastUse: Date? { d.object(forKey: "pickupLast") as? Date }

    /// Distraction minutes in this pick-up, counted by Screen Time (full version).
    static var minutes: Int { isActive() ? d.integer(forKey: "pickupMin") : 0 }

    static func isActive(_ now: Date = Date()) -> Bool {
        guard let s = start else { return false }
        return now.timeIntervalSince(lastUse ?? s) < quiet && now.timeIntervalSince(s) < 4 * 3600
    }

    static func begin(_ now: Date = Date()) {
        d.set(now, forKey: "pickupStart")
        d.set(now, forKey: "pickupLast")
        d.set(0, forKey: "pickupMin")
    }

    static func touch(_ now: Date = Date()) { d.set(now, forKey: "pickupLast") }

    static func setMinutes(_ m: Int) { d.set(m, forKey: "pickupMin") }

    static func end() {
        d.removeObject(forKey: "pickupStart")
        d.removeObject(forKey: "pickupLast")
        d.set(0, forKey: "pickupMin")
    }
}

/// Today's distraction time in a few characters, for the Lock Screen.
enum TodayUsage {
    static func text() -> String {
        #if !LITE
        if ScreenTime.isOn { return Dur.text(TimeInterval(ScreenTime.playUsedToday * 60)) + " today" }
        #endif
        let d = PorkStore.defaults
        let opens = d.string(forKey: "distractDay") == DayPlans.dayKey(Date()) ? d.integer(forKey: "distractOpens") : 0
        return "\(opens)× today"
    }
}
