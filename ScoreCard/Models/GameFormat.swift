import Foundation

enum GameFormat: String, CaseIterable, Codable, Identifiable {
    case strokePlay   = "Stroke Play"
    case matchPlay    = "Match Play"
    case bestBall     = "Best Ball"
    case vegas        = "Vegas"
    case sixes        = "Sixes"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .strokePlay: return "Total gross/net strokes. Lowest score wins."
        case .matchPlay:  return "Hole-by-hole wins. Most holes won wins the match."
        case .bestBall:   return "Teams of 2. Best net score on each hole counts."
        case .vegas:      return "Teams of 2. Scores combined as two-digit number; lower combined number wins."
        case .sixes:      return "Partners rotate every 6 holes. Three separate 6-hole matches."
        }
    }

    var requiresTeams: Bool {
        switch self {
        case .bestBall, .vegas, .sixes: return true
        default: return false
        }
    }

    var minimumPlayers: Int {
        switch self {
        case .matchPlay: return 2
        case .bestBall, .vegas, .sixes: return 4
        default: return 1
        }
    }
}
