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
