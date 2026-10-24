// Sleep countdown: after bedtime (or "I'm going to sleep"), the main screen
// and the Lock Screen show how much sleep is left until you get up (8:30 am
// on weekdays, 10:30 am on weekends; Settings).

import Foundation

enum SleepMode {
    private static var defaults: UserDefaults { PorkStore.defaults }

    static var sleptAt: Date? { defaults.object(forKey: "sleptAt") as? Date }
    static var upAt: Date? { defaults.object(forKey: "upAt") as? Date }

    /// Tonight's bedtime: from today's promise, or the late-night setting.
    static func bedtime(_ st: PorkSettings, now: Date = Date()) -> Int? {
        if let plan = DayPlans.current(now) { return plan.bedtime }
        return st.nightOn ? st.nightStart : nil
    }

    /// When to get up, if it's sleep time now.
    static func wake(_ st: PorkSettings = PorkStore.load().settings, now: Date = Date()) -> Date? {
        st.wakeIfSleeping(now: now, bedtime: bedtime(st, now: now), sleptAt: sleptAt, upAt: upAt)
    }

    /// "I'm going to sleep 🌙"
    static func start(_ now: Date = Date()) {
        defaults.set(now, forKey: "sleptAt")
        defaults.removeObject(forKey: "upAt")
    }

    /// "I'm up ☀️" (also when today's promise is made).
    static func end(_ now: Date = Date()) {
        defaults.set(now, forKey: "upAt")
    }
}
