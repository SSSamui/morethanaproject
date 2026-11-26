// The buttons on Pork's screen.
// - Unlock check: "Write to Pork" sends a notification (tap it to open the
//   diary box; Apple doesn't let this screen open the app itself). "Not now"
//   lets you in and saves "skipped" in the diary.
// - Focus clock: after the focus goal, "Start my break" starts the break and
//   unlocks the app; when the break is over, "Let Pork out" starts the next
//   focus.

import Foundation
import ManagedSettings

class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(action, token: application))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(action, token: nil))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(action, token: nil))
    }

    private func respond(_ action: ShieldAction, token: ApplicationToken?) -> ShieldActionResponse {
        let now = Date()
        var s = PorkStore.load()
        s.advance(now)

        if ScreenTime.focusBlocks(token, s) {
            switch (s.phase, action) {
            case (.focus, .primaryButtonPressed) where s.left(now) <= 0:
                PorkCommands.run(.takeBreak, announce: true)
                return .defer // shields are off now, so the app opens
            case (.overtime, .primaryButtonPressed):
                PorkCommands.run(.release, announce: true)
                return .defer // next focus: the screen now shows the focus message
            default:
                return .close
            }
        }

        // The unlock check.
        if action == .secondaryButtonPressed {
            Gate.notNow(now)
            return .defer // Pork's screen is down now, so the app opens
        }
        Gate.noteStart(now)
        Alerts.writeTap()
        return .defer // redraw: the screen now says "tap the notification"
    }
}
