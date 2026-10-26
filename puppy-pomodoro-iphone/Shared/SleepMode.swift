// Bedtime and sleep countdowns, for the app, the widgets and the Lock Screen:
// - from 10 pm until bedtime: how long until it's time to sleep;
// - after bedtime (or "I'm going to sleep"): how much sleep is left until
//   you get up (8:30 am on weekdays, 10:30 am on weekends; Settings).

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

    /// From 10 pm until bedtime: the bedtime to count down to.
    static func bedtimeSoon(_ st: PorkSettings = PorkStore.load().settings, now: Date = Date()) -> Date? {
        if wake(st, now: now) != nil { return nil } // already sleeping
        return SleepPlan.bedtimeIfEvening(now: now, bedtime: bedtime(st, now: now),
                                          weekday: st.wakeWeekday, weekend: st.wakeWeekend)
    }

    /// When the countdowns change by themselves (for widget timelines).
    static func changes(_ st: PorkSettings, now: Date = Date()) -> [Date] {
        guard let b = bedtime(st, now: now) else { return [] }
        let n = SleepPlan.night(now: now, bedtime: b, weekday: st.wakeWeekday, weekend: st.wakeWeekend)
        return [n.start, n.bedtime, n.wake].filter { $0 > now }
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
