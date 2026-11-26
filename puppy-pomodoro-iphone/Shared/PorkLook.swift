// Colors, labels and pictures for each moment, shared by the app, the
// widgets, the Live Activity and the blocked-app screen.

import SwiftUI

extension Color {
    static let porkFocus = Color(red: 0.227, green: 0.553, blue: 0.361) // green: focus time left
    static let porkBonus = Color(red: 0.773, green: 0.541, blue: 0.0)   // gold: extra focus
    static let porkBreak = Color(red: 0.231, green: 0.490, blue: 0.847) // blue: break
    static let porkOver = Color(red: 0.851, green: 0.263, blue: 0.231)  // red: break is over
    static let porkWall = Color(red: 0.965, green: 0.906, blue: 0.812)
}

struct PorkMoment {
    enum Kind { case idle, focus, extra, rest, over }

    var kind: Kind
    var paused = false
    var target = Date()          // goal / break end / when the break ran out
    var pausedLeft: TimeInterval = 0
    var idleSeconds: TimeInterval = 25 * 60
    var carry: TimeInterval = 0
    var bonusEveryMin = 5
    var lateBy: TimeInterval = 0 // known only in the app; widgets show "door"

    /// From the saved state, as it will be at `date`.
    init(_ state: PorkState, at date: Date = Date()) {
        var s = state
        s.advance(date)
        idleSeconds = TimeInterval(s.settings.focusMin * 60)
        carry = s.carry
        bonusEveryMin = s.settings.bonusEveryMin
        paused = s.paused
        pausedLeft = s.remaining ?? 0
        switch s.phase {
        case .idle:
            kind = .idle
        case .focus:
            kind = s.left(date) > 0 ? .focus : .extra
            target = s.endsAt ?? date
        case .break:
            kind = .rest
            target = s.endsAt ?? date
        case .overtime:
            kind = .over
            target = s.overtimeFrom ?? date
            lateBy = s.lateBy(date)
        }
    }

    /// From the Live Activity data. `stale` means its time has passed.
    init(phase: String, paused: Bool, target: Date, pausedLeft: TimeInterval,
         carry: TimeInterval, bonusEveryMin: Int, stale: Bool) {
        self.paused = paused
        self.target = target
        self.pausedLeft = pausedLeft
        self.carry = carry
        self.bonusEveryMin = bonusEveryMin
        let passed = !paused && (stale || target <= Date())
        switch phase {
        case "focus": kind = (paused ? pausedLeft <= 0 : passed) ? .extra : .focus
        case "break": kind = passed ? .over : .rest
        case "overtime": kind = .over
        default: kind = .idle
        }
        if kind == .over, phase == "overtime" { lateBy = Date().timeIntervalSince(target) }
    }

    var color: Color {
        if paused { return .gray }
        switch kind {
        case .idle, .focus: return .porkFocus
        case .extra: return .porkBonus
        case .rest: return .porkBreak
        case .over: return .porkOver
        }
    }

    var label: String {
        let p = paused ? " · paused" : ""
        switch kind {
        case .idle: return "Ready to focus"
        case .focus: return "Focus" + p
        case .extra: return "Extra focus" + p
        case .rest: return "Break" + p
        case .over: return "Break is over!"
        }
    }

    var line: String {
        switch kind {
        case .idle: return "Pork is napping. Tap to start."
        case .focus: return carry > 0 ? "Pork is napping 💤 · +\(PorkClock.text(carry)) from the long break" : "Pork is napping 💤"
        case .extra: return "Pork is earning treats 🦴 · 1 every \(bonusEveryMin) min"
        case .rest: return "Pork is waiting by the door 🚪"
        case .over: return lateBy > 0 && lateBy < paceSeconds ? "Can we go out? 🥺" : "Woof! Let me out! 🐾"
        }
    }

    var pose: Pose {
        switch kind {
        case .idle, .focus, .extra: return .sleep
        case .rest: return .wait
        case .over: return lateBy > 0 && lateBy < paceSeconds ? .pace : .door
        }
    }

    var porkImage: String { "Pork" + pose.rawValue.capitalized }
    var roomImage: String { "Room" + pose.rawValue.capitalized }

    /// The clock: counts down to the goal/break end, then up (+ or −).
    var timer: Text {
        switch kind {
        case .idle:
            return Text(PorkClock.text(idleSeconds))
        case .focus, .rest:
            return paused ? Text(PorkClock.text(pausedLeft)) : Text(target, style: .timer)
        case .extra:
            return paused ? Text("+" + PorkClock.text(pausedLeft)) : Text("+") + Text(target, style: .timer)
        case .over:
            return Text("−") + Text(target, style: .timer)
        }
    }

    /// Short form for tiny spots: 24m, +3m, 4m, −2m, ||
    var short: String {
        if paused { return "||" }
        let now = Date()
        switch kind {
        case .idle: return "\(Int(idleSeconds / 60))m"
        case .focus, .rest: return "\(max(1, Int(ceil(target.timeIntervalSince(now) / 60))))m"
        case .extra: return "+\(max(1, Int(ceil(now.timeIntervalSince(target) / 60))))m"
        case .over: return "−\(max(1, Int(ceil(now.timeIntervalSince(target) / 60))))m"
        }
    }
}
