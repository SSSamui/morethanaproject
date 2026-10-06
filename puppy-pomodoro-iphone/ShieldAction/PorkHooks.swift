import Foundation

// In the app, these update the Live Activity and the screen (see
// App/PorkHooks.swift). Outside the app there is nothing more to do.
enum PorkHooks {
    static func changed(_ s: PorkState) {}
    static func settle(_ s: PorkState) async {}
}
