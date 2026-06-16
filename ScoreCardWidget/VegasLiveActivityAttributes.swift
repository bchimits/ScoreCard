import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct RoundLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var leadingLabel: String
        var leadingValue: String
        var trailingLabel: String
        var trailingValue: String
        var leadingIsWinning: Bool
        var trailingIsWinning: Bool
        var leadingColorName: String?
        var trailingColorName: String?
        var rows: [ScoreRow]
        var currentHole: Int
        var holesCompleted: Int
    }

    struct ScoreRow: Codable, Hashable, Identifiable {
        var id: String
        var label: String
        var value: String
        var isHighlighted: Bool
    }

    let roundName: String
    let formatName: String
    let totalHoles: Int
}
