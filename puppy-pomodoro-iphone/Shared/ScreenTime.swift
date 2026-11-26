// Screen Time, for the focus clock (the iPhone version of closing and
// blocking non-focus tabs). Only while a focus session runs:
// - every app except your focus apps shows Pork's screen, and Safari only
//   opens focus sites;
// - when the break is over, the blocked-app screen comes back with
//   "Let Pork out".
// Outside a focus session nothing here blocks anything. (The unlock check is
// separate: see Gate.swift.)

import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum ScreenTime {
    static let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("pork"))
    static let goalActivity = DeviceActivityName("pork.goal")
    static let overtimeActivity = DeviceActivityName("pork.breakOver")

    /// Set by the app once you allow Screen Time.
    static var isOn: Bool {
        get { PorkStore.defaults.bool(forKey: "blockingOn") }
        set { PorkStore.defaults.set(newValue, forKey: "blockingOn") }
    }

    /// Apps you picked as focus apps (green in the tracker, open during focus).
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

    /// Does the focus clock keep this app closed right now?
    static func focusBlocks(_ token: ApplicationToken?, _ s: PorkState) -> Bool {
        guard isOn, (s.phase == .focus && !s.paused) || s.phase == .overtime else { return false }
        guard let token else { return true }
        return !focusApps.applicationTokens.contains(token)
    }

    static func apply(_ s: PorkState) {
        let focusing = s.phase == .focus && !s.paused
        if isOn && (focusing || s.phase == .overtime) {
            store.shield.applicationCategories = .all(except: focusApps.applicationTokens)
            if focusing {
                store.webContent.blockedByFilter = .all(except: Set(allowedHosts(s.settings.focusSites).map { WebDomain(domain: $0) }))
            } else {
                store.webContent.blockedByFilter = nil
            }
        } else {
            store.clearAllSettings()
        }
        watch(s)
    }

    /// Version 6 dropped the night block, the promise, the paw screen and
    /// the pick-up counting. Take down anything they left behind.
    static func cleanUpOldRules() {
        let d = PorkStore.defaults
        guard d.integer(forKey: "cleanedFor") < 6 else { return }
        for name in ["porkNight", "porkMorning", "porkPromise", "porkPaws"] {
            ManagedSettingsStore(named: ManagedSettingsStore.Name(name)).clearAllSettings()
        }
        DeviceActivityCenter().stopMonitoring(["pork.night", "pork.morning", "pork.promise", "pork.promiseLate",
                                               "pork.grace", "pork.pickup", "pork.pause"].map { DeviceActivityName($0) })
        d.set(6, forKey: "cleanedFor")
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
