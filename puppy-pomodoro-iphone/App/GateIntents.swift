// Shortcuts actions (see Settings → How to set up Shortcuts):
// - "Pork: distraction app opened" / "Pork: focus app opened" — run by
//   automations when you open apps; they start or cancel the 5 / 10 minute
//   reminders and show a calendar event right away.
// - "Pork: to-dos left?" — for the 12 am (Outlook) and 6 pm (WeChat)
//   automations: true when to-dos are left.
// - "Show Pork's check-in" — opens the app with your to-dos.

import AppIntents

struct DistractionOpenedIntent: AppIntent {
    static var title: LocalizedStringResource = "Pork: distraction app opened"
    static var description = IntentDescription(
        "Starts Pork's reminders (after 5 and 10 minutes). True when a Calendar event is on now, so the automation can show Pork's check-in.")

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: await Nudges.distractionOpened())
    }
}

struct FocusAppOpenedIntent: AppIntent {
    static var title: LocalizedStringResource = "Pork: focus app opened"
    static var description = IntentDescription(
        "Cancels Pork's distraction reminders. True when today's promise isn't made yet (first pick-up after 8 am), so the automation can open it.")

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        Nudges.focusOpened()
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
            AppModel.shared.showHi = true
        }
        return .result()
    }
}

struct PorkShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SayHiToPorkIntent(),
                    phrases: ["Show Pork's check-in in \(.applicationName)"],
                    shortTitle: "Pork's check-in",
                    systemImageName: "pawprint.fill")
    }
}
