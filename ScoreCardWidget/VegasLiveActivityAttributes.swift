import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct VegasLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var team1Points: Int
        var team2Points: Int
        var currentHole: Int
        var holesCompleted: Int
    }

    let team1Players: String
    let team2Players: String
    let totalHoles: Int
}
