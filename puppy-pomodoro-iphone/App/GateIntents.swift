// Shortcuts actions for "Pork says hi" (see Settings → How to turn it on).
// An automation runs "Should Pork say hi?" when you open an app, and if it's
// true, "Say hi to Pork" opens Pork's photos.

import AppIntents

struct ShouldPorkSayHiIntent: AppIntent {
    static var title: LocalizedStringResource = "Should Pork say hi?"
    static var description = IntentDescription(
        "True when Pork should show his photos first: the clock isn't running and you didn't just say “Yes, continue”.")

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: Gate.shouldSayHi(PorkStore.load()))
    }
}

struct SayHiToPorkIntent: AppIntent {
    static var title: LocalizedStringResource = "Say hi to Pork"
    static var description = IntentDescription("Opens Puppy Pomodoro and plays Pork's photos and videos.")
    static var openAppWhenRun = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.showHi = true
        return .result()
    }
}

struct PorkShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SayHiToPorkIntent(),
                    phrases: ["Say hi to Pork in \(.applicationName)"],
                    shortTitle: "Say hi to Pork",
                    systemImageName: "pawprint.fill")
    }
}
