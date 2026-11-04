// Shortcuts actions (see Settings → How to set up Shortcuts):
// - "Pork: distraction app opened" / "Pork: focus app opened" — run by
//   automations when you open apps; they start or cancel the 5 / 10 minute
//   reminders and show a calendar event right away.
// - "Pork: to-dos left?" — for the 12 am (Outlook) and 6 pm (WeChat)
//   automations: true when to-dos are left.
// - "Show Pork's check-in" — opens the app with your to-dos.

import AppIntents
import Foundation

struct DistractionOpenedIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pork: distraction app opened"
    static var description = IntentDescription(
        "Starts Pork's reminders (after 5 and 10 minutes). True when Pork should show his check-in first: today's promise isn't made, something from the fun list could replace the distraction, or a Calendar event is on now.")

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let show = await Nudges.distractionOpened()
        await LiveActivities.update(PorkStore.load())   // "This pick-up" on the Lock Screen
        return .result(value: show)
    }
}

struct FocusAppOpenedIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pork: focus app opened"
    static var description = IntentDescription(
        "Cancels Pork's distraction reminders. True when today's promise isn't made yet (first pick-up after 8 am), so the automation can open it.")

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        Nudges.focusOpened()
        await LiveActivities.update(PorkStore.load())
        return .result(value: DayPlans.needsPromise(DayPlans.all()))
    }
}

struct TodosLeftIntent: AppIntent {
    static var title: LocalizedStringResource = "Pork: to-dos left?"
    static var description = IntentDescription(
        "True when to-dos from your Reminders lists are still open (between midnight and 6 am: yesterday's). Pork also sends a reminder listing them.")

    @Parameter(title: "App to open", description: "Shown in Pork's reminder, like Outlook or WeChat.")
    var app: String?

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: await Nudges.todosLeft(app: app))
    }
}

struct SayHiToPorkIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Pork's check-in"
    static var description = IntentDescription("Opens Puppy Pomodoro with your to-dos, the event on now, and Pork.")
    static var openAppWhenRun = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        if DayPlans.needsPromise(DayPlans.all()) {
            AppModel.shared.showMorning = true
        } else {
            AppModel.shared.funFirst = Nudges.takeFunFirst()
            AppModel.shared.showHi = true
        }
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
        AppShortcut(intent: SayHiToPorkIntent(),
                    phrases: ["Show Pork's check-in in \(.applicationName)"],
                    shortTitle: "Pork's check-in",
                    systemImageName: "pawprint.fill")
        AppShortcut(intent: TellPorkIntent(),
                    phrases: ["Tell \(.applicationName)", "Tell \(.applicationName) a thought"],
                    shortTitle: "Tell Pork",
                    systemImageName: "bubble.left.fill")
    }
}
