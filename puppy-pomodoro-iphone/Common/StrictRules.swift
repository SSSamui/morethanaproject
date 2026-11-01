// How strict Pork is. Defaults: the late-night block and the paw screen at
// 12 minutes are on, the promise blocks are off. You can change them in
// Settings, but a change only lasts 1 day; then it goes back to the default.

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
    static func isOn(_ rule: StrictRule, now: Date = Date(), defaults: UserDefaults = PorkGroup.defaults) -> Bool {
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
