// The Live Activity (Lock Screen + Dynamic Island) data, and the buttons on
// it. Used by the app and the widget extension. The buttons run inside the app.

import ActivityKit
import AppIntents
import Foundation

struct PorkActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: String          // focus | break | overtime
        var paused: Bool
        var target: Date           // focus goal / break end / when the break ran out
        var pausedLeft: TimeInterval
        var carry: TimeInterval
        var bonusEveryMin: Int
    }
}

extension PorkActivityAttributes.ContentState {
    init(_ s: PorkState, now: Date = Date()) {
        phase = s.phase.rawValue
        paused = s.paused
        pausedLeft = s.remaining ?? 0
        carry = s.carry
        bonusEveryMin = s.settings.bonusEveryMin
        switch s.phase {
        case .overtime: target = s.overtimeFrom ?? now
        default: target = s.endsAt ?? now.addingTimeInterval(s.remaining ?? 0)
        }
    }

    /// When the picture has to change by itself: focus goal reached, or break over.
    var staleDate: Date? {
        (paused || phase == "overtime") ? nil : target
    }
}

// MARK: - buttons

struct TakeBreakIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Take a break"
    static var description = IntentDescription("Give Pork his treats and start the break.")
    init() {}
    func perform() async throws -> some IntentResult {
        await PorkHooks.settle(PorkCommands.run(.takeBreak))
        return .result()
    }
}

struct LetPorkOutIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Let Pork out"
    static var description = IntentDescription("End the break and start the next focus.")
    init() {}
    func perform() async throws -> some IntentResult {
        await PorkHooks.settle(PorkCommands.run(.release))
        return .result()
    }
}

struct PauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause"
    init() {}
    func perform() async throws -> some IntentResult {
        await PorkHooks.settle(PorkCommands.run(.pause))
        return .result()
    }
}

struct ResumeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume"
    init() {}
    func perform() async throws -> some IntentResult {
        await PorkHooks.settle(PorkCommands.run(.resume))
        return .result()
    }
}
