// Screen Time wakes this up even if the app is closed:
// - unlock check: when the backup time runs out (ask again), and at
//   midnight ("Skip today" ends);
// - focus clock: at the focus goal and when the break runs out (refreshes
//   Pork's blocked-app screen: "Start my break", "Let Pork out").

import DeviceActivity
import Foundation

class PorkMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if activity == Gate.dayActivity {
            Gate.apply()
            return
        }
        guard activity == ScreenTime.goalActivity || activity == ScreenTime.overtimeActivity else { return }
        // If Screen Time woke us a few seconds early, wait for the real time.
        let before = PorkStore.load()
        if (before.phase == .focus || before.phase == .break), !before.paused, let end = before.endsAt {
            let wait = end.timeIntervalSinceNow
            if wait > 0 && wait < 20 { Thread.sleep(forTimeInterval: wait + 0.5) }
        }
        let s = PorkCommands.run(.sync)
        ScreenTime.refresh(s)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity == Gate.backupActivity {
            Thread.sleep(forTimeInterval: 1) // let the clock pass the end time
            Gate.arm()
        }
    }
}
