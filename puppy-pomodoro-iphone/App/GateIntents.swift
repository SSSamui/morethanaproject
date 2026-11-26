// Shortcuts actions:
// - "Write to Pork" — opens Pork's diary box.
// - "Tell Pork" — drop a thought into your Reminders "Inbox" list.
// - "Pork: start focus" / "Pork: stop focus" — for later, with the Mac.

import AppIntents
import Foundation

struct WriteToPorkIntent: AppIntent {
    static var title: LocalizedStringResource = "Write to Pork"
    static var description = IntentDescription("Opens Puppy Pomodoro's diary box: a photo or a sentence, saved with the time.")
    static var openAppWhenRun = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        Gate.noteStart()
        AppModel.shared.showWrite = true
        return .result()
    }
}

// MARK: - brain dump

struct TellPorkIntent: AppIntent {
    static var title: LocalizedStringResource = "Tell Pork"
    static var description = IntentDescription("Drop a thought into Pork's inbox (your Reminders “Inbox” list).")

    @Parameter(title: "Thought", requestValueDialog: "What's on your mind?")
    var thought: String

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        Todos.add(thought, to: PorkStore.load().settings.inboxList)
        return .result(dialog: "Got it. Pork keeps it in your inbox 🐾")
    }
}

// MARK: - studying on the Mac
// Turn on a "Study" Focus on the Mac (Share Across Devices) and the iPhone
// gets it too; iPhone automations run these to start / stop Pork's focus.

struct StartFocusIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pork: start focus"
    static var description = IntentDescription("Starts Pork's focus clock on the iPhone (for example when your Mac's Study Focus turns on).")
    init() {}
    func perform() async throws -> some IntentResult {
        let s = PorkStore.load()
        if s.phase == .idle { await PorkHooks.settle(PorkCommands.run(.start(nil))) }
        return .result()
    }
}

struct StopFocusIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pork: stop focus"
    static var description = IntentDescription("Stops Pork's focus clock on the iPhone (for example when your Mac's Study Focus turns off).")
    init() {}
    func perform() async throws -> some IntentResult {
        await PorkHooks.settle(PorkCommands.run(.stop))
        return .result()
    }
}

struct PorkShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: WriteToPorkIntent(),
                    phrases: ["Write to \(.applicationName)", "Write in \(.applicationName)'s diary"],
                    shortTitle: "Write to Pork",
                    systemImageName: "square.and.pencil")
        AppShortcut(intent: TellPorkIntent(),
                    phrases: ["Tell \(.applicationName)", "Tell \(.applicationName) a thought"],
                    shortTitle: "Tell Pork",
                    systemImageName: "bubble.left.fill")
    }
}
