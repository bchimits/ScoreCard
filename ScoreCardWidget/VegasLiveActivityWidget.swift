import ActivityKit
import WidgetKit
import SwiftUI

struct VegasLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VegasLiveActivityAttributes.self) { context in
            VegasLockScreenView(context: context)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.team1Players)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("+\(context.state.team1Points)")
                            .font(.title2.bold())
                            .foregroundStyle(.green)
                            .contentTransition(.numericText())
                    }
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.attributes.team2Players)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("+\(context.state.team2Points)")
                            .font(.title2.bold())
                            .foregroundStyle(.blue)
                            .contentTransition(.numericText())
                    }
                    .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Vegas  ·  Hole \(context.state.currentHole)  ·  \(context.state.holesCompleted)/\(context.attributes.totalHoles) holes")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Text("T1")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                    Text("+\(context.state.team1Points)")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .contentTransition(.numericText())
                }
            } compactTrailing: {
                HStack(spacing: 3) {
                    Text("+\(context.state.team2Points)")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                        .contentTransition(.numericText())
                    Text("T2")
                        .font(.caption2.bold())
                        .foregroundStyle(.blue)
                }
            } minimal: {
                let diff = context.state.team1Points - context.state.team2Points
                Group {
                    if diff > 0 {
                        Text("T1")
                            .font(.caption2.bold())
                            .foregroundStyle(.green)
                    } else if diff < 0 {
                        Text("T2")
                            .font(.caption2.bold())
                            .foregroundStyle(.blue)
                    } else {
                        Image(systemName: "equal.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct VegasLockScreenView: View {
    let context: ActivityViewContext<VegasLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 0) {
            teamColumn(
                players: context.attributes.team1Players,
                points: context.state.team1Points,
                color: .green
            )

            Divider().frame(height: 44)

            VStack(spacing: 2) {
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("H\(context.state.currentHole)")
                    .font(.caption2.bold())
            }
            .frame(width: 48)

            Divider().frame(height: 44)

            teamColumn(
                players: context.attributes.team2Players,
                points: context.state.team2Points,
                color: .blue
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func teamColumn(players: String, points: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(players)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("+\(points)")
                .font(.title.bold())
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }
}
