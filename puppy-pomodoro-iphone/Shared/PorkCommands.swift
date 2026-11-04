// Every change to the timer goes through here, from the app, the Lock Screen
// buttons, notification buttons and the blocked-app screen. After a change it
// updates the app blocking, the reminders, the widgets and the Live Activity.

import Foundation
import WidgetKit

enum PorkCommand {
    case start(PorkSettings?)
    case startTask(id: String, title: String)   // ▶︎ on a sticky note: focus on this to-do
    case pause, resume, stop
    case takeBreak      // focus goal reached → break
    case release        // let Pork out → next focus (with the late time added)
    case sync           // just catch up with the clock
    case settings(PorkSettings)
    case clearTreats
}

enum PorkCommands {
    private static let lock = NSLock()

    /// `announce`: also post a notification about what happened (used when
    /// the change comes from somewhere the app isn't showing, like the
    /// blocked-app screen).
    @discardableResult
    static func run(_ cmd: PorkCommand, announce: Bool = false) -> PorkState {
        lock.lock()
        let now = Date()
        var s = PorkStore.load()
        let before = s.phase
        s.advance(now)
        var changed = s.phase != before
        // Count focus time on the current to-do so far.
        if let id = s.taskID, let since = s.workingSince {
            ProjectTime.add(id, s.taskTitle ?? "", now.timeIntervalSince(since), now: now)
            s.workingSince = nil
            changed = true
        }

        switch cmd {
        case .start(let settings):
            if let settings { s.settings = settings.cleaned() }
            s.startFocus(now)
            s.taskID = nil
            s.taskTitle = nil
            changed = true
        case .startTask(let id, let title):
            if s.phase != .focus { s.startFocus(now) }
            s.taskID = id
            s.taskTitle = title
            changed = true
        case .pause:
            s.pause(now)
            changed = true
        case .resume:
            s.resume(now)
            changed = true
        case .stop:
            s.reward(now)
            s.toIdle()
            s.taskID = nil
            s.taskTitle = nil
            changed = true
        case .takeBreak:
            if s.phase == .focus, s.reward(now) {
                s.startBreak(now)
                changed = true
            }
        case .release:
            if s.phase == .break || s.phase == .overtime {
                s.release(now)
                changed = true
            }
        case .settings(let settings):
            s.settings = settings.cleaned()
            changed = true
            #if !LITE
            ScreenTime.scheduleNight(s.settings)
            #endif
        case .clearTreats:
            s.treats = []
            changed = true
        case .sync:
            break
        }

        // Focus time on the to-do counts while the focus clock runs.
        if s.taskID != nil, s.phase == .focus, !s.paused, s.workingSince == nil {
            s.workingSince = now
            changed = true
        }
        if changed { PorkStore.save(s) }
        lock.unlock()

        if changed {
            apply(s)
            if announce { Alerts.announce(cmd, s) }
        }
        return s
    }

    /// Bring everything outside the app in line with the state.
    static func apply(_ s: PorkState) {
        #if !LITE
        ScreenTime.apply(s)
        #endif
        Alerts.schedule(s)
        WidgetCenter.shared.reloadAllTimelines()
        PorkHooks.changed(s)
    }
}
