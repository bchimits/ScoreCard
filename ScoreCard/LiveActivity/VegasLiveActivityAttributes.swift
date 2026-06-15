import ActivityKit
import Foundation

/// Shared between the main app and the ScoreCardWidget extension.
/// Add this file to both targets in Xcode (target membership checkbox).
@available(iOS 16.1, *)
struct VegasLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var team1Points: Int
        var team2Points: Int
        var currentHole: Int
        var holesCompleted: Int
    }

    let team1Players: String   // e.g. "Alice & Bob"
    let team2Players: String   // e.g. "Carol & Dave"
    let totalHoles: Int
}
