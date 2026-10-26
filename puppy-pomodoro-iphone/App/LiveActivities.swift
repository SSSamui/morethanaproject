// Starts, updates and ends the Live Activity (Lock Screen + Dynamic Island).

import ActivityKit
import Foundation

enum LiveActivities {
    static func update(_ s: PorkState) async {
        let running = Activity<PorkActivityAttributes>.activities
        var state = PorkActivityAttributes.ContentState(s)
        if s.phase == .idle {
            if let bedtime = SleepMode.bedtimeSoon(s.settings) {
                // After 10 pm: time left until bedtime, then sleep left.
                let wake = SleepPlan.night(now: Date(), bedtime: SleepMode.bedtime(s.settings) ?? 0,
                                           weekday: s.settings.wakeWeekday, weekend: s.settings.wakeWeekend).wake
                state = PorkActivityAttributes.ContentState(phase: "bedtime", paused: false, target: bedtime,
                                                            pausedLeft: 0, carry: 0, bonusEveryMin: s.settings.bonusEveryMin,
                                                            wake: wake)
            } else if let wake = SleepMode.wake(s.settings) {
                // Sleep time: count down to getting up.
                state = PorkActivityAttributes.ContentState(phase: "sleep", paused: false, target: wake,
                                                            pausedLeft: 0, carry: 0, bonusEveryMin: s.settings.bonusEveryMin)
            } else {
                for a in running { await a.end(nil, dismissalPolicy: .immediate) }
                return
            }
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
