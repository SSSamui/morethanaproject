// The buttons on Pork's blocked-app screen.
// After the focus goal, "Start my break" starts the break and unlocks the app
// (like opening a non-focus site in Safari). When the break is over,
// "Let Pork out" ends it and starts the next focus.

import ManagedSettings

class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(action))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(action))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(action))
    }

    private func respond(_ action: ShieldAction) -> ShieldActionResponse {
        guard action == .primaryButtonPressed else { return .close }
        var s = PorkStore.load()
        let now = Date()
        s.advance(now)
        switch s.phase {
        case .focus where s.left(now) <= 0:
            PorkCommands.run(.takeBreak, announce: true)
            return .defer // shields are off now, so the app opens
        case .overtime, .break:
            PorkCommands.run(.release, announce: true)
            return .defer // next focus: the screen now shows the focus message
        default:
            return .close
        }
    }
}
