// Blocking distractions with Screen Time (the iPhone version of closing and
// blocking non-focus tabs).
// - Focus: every app except your focus apps shows Pork's screen, and Safari
//   only opens focus sites.
// - Break is over: the blocked-app screen comes back with "Let Pork out".
// Not in the Lite version (Screen Time needs a paid Apple developer account).

#if !LITE
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum ScreenTime {
    static let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("pork"))
    /// Late-night blocking has its own store, so focus and night don't undo each other.
    static let nightStore = ManagedSettingsStore(named: ManagedSettingsStore.Name("porkNight"))
    static let nightActivity = DeviceActivityName("pork.night")
    static let goalActivity = DeviceActivityName("pork.goal")
    static let overtimeActivity = DeviceActivityName("pork.breakOver")

    /// Set by the app once you allow Screen Time and turn blocking on.
    static var isOn: Bool {
        get { PorkStore.defaults.bool(forKey: "blockingOn") }
        set { PorkStore.defaults.set(newValue, forKey: "blockingOn") }
    }

    /// Apps (and websites) you picked as focus apps.
    static var focusApps: FamilyActivitySelection {
        get {
            guard let data = PorkStore.defaults.data(forKey: "focusApps"),
                  let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else { return FamilyActivitySelection() }
            return sel
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                PorkStore.defaults.set(data, forKey: "focusApps")
            }
        }
    }

    static func apply(_ s: PorkState) {
        let focusing = s.phase == .focus && !s.paused
        if isOn && (focusing || s.phase == .overtime) {
            let apps = focusApps
            store.shield.applicationCategories = .all(except: apps.applicationTokens)
            if focusing {
                store.webContent.blockedByFilter = .all(except: Set(allowedHosts(s.settings.focusSites).map { WebDomain(domain: $0) }))
            } else {
                store.webContent.blockedByFilter = nil
            }
        } else {
            store.clearAllSettings()
        }
        watch(s)
        applyNight(s.settings)
    }

    /// Late at night: only focus apps and focus sites, focus session or not.
    static func applyNight(_ st: PorkSettings, now: Date = Date()) {
        if isOn && st.isNight(now) {
            nightStore.shield.applicationCategories = .all(except: focusApps.applicationTokens)
            nightStore.webContent.blockedByFilter = .all(except: Set(allowedHosts(st.focusSites).map { WebDomain(domain: $0) }))
        } else {
            nightStore.clearAllSettings()
        }
    }

    /// Ask Screen Time to wake the monitor at the start and end of the night
    /// every day.
    static func scheduleNight(_ st: PorkSettings) {
        let center = DeviceActivityCenter()
        center.stopMonitoring([nightActivity])
        applyNight(st)
        guard isOn, st.nightOn, st.nightStart != st.nightEnd else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: st.nightStart / 60, minute: st.nightStart % 60),
            intervalEnd: DateComponents(hour: st.nightEnd / 60, minute: st.nightEnd % 60),
            repeats: true)
        try? center.startMonitoring(nightActivity, during: schedule)
    }

    // MARK: today's promise

    /// Blocks distractions in the morning until today's promise is made.
    static let morningStore = ManagedSettingsStore(named: ManagedSettingsStore.Name("porkMorning"))
    /// Blocks distractions when today's promised play time is used up.
    static let promiseStore = ManagedSettingsStore(named: ManagedSettingsStore.Name("porkPromise"))
    static let morningActivity = DeviceActivityName("pork.morning")
    static let promiseActivity = DeviceActivityName("pork.promise")
    static let promiseLateActivity = DeviceActivityName("pork.promiseLate") // after midnight, until a late bedtime
    static let graceActivity = DeviceActivityName("pork.grace")
    private static let step = 10 // minutes between usage checks

    /// What counts as phone time: pick "All Apps & Categories" in Settings.
    /// (Focus apps are taken out again, so only play time counts.)
    static var countApps: FamilyActivitySelection {
        get {
            guard let data = PorkStore.defaults.data(forKey: "countApps"),
                  let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else { return FamilyActivitySelection() }
            return sel
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                PorkStore.defaults.set(data, forKey: "countApps")
            }
        }
    }

    private static func shieldDistractions(_ store: ManagedSettingsStore) {
        store.shield.applicationCategories = .all(except: focusApps.applicationTokens)
    }

    /// Every day at 8 am: block distractions until the promise is made.
    static func scheduleMorning() {
        let center = DeviceActivityCenter()
        center.stopMonitoring([morningActivity])
        applyMorning()
        guard isOn else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: DayPlans.wakeHour, minute: 0),
            intervalEnd: DateComponents(hour: DayPlans.wakeHour, minute: 30),
            repeats: true)
        try? center.startMonitoring(morningActivity, during: schedule)
    }

    static func applyMorning(now: Date = Date()) {
        if isOn && DayPlans.needsPromise(DayPlans.all(), now: now) {
            shieldDistractions(morningStore)
        } else {
            morningStore.clearAllSettings()
        }
    }

    /// Play time used for the running promise (minutes), counted by the monitor.
    static var playUsedToday: Int {
        let d = PorkStore.defaults
        guard let plan = DayPlans.current(), d.string(forKey: "useDay") == plan.day else { return 0 }
        return max(0, d.integer(forKey: "allMin") - d.integer(forKey: "focusMin"))
    }

    static var promiseReachedToday: Bool {
        guard let plan = DayPlans.current() else { return false }
        return PorkStore.defaults.string(forKey: "promiseReachedDay") == plan.day
    }

    /// Start counting today's play time, from now until bedtime.
    static func startPromise(_ plan: DayPlan, now: Date = Date()) {
        let center = DeviceActivityCenter()
        center.stopMonitoring([promiseActivity, promiseLateActivity, graceActivity])
        morningStore.clearAllSettings()
        promiseStore.clearAllSettings()
        let d = PorkStore.defaults
        if d.string(forKey: "useDay") != plan.day {
            d.set(plan.day, forKey: "useDay")
            d.set(0, forKey: "allMin")
            d.set(0, forKey: "focusMin")
            d.removeObject(forKey: "promiseWarned")
        }
        d.set(d.integer(forKey: "allMin"), forKey: "allBase")
        d.set(d.integer(forKey: "focusMin"), forKey: "focusBase")
        guard isOn else { return }

        // Until bedtime. A bedtime after midnight (like 4 am) is counted in two
        // parts: now until 11:59 pm, then midnight until bedtime.
        let cal = Calendar.current
        let midnight = cal.startOfDay(for: now).addingTimeInterval(24 * 3600)
        let late = plan.bedtime < 12 * 60
        let end = late ? midnight.addingTimeInterval(-60)
                       : cal.startOfDay(for: now).addingTimeInterval(TimeInterval(plan.bedtime * 60))
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let count = countApps
        let focus = focusApps.applicationTokens
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for k in 1...(12 * 60 / step) {
            let mins = k * step
            events[DeviceActivityEvent.Name("all.\(mins)")] = DeviceActivityEvent(
                applications: count.applicationTokens, categories: count.categoryTokens,
                webDomains: count.webDomainTokens, threshold: DateComponents(minute: mins))
            if !focus.isEmpty {
                events[DeviceActivityEvent.Name("focus.\(mins)")] = DeviceActivityEvent(
                    applications: focus, threshold: DateComponents(minute: mins))
            }
        }
        if end.timeIntervalSince(now) >= 15 * 60 {
            try? center.startMonitoring(promiseActivity, during: DeviceActivitySchedule(
                intervalStart: cal.dateComponents(parts, from: now),
                intervalEnd: cal.dateComponents(parts, from: end), repeats: false), events: events)
        }
        if late && plan.bedtime >= 15 {
            try? center.startMonitoring(promiseLateActivity, during: DeviceActivitySchedule(
                intervalStart: cal.dateComponents(parts, from: midnight),
                intervalEnd: cal.dateComponents(parts, from: midnight.addingTimeInterval(TimeInterval(plan.bedtime * 60))),
                repeats: false), events: events)
        }
    }

    /// Midnight, with a late bedtime: keep adding to the same day's play time.
    static func promiseLateStarted() {
        let d = PorkStore.defaults
        d.set(d.integer(forKey: "allMin"), forKey: "allBase")
        d.set(d.integer(forKey: "focusMin"), forKey: "focusBase")
    }

    /// The monitor heard "all.30" or "focus.20": update today's play time.
    static func usageReached(_ name: String) {
        let parts = name.split(separator: ".")
        guard parts.count == 2, let mins = Int(parts[1]) else { return }
        let d = PorkStore.defaults
        let key = parts[0] == "all" ? "allMin" : "focusMin"
        let base = d.integer(forKey: parts[0] == "all" ? "allBase" : "focusBase")
        d.set(max(d.integer(forKey: key), base + mins), forKey: key)
        checkPromise()
    }

    /// Warn at 3/4 of the promise; block distractions when it's used up.
    static func checkPromise() {
        guard let plan = DayPlans.current() else { return }
        let used = playUsedToday
        let d = PorkStore.defaults
        if used * 4 >= plan.promiseMin * 3, d.string(forKey: "promiseWarned") != plan.day, used < plan.promiseMin {
            d.set(plan.day, forKey: "promiseWarned")
            Alerts.say("Pork's promise 🐾", "\(Dur.text(TimeInterval((plan.promiseMin - used) * 60))) of play time left today.")
        }
        if used >= plan.promiseMin, !promiseReachedToday {
            d.set(plan.day, forKey: "promiseReachedDay")
            shieldDistractions(promiseStore)
            Alerts.say("That's today's promise 🐾", "You promised Pork \(Dur.text(TimeInterval(plan.promiseMin * 60))) of play time. Only focus apps for the rest of today.")
        }
    }

    /// "15 more minutes": unblock now, block again in 15 minutes.
    static func grace() {
        promiseStore.clearAllSettings()
        let d = PorkStore.defaults
        d.set(d.integer(forKey: "graceCount") + 1, forKey: "graceCount")
        let cal = Calendar.current
        let now = Date()
        let parts: Set<Calendar.Component> = [.hour, .minute, .second]
        let schedule = DeviceActivitySchedule(intervalStart: cal.dateComponents(parts, from: now),
                                              intervalEnd: cal.dateComponents(parts, from: now.addingTimeInterval(15 * 60)),
                                              repeats: false)
        try? DeviceActivityCenter().startMonitoring(graceActivity, during: schedule)
    }

    static func graceOver() {
        if promiseReachedToday { shieldDistractions(promiseStore) }
    }

    /// Players that focus sites embed (for example the YouTube player on the
    /// danmu site). They only show videos inside other pages, so allowing them
    /// doesn't open YouTube itself.
    static let embeddedPlayers = ["youtube-nocookie.com", "googlevideo.com", "ytimg.com", "ggpht.com"]

    /// Websites Safari may open during focus. Screen Time only knows whole
    /// sites: "sssamui.github.io/morethanaproject/danmu" allows
    /// sssamui.github.io, and youtube.com/@channel lines are left out (that
    /// would allow all of YouTube).
    static func allowedHosts(_ focusSites: [String]) -> [String] {
        var hosts: [String] = []
        for site in focusSites.compactMap(FocusSite.parse) {
            let isYouTube = site.host == "youtube.com" || site.host.hasSuffix(".youtube.com")
            if isYouTube && !site.path.isEmpty { continue }
            hosts.append(site.host)
        }
        if !hosts.isEmpty { hosts += embeddedPlayers }
        var seen = Set<String>()
        return (hosts + hosts.map { "www." + $0 }).filter { seen.insert($0).inserted }
    }

    /// Put the blocked-app screens up again so they show the new message
    /// (focus goal reached, or break over).
    static func refresh(_ s: PorkState) {
        store.clearAllSettings()
        apply(s)
    }

    /// Wake the monitor extension at the focus goal and when the break runs
    /// out, so the blocked-app screen changes even if the app isn't open.
    private static func watch(_ s: PorkState) {
        let center = DeviceActivityCenter()
        center.stopMonitoring([goalActivity, overtimeActivity])
        guard isOn, !s.paused, let end = s.endsAt, end > Date() else { return }
        let activity: DeviceActivityName
        switch s.phase {
        case .focus: activity = goalActivity
        case .break: activity = overtimeActivity
        default: return
        }
        let cal = Calendar.current
        let parts: Set<Calendar.Component> = [.hour, .minute, .second]
        // Screen Time needs the watched time to be at least 15 minutes long.
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents(parts, from: end),
            intervalEnd: cal.dateComponents(parts, from: end.addingTimeInterval(60 * 60)),
            repeats: false)
        try? center.startMonitoring(activity, during: schedule)
    }
}
#endif
