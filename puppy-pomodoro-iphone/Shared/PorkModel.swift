// Puppy Pomodoro — the timer, treats and settings.
// Same rules as the Safari version (background.js). All timing is stored as
// dates, so the clock stays right while the app isn't running. The state lives
// in the App Group so the widgets and the Screen Time extensions can read it.

import Foundation

enum Phase: String, Codable {
    case idle, focus, `break`, overtime
}

enum Pose: String {
    case sleep, wait, pace, door, out
}

let porkTreats = ["🦴", "🍖", "🧀", "🥕", "🍪", "🍗", "🥩"]

/// After the break runs out, Pork paces this long, then scratches the door.
let paceSeconds: TimeInterval = 2 * 60

struct Treat: Codable, Hashable, Identifiable {
    var t: String
    var at: Date
    var bonus: Bool
    var id: Date { at }
}

struct Reward: Codable, Hashable {
    var at: Date
    var items: [String]
}

struct PorkSettings: Codable, Equatable {
    static let defaultFocusSites = [
        "mit.edu",
        "youtube.com/@mit",
        "youtube.com/@mitocw",
        "chatgpt.com", "chat.openai.com", "auth.openai.com",
        "claude.ai",
        "gemini.google.com", "accounts.google.com",
        "books.google.com", "openlibrary.org", "archive.org", "gutenberg.org",
        "libbyapp.com", "overdrive.com", "learning.oreilly.com"
    ]

    var focusMin = 25
    var breakMin = 5
    var bonusEveryMin = 5
    var sound = true
    var focusSites = PorkSettings.defaultFocusSites

    // "Pork says hi" when you pick up the phone
    var hiEnabled = true
    var hiSeconds = 60
    var hiGraceMin = 15
    var hiAlbum = "Pork"
    var hiMuted = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PorkSettings()
        focusMin = try c.decodeIfPresent(Int.self, forKey: .focusMin) ?? d.focusMin
        breakMin = try c.decodeIfPresent(Int.self, forKey: .breakMin) ?? d.breakMin
        bonusEveryMin = try c.decodeIfPresent(Int.self, forKey: .bonusEveryMin) ?? d.bonusEveryMin
        sound = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? d.sound
        focusSites = try c.decodeIfPresent([String].self, forKey: .focusSites) ?? d.focusSites
        hiEnabled = try c.decodeIfPresent(Bool.self, forKey: .hiEnabled) ?? d.hiEnabled
        hiSeconds = try c.decodeIfPresent(Int.self, forKey: .hiSeconds) ?? d.hiSeconds
        hiGraceMin = try c.decodeIfPresent(Int.self, forKey: .hiGraceMin) ?? d.hiGraceMin
        hiAlbum = try c.decodeIfPresent(String.self, forKey: .hiAlbum) ?? d.hiAlbum
        hiMuted = try c.decodeIfPresent(Bool.self, forKey: .hiMuted) ?? d.hiMuted
    }

    /// Keeps numbers in range and tidies the focus-site list.
    func cleaned() -> PorkSettings {
        var s = self
        s.focusMin = min(180, max(1, focusMin))
        s.breakMin = min(60, max(1, breakMin))
        s.bonusEveryMin = min(60, max(1, bonusEveryMin))
        s.hiSeconds = min(600, max(5, hiSeconds))
        s.hiGraceMin = min(240, max(0, hiGraceMin))
        var seen = Set<String>()
        s.focusSites = focusSites.compactMap(FocusSite.parse).map(\.text).filter { seen.insert($0).inserted }
        return s
    }
}

/// One line of the focus-site list: "mit.edu" or "youtube.com/@mitocw".
struct FocusSite {
    var host: String
    var path: String
    var text: String { host + path }

    static func parse(_ line: String) -> FocusSite? {
        var clean = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://", "http://", "www."] where clean.hasPrefix(prefix) {
            clean.removeFirst(prefix.count)
        }
        guard !clean.isEmpty else { return nil }
        if let slash = clean.firstIndex(of: "/") {
            var path = String(clean[slash...])
            while path.hasSuffix("/") { path.removeLast() }
            let host = String(clean[..<slash])
            return host.isEmpty ? nil : FocusSite(host: host, path: path)
        }
        return FocusSite(host: clean, path: "")
    }
}

