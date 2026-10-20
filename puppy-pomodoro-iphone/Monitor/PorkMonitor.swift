// Screen Time wakes this up even if the app is closed:
// - at the focus goal and when the break runs out (refreshes Pork's
//   blocked-app screen: "Start my break", "Let Pork out");
// - at bedtime and in the morning (late-night block);
// - at 8 am (block distractions until today's promise is made);
// - every 10 minutes of phone time (today's promise), and after
//   "15 more minutes".

import DeviceActivity
import Foundation

class PorkMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if activity == ScreenTime.nightActivity {
            ScreenTime.applyNight(PorkStore.load().settings)
            return
        }
        if activity == ScreenTime.morningActivity {
            ScreenTime.applyMorning()
            return
        }
        if activity == ScreenTime.promiseActivity || activity == ScreenTime.graceActivity { return }
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
        // Morning: the late-night block ends. (Give the clock a moment to pass the end time.)
        if activity == ScreenTime.nightActivity {
            Thread.sleep(forTimeInterval: 1)
            ScreenTime.applyNight(PorkStore.load().settings)
        }
        if activity == ScreenTime.graceActivity {
            ScreenTime.graceOver()
        }
    }

    // Today's play time reached another 10 minutes.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        if activity == ScreenTime.promiseActivity {
            ScreenTime.usageReached(event.rawValue)
        }
    }
}
