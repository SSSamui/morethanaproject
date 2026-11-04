// Time limits (how strict Pork is). One main switch, off unless you turn it
// on, and it stays the way you set it. With it on: the late-night block and
// the paw screen at 12 minutes are on, the promise blocks are off; a change
// to one of those only lasts 1 day, then it goes back.
// Blocking apps and websites during a Focus session is separate (always on
// while you focus, if Screen Time is allowed).

import Foundation

enum StrictRule: String, CaseIterable {
    case night     // after bedtime only focus apps open
    case paws      // after 12 min of distractions Pork's paws cover the app
    case promise   // block until the morning promise, and when the promised time is used up

    var byDefault: Bool {
        switch self {
        case .night, .paws: return true
        case .promise: return false
        }
    }

    var title: String {
        switch self {
        case .night: return "Only focus apps after bedtime"
        case .paws: return "Pork's paws cover the app at 12 min"
        case .promise: return "Block apps for the morning promise and when it's used up"
        }
    }
}

enum StrictRules {
    static let lasts: TimeInterval = 24 * 3600

    /// Is the rule on right now (your change if it's less than 1 day old, else the default)?
    /// The main "Time limits" switch (off unless turned on; never resets).
    static func limitsOn(_ defaults: UserDefaults = PorkGroup.defaults) -> Bool {
        defaults.bool(forKey: "limitsOn")
    }

    static func setLimits(_ on: Bool, defaults: UserDefaults = PorkGroup.defaults) {
        defaults.set(on, forKey: "limitsOn")
    }

    static func isOn(_ rule: StrictRule, now: Date = Date(), defaults: UserDefaults = PorkGroup.defaults) -> Bool {
        guard limitsOn(defaults) else { return false }
        if let until = defaults.object(forKey: "strict.\(rule.rawValue).until") as? Date, until > now {
            return defaults.bool(forKey: "strict.\(rule.rawValue).value")
        }
        return rule.byDefault
    }

    /// Change a rule for the next 24 hours (setting it back to the default ends the change).
    static func set(_ rule: StrictRule, _ on: Bool, now: Date = Date(), defaults: UserDefaults = PorkGroup.defaults) {
        if on == rule.byDefault {
            defaults.removeObject(forKey: "strict.\(rule.rawValue).until")
        } else {
            defaults.set(on, forKey: "strict.\(rule.rawValue).value")
            defaults.set(now.addingTimeInterval(lasts), forKey: "strict.\(rule.rawValue).until")
        }
    }

    /// When a change goes back to the default (nil if there's no change).
    static func changedUntil(_ rule: StrictRule, now: Date = Date(), defaults: UserDefaults = PorkGroup.defaults) -> Date? {
        guard let until = defaults.object(forKey: "strict.\(rule.rawValue).until") as? Date, until > now else { return nil }
        return until
    }
}
