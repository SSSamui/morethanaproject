// Screen Time wakes this up at the focus goal and when the break runs out,
// even if the app is closed. It refreshes Pork's blocked-app screen: "Start my
// break" after the goal, "Let Pork out" when the break is over.

import DeviceActivity
import Foundation

class PorkMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // If Screen Time woke us a few seconds early, wait for the real time.
        let before = PorkStore.load()
        if (before.phase == .focus || before.phase == .break), !before.paused, let end = before.endsAt {
            let wait = end.timeIntervalSinceNow
            if wait > 0 && wait < 20 { Thread.sleep(forTimeInterval: wait + 0.5) }
        }
        let s = PorkCommands.run(.sync)
        ScreenTime.refresh(s)
    }
}