struct PorkState: Codable {
    var phase: Phase = .idle
    var paused = false
    var endsAt: Date?            // focus goal / end of break (not paused)
    var remaining: TimeInterval? // seconds to endsAt while paused (negative past the goal)
    var overtimeFrom: Date?      // when the break ran out and Pork went to the door
    var target: TimeInterval = 0 // length of this focus goal or break
    var carry: TimeInterval = 0  // late-from-break time added to this focus goal
    var sessions = 0             // finished focus sessions
    var treats: [Treat] = []
    var lastReward: Reward?
    var settings = PorkSettings()
    var hiAllowedUntil: Date?    // Pork won't say hi again before this

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        phase = try c.decodeIfPresent(Phase.self, forKey: .phase) ?? .idle
        paused = try c.decodeIfPresent(Bool.self, forKey: .paused) ?? false
        endsAt = try c.decodeIfPresent(Date.self, forKey: .endsAt)
        remaining = try c.decodeIfPresent(TimeInterval.self, forKey: .remaining)
        overtimeFrom = try c.decodeIfPresent(Date.self, forKey: .overtimeFrom)
        target = try c.decodeIfPresent(TimeInterval.self, forKey: .target) ?? 0
        carry = try c.decodeIfPresent(TimeInterval.self, forKey: .carry) ?? 0
        sessions = try c.decodeIfPresent(Int.self, forKey: .sessions) ?? 0
        treats = try c.decodeIfPresent([Treat].self, forKey: .treats) ?? []
        lastReward = try c.decodeIfPresent(Reward.self, forKey: .lastReward)
        settings = try c.decodeIfPresent(PorkSettings.self, forKey: .settings) ?? PorkSettings()
        hiAllowedUntil = try c.decodeIfPresent(Date.self, forKey: .hiAllowedUntil)
    }

    // MARK: timing

    /// Seconds until the focus goal / break end; negative once past it.
    func left(_ now: Date = Date()) -> TimeInterval {
        if paused { return remaining ?? 0 }
        guard let endsAt else { return 0 }
        return endsAt.timeIntervalSince(now)
    }

    func goalReached(_ now: Date = Date()) -> Bool {
        phase == .focus && left(now) <= 0
    }

    var bonusEvery: TimeInterval { TimeInterval(settings.bonusEveryMin * 60) }

    /// Treats earned so far in this focus session.
    func earned(_ now: Date = Date()) -> Int {
        guard phase == .focus else { return 0 }
        let extra = -left(now)
        if extra < 0 { return 0 }
        return 1 + Int(extra / bonusEvery)
    }

    /// Seconds until the next bonus treat (after the goal).
    func nextTreatIn(_ now: Date = Date()) -> TimeInterval {
        let extra = max(0, -left(now))
        return bonusEvery - extra.truncatingRemainder(dividingBy: bonusEvery)
    }

    /// How long the break has run over.
    func lateBy(_ now: Date = Date()) -> TimeInterval {
        guard phase == .overtime, let overtimeFrom else { return 0 }
        return max(0, now.timeIntervalSince(overtimeFrom))
    }

    func pose(_ now: Date = Date()) -> Pose {
        switch phase {
        case .idle, .focus: return .sleep
        case .break: return .wait
        case .overtime: return lateBy(now) < paceSeconds ? .pace : .door
        }
    }

    /// The break ran out while nobody was looking.
    mutating func advance(_ now: Date = Date()) {
        if phase == .break, !paused, let endsAt, now >= endsAt {
            phase = .overtime
            overtimeFrom = endsAt
            self.endsAt = nil
        }
    }

    // MARK: changes

    mutating func startFocus(_ now: Date = Date(), carry: TimeInterval = 0) {
        phase = .focus
        paused = false
        remaining = nil
        overtimeFrom = nil
        self.carry = carry
        target = TimeInterval(settings.focusMin * 60) + carry
        endsAt = now.addingTimeInterval(target)
    }

    mutating func startBreak(_ now: Date = Date()) {
        phase = .break
        paused = false
        remaining = nil
        carry = 0
        target = TimeInterval(settings.breakMin * 60)
        endsAt = now.addingTimeInterval(target)
    }

    mutating func toIdle() {
        phase = .idle
        paused = false
        endsAt = nil
        remaining = nil
        overtimeFrom = nil
        target = 0
        carry = 0
    }

    /// Gives Pork his treats for this focus session.
    @discardableResult
    mutating func reward(_ now: Date = Date()) -> Bool {
        let n = earned(now)
        guard n > 0 else { return false }
        let items = (0..<n).map { i in
            Treat(t: porkTreats.randomElement()!, at: now.addingTimeInterval(Double(i) / 1000), bonus: i > 0)
        }
        treats += items
        lastReward = Reward(at: now, items: items.map(\.t))
        sessions += 1
        return true
    }

    mutating func pause(_ now: Date = Date()) {
        guard phase == .focus || phase == .break, !paused, let endsAt else { return }
        remaining = endsAt.timeIntervalSince(now)
        self.endsAt = nil
        paused = true
    }

    mutating func resume(_ now: Date = Date()) {
        guard paused else { return }
        endsAt = now.addingTimeInterval(remaining ?? 0)
        remaining = nil
        paused = false
    }

    /// Let Pork out: end the break and start the next focus, adding the late time.
    mutating func release(_ now: Date = Date()) {
        guard phase == .break || phase == .overtime else { return }
        let late = lateBy(now)
        startFocus(now, carry: late)
    }
}

// MARK: - time text

enum PorkClock {
    /// 25:00, 1:02:03
    static func text(_ seconds: TimeInterval) -> String {
        let total = Int(abs(seconds).rounded(.down))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    /// The clock as shown in the app: 24:59, +03:12, −01:36
    static func display(_ st: PorkState, _ now: Date = Date()) -> String {
        switch st.phase {
        case .idle: return text(TimeInterval(st.settings.focusMin * 60))
        case .focus:
            let left = st.left(now)
            return left > 0 ? text(left + 0.999) : "+" + text(-left)
        case .break: return text(max(0, st.left(now)) + 0.999)
        case .overtime: return "−" + text(st.lateBy(now))
        }
    }

    static func treatsText(_ n: Int) -> String {
        n > 8 ? String(repeating: "🦴", count: 8) + " ×\(n)" : String(repeating: "🦴", count: n)
    }
}

// MARK: - storage (App Group, shared with the widgets and Screen Time extensions)

enum PorkStore {
    static let groupID = (Bundle.main.object(forInfoDictionaryKey: "PorkAppGroup") as? String)
        ?? "group.com.sssamui.puppypomodoro"
    static var defaults: UserDefaults { UserDefaults(suiteName: groupID) ?? .standard }
    private static let key = "pp"

    static func load() -> PorkState {
        guard let data = defaults.data(forKey: key),
              let s = try? JSONDecoder().decode(PorkState.self, from: data) else { return PorkState() }
        return s
    }

    static func save(_ s: PorkState) {
        if let data = try? JSONEncoder().encode(s) {
            defaults.set(data, forKey: key)
        }
    }
}
