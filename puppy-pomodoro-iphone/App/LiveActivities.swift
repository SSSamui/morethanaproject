// Starts, updates and ends the Live Activity (Lock Screen + Dynamic Island).

import ActivityKit
import Foundation

enum LiveActivities {
    static func update(_ s: PorkState) async {
        let running = Activity<PorkActivityAttributes>.activities
        var state = PorkActivityAttributes.ContentState(s)
        if s.phase == .idle {
            // Sleep time: count down to getting up.
            guard let wake = SleepMode.wake(s.settings) else {
                for a in running { await a.end(nil, dismissalPolicy: .immediate) }
                return
            }
            state = PorkActivityAttributes.ContentState(phase: "sleep", paused: false, target: wake,
                                                        pausedLeft: 0, carry: 0, bonusEveryMin: s.settings.bonusEveryMin)
        }
        let content = ActivityContent(state: state, staleDate: state.staleDate)
        if let a = running.first {
            await a.update(content)
            for extra in running.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            // Only works while the app is open; otherwise it starts next time.
            _ = try? Activity.request(attributes: PorkActivityAttributes(), content: content, pushType: nil)
        }
    }
}
