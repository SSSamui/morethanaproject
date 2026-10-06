// Starts, updates and ends the Live Activity (Lock Screen + Dynamic Island).

import ActivityKit
import Foundation

enum LiveActivities {
    static func update(_ s: PorkState) async {
        let running = Activity<PorkActivityAttributes>.activities
        guard s.phase != .idle else {
            for a in running { await a.end(nil, dismissalPolicy: .immediate) }
            return
        }
        let state = PorkActivityAttributes.ContentState(s)
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
