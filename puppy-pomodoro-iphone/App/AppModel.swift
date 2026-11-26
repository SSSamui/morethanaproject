// What the screen shows. The timer itself lives in PorkStore (shared with the
// widgets and Screen Time extensions); this keeps a copy for SwiftUI.

import FamilyControls
import SwiftUI
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var state = PorkStore.load()
    @Published var showWrite = false    // the diary box (the unlock check)
    @Published var showDump = false     // "Tell Pork…"
    @Published var showFocus = false    // the focus clock
    @Published var celebrating = false  // a to-do was just finished
    @Published var toast: String?
    @Published var releasingUntil = Date.distantPast // door animation after "let Pork out"
    @Published var diaryTick = 0        // the diary changed

    private var toastTask: Task<Void, Never>?

    func send(_ cmd: PorkCommand) {
        if case .release = cmd { releasingUntil = Date().addingTimeInterval(3.2) }
        setState(PorkCommands.run(cmd))
    }

    func reload() {
        var s = PorkStore.load()
        s.advance()
        setState(s)
    }

    func becameActive() {
        // Screen Time is on whenever it's allowed (the tracker and the unlock check need it).
        ScreenTime.isOn = AuthorizationCenter.shared.authorizationStatus == .approved
        let s = PorkCommands.run(.sync)
        ScreenTime.cleanUpOldRules()
        Alerts.removeOld()
        PorkCommands.apply(s) // also catches up after changes made from the blocked-app screen
        setState(s)
        Task { await LiveActivities.update(s) }
        Alerts.requestPermission()
        Gate.apply()
        Gate.scheduleDay()
        checkGate()
        diaryTick += 1
    }

    /// Pork is asking (or you just tapped his screen): the diary box comes first.
    func checkGate() {
        if Gate.isAsking() || (Gate.startedAt.map { Date().timeIntervalSince($0) < 10 * 60 } ?? false) {
            Gate.noteStart()
            showDump = false
            showWrite = true
        }
    }

    /// The diary box was filled in (or "Not now"): apps open.
    func gatePassed() {
        Alerts.clearWriteTap()
        diaryTick += 1
        LockWatcher.shared.update(state)
        Task { await DiaryExport.write() }
    }

    /// ▶︎ on a sticky note: a focus session for this to-do. Its time is
    /// counted under the project; apps and websites are limited only now.
    func workOn(_ item: TodoItem) {
        send(.startTask(id: item.id, title: item.title))
        showFocus = true
        show("Focusing on “\(item.title)” 🐾")
    }

    /// A to-do is done: Pork jumps for joy.
    func celebrate() {
        withAnimation(.spring) { celebrating = true }
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            withAnimation { celebrating = false }
        }
    }

    func updateSettings(_ change: (inout PorkSettings) -> Void) {
        var st = state.settings
        change(&st)
        guard st != state.settings else { return }
        send(.settings(st))
    }

    func show(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled { toast = nil }
        }
    }

    private func setState(_ s: PorkState) {
        LockWatcher.shared.update(s)
        let prev = state
        // Back to focus from the break: play the door animation.
        if (prev.phase == .break || prev.phase == .overtime) && s.phase == .focus {
            releasingUntil = max(releasingUntil, Date().addingTimeInterval(3.2))
        }
        if let r = s.lastReward, r != prev.lastReward, Date().timeIntervalSince(r.at) < 15 {
            show(s.phase == .break ? "Break time! Pork got \(r.items.joined()) 🐾" : "Pork got \(r.items.joined()) 🐾")
        }
        // New treats pop into the jar.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
            state = s
        }
    }
}
