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
import WidgetKit

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
        if isOn && !PorkPause.isOn && (focusing || s.phase == .overtime) {
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
        if isOn && !PorkPause.isOn && StrictRules.isOn(.night, now: now) && st.isNight(now) {
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
        guard !PorkPause.isOn else { return }
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
        if isOn && StrictRules.isOn(.promise, now: now) && DayPlans.needsPromise(DayPlans.all(), now: now) {
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
        WidgetCenter.shared.reloadAllTimelines() // the Lock Screen shows today's time
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
            if StrictRules.isOn(.promise) {
                shieldDistractions(promiseStore)
                Alerts.say("That's today's promise 🐾", "You promised Pork \(Dur.text(TimeInterval(plan.promiseMin * 60))) of play time. Only focus apps for the rest of today.")
            } else {
                Alerts.say("That's today's promise 🐾", "You promised Pork \(Dur.text(TimeInterval(plan.promiseMin * 60))) of play time, and it's used up. Pork trusts you to stop here.")
            }
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
        if promiseReachedToday && StrictRules.isOn(.promise) { shieldDistractions(promiseStore) }
    }

    // MARK: this pick-up (full version: counted by Screen Time)

    /// Covers distraction apps with Pork's paws after 12 minutes (optional).
    static let pawStore = ManagedSettingsStore(named: ManagedSettingsStore.Name("porkPaws"))
    static let pickUpActivity = DeviceActivityName("pork.pickup")
    static let pauseActivity = DeviceActivityName("pork.pause")

    static var pawCovered: Bool { PorkStore.defaults.bool(forKey: "pawCovered") }

    /// A new pick-up: count distraction minutes from now, minute by minute.
    static func startPickUp(now: Date = Date()) {
        let center = DeviceActivityCenter()
        center.stopMonitoring([pickUpActivity])
        uncoverPaws()
        let d = PorkStore.defaults
        for k in ["puAll", "puFocus"] { d.set(0, forKey: k) }
        d.set(false, forKey: "puNudged")
        d.set(false, forKey: "puNotes")
        d.set(false, forKey: "puBody")
        d.set(PorkStore.load().settings.notesMin + 2, forKey: "puNextCover")
        guard isOn else { return }
        let cal = Calendar.current
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let count = countApps
        let focus = focusApps.applicationTokens
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for m in 1...90 {
            events[DeviceActivityEvent.Name("all.\(m)")] = DeviceActivityEvent(
                applications: count.applicationTokens, categories: count.categoryTokens,
                webDomains: count.webDomainTokens, threshold: DateComponents(minute: m))
            if !focus.isEmpty {
                events[DeviceActivityEvent.Name("focus.\(m)")] = DeviceActivityEvent(
                    applications: focus, threshold: DateComponents(minute: m))
            }
        }
        try? center.startMonitoring(pickUpActivity, during: DeviceActivitySchedule(
            intervalStart: cal.dateComponents(parts, from: now),
            intervalEnd: cal.dateComponents(parts, from: now.addingTimeInterval(4 * 3600)), repeats: false),
            events: events)
    }

    /// The monitor heard another minute of phone use in this pick-up.
    static func pickUpReached(_ name: String) {
        let parts = name.split(separator: ".")
        guard parts.count == 2, let mins = Int(parts[1]) else { return }
        let d = PorkStore.defaults
        let key = parts[0] == "all" ? "puAll" : "puFocus"
        d.set(max(d.integer(forKey: key), mins), forKey: key)
        let play = max(0, d.integer(forKey: "puAll") - d.integer(forKey: "puFocus"))
        PickUp.setMinutes(play)
        PickUp.touch()
        guard !PorkPause.isOn else { return }
        let st = PorkStore.load().settings
        if d.integer(forKey: "puAll") >= 45, !d.bool(forKey: "puBody") {
            d.set(true, forKey: "puBody")
            Alerts.bodyCheck(after: 1)
        }
        if play >= st.nudgeMin, !d.bool(forKey: "puNudged") {
            d.set(true, forKey: "puNudged")
            Alerts.say("Pork is scratching the door 🐾", "\(play) min on distractions this time. Pork wants you back!")
        }
        if play >= st.notesMin, !d.bool(forKey: "puNotes") {
            d.set(true, forKey: "puNotes")
            let todos = (d.stringArray(forKey: "todoPreview") ?? []).prefix(4).map { "• " + $0 }.joined(separator: "\n")
            Alerts.say("\(play) min this time · \(Dur.text(TimeInterval(playUsedToday * 60))) today 📝",
                       todos.isEmpty ? "Tap to see your to-dos with Pork." : "To do:\n" + todos)
            if st.pawsOn && StrictRules.limitsOn() { Alerts.paws() }
        }
        if StrictRules.isOn(.paws), play >= d.integer(forKey: "puNextCover"), d.integer(forKey: "puNextCover") > 0, !pawCovered {
            shieldDistractions(pawStore)
            d.set(true, forKey: "pawCovered")
        }
    }

    /// "Go on, 5 more minutes" on the paw screen.
    static func uncoverPaws(more: Int = 5) {
        pawStore.clearAllSettings()
        let d = PorkStore.defaults
        if d.bool(forKey: "pawCovered") {
            d.set(PickUp.minutes + more, forKey: "puNextCover")
        }
        d.set(false, forKey: "pawCovered")
    }

    /// A focus app was opened (or Pork's gate said "back to work").
    static func endPickUp() {
        DeviceActivityCenter().stopMonitoring([pickUpActivity])
        pawStore.clearAllSettings()
        PorkStore.defaults.set(false, forKey: "pawCovered")
    }

    // MARK: ⏸ pause 30 minutes

    static func pause(minutes: Int = 30) {
        PorkPause.start(minutes: minutes)
        for s in [store, nightStore, morningStore, promiseStore, pawStore] { s.clearAllSettings() }
        let center = DeviceActivityCenter()
        center.stopMonitoring([pauseActivity])
        let now = Date()
        let cal = Calendar.current
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        try? center.startMonitoring(pauseActivity, during: DeviceActivitySchedule(
            intervalStart: cal.dateComponents(parts, from: now),
            intervalEnd: cal.dateComponents(parts, from: now.addingTimeInterval(TimeInterval(max(15, minutes) * 60))),
            repeats: false))
    }

    /// The pause is over (or ended early): everything comes back.
    static func resumeAll() {
        PorkPause.end()
        DeviceActivityCenter().stopMonitoring([pauseActivity])
        apply(PorkStore.load())
        applyMorning()
        if promiseReachedToday && StrictRules.isOn(.promise) { shieldDistractions(promiseStore) }
    }

    /// After a strict rule changes (or a change ran out): block or unblock now.
    static func applyRules() {
        let s = PorkStore.load()
        applyNight(s.settings)
        applyMorning()
        if !StrictRules.isOn(.promise) { promiseStore.clearAllSettings() }
        else if promiseReachedToday { shieldDistractions(promiseStore) }
        if !StrictRules.isOn(.paws) { uncoverPaws() }
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
