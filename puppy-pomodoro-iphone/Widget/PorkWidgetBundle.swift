// Pork on the Home Screen, the Lock Screen and in the Dynamic Island.

import SwiftUI
import WidgetKit

@main
struct PorkWidgetBundle: WidgetBundle {
    var body: some Widget {
        PorkClockWidget()
        PorkLiveActivity()
    }
}
