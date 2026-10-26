// Sleep countdown: from bedtime (or when you tap "I'm going to sleep") until
// you get up: 8:30 am on weekdays, 10:30 am on weekends (Settings).

import Foundation

enum SleepPlan {
    static func isWeekend(_ date: Date, calendar: Calendar = .current) -> Bool {
        let wd = calendar.component(.weekday, from: date) // 1 = Sunday, 7 = Saturday
        return wd == 1 || wd == 7
    }

    /// The next wake-up time after `date`.
    static func nextWake(after date: Date, weekday: Int, weekend: Int, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: date)
        let t = today.addingTimeInterval(TimeInterval((isWeekend(today, calendar: calendar) ? weekend : weekday) * 60))
        if date < t { return t }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return tomorrow.addingTimeInterval(TimeInterval((isWeekend(tomorrow, calendar: calendar) ? weekend : weekday) * 60))
    }

    /// Hour the bedtime countdown starts (10 pm).
    static let eveningHour = 22

    /// Tonight: when the "time to sleep" countdown starts (10 pm, or 2 hours
    /// before an earlier bedtime), bedtime, and when to get up. During the
    /// night it's the night we're in.
    static func night(now: Date, bedtime: Int, weekday: Int, weekend: Int,
                      calendar: Calendar = .current) -> (start: Date, bedtime: Date, wake: Date) {
        let today = calendar.startOfDay(for: now).addingTimeInterval(TimeInterval(bedtime * 60))
        for b in [today.addingTimeInterval(-24 * 3600), today, today.addingTimeInterval(24 * 3600)] {
            let wake = nextWake(after: b, weekday: weekday, weekend: weekend, calendar: calendar)
            guard wake > now else { continue }
            let dayStart = calendar.startOfDay(for: b)
            let start: Date
            if bedtime < 12 * 60 {
                start = dayStart.addingTimeInterval(TimeInterval((eveningHour - 24) * 3600)) // 10 pm the evening before
            } else if bedtime >= eveningHour * 60 {
                start = dayStart.addingTimeInterval(TimeInterval(eveningHour * 3600))
            } else {
                start = b.addingTimeInterval(-2 * 3600) // an early bedtime: 2 hours before
            }
            return (start, b, wake)
        }
        let b = today.addingTimeInterval(24 * 3600)
        return (b.addingTimeInterval(-2 * 3600), b, nextWake(after: b, weekday: weekday, weekend: weekend, calendar: calendar))
    }

    /// After 10 pm and before bedtime: the bedtime to count down to.
    static func bedtimeIfEvening(now: Date, bedtime: Int?, weekday: Int, weekend: Int,
                                 calendar: Calendar = .current) -> Date? {
        guard let bedtime else { return nil }
        let n = night(now: now, bedtime: bedtime, weekday: weekday, weekend: weekend, calendar: calendar)
        return now >= n.start && now < n.bedtime ? n.bedtime : nil
    }

    /// If it's sleep time now, when to get up. Sleep time starts at bedtime
    /// (minutes after midnight) or when you said you're going to sleep, and
    /// ends at the wake-up time or when you said you're up.
    static func wakeIfSleeping(now: Date, bedtime: Int?, sleptAt: Date?, upAt: Date?,
                               weekday: Int, weekend: Int, calendar: Calendar = .current) -> Date? {
        var starts: [Date] = []
        if let sleptAt { starts.append(sleptAt) }
        if let bedtime {
            // the latest bedtime that already started, within the last 14 hours
            let today = calendar.startOfDay(for: now).addingTimeInterval(TimeInterval(bedtime * 60))
            let last = today <= now ? today : today.addingTimeInterval(-24 * 3600)
            if now.timeIntervalSince(last) < 14 * 3600 { starts.append(last) }
        }
        for start in starts.sorted(by: >) where start <= now {
            if let upAt, upAt >= start { continue }
            let wake = nextWake(after: start, weekday: weekday, weekend: weekend, calendar: calendar)
            if now < wake { return wake }
        }
        return nil
    }
}
