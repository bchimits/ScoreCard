import ActivityKit
import WidgetKit
import SwiftUI

struct RoundLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoundLiveActivityAttributes.self) { context in
            RoundLockScreenView(context: context)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    summaryColumn(
                        label: context.state.leadingLabel,
                        value: context.state.leadingValue,
                        isWinning: context.state.leadingIsWinning,
                        teamColorName: context.state.leadingColorName,
                        alignment: .leading
                    )
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    summaryColumn(
                        label: context.state.trailingLabel,
                        value: context.state.trailingValue,
                        isWinning: context.state.trailingIsWinning,
                        teamColorName: context.state.trailingColorName,
                        alignment: .trailing
                    )
                    .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            ForEach(context.state.rows.prefix(3)) { row in
                                HStack(spacing: 3) {
                                    Text(row.label)
                                    Text(row.value)
                                        .fontWeight(row.isHighlighted ? .semibold : .regular)
                                }
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            }
                        }
                        Text("\(context.attributes.formatName)  ·  Hole \(context.state.currentHole)  ·  \(context.state.holesCompleted)/\(context.attributes.totalHoles) holes")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                compactSummary(
                    label: context.state.leadingLabel,
                    value: context.state.leadingValue,
                    isWinning: context.state.leadingIsWinning,
                    teamColorName: context.state.leadingColorName
                )
            } compactTrailing: {
                compactSummary(
                    label: context.state.trailingLabel,
                    value: context.state.trailingValue,
                    isWinning: context.state.trailingIsWinning,
                    teamColorName: context.state.trailingColorName
                )
            } minimal: {
                if context.state.leadingIsWinning {
                    minimalSummary(label: context.state.leadingLabel, teamColorName: context.state.leadingColorName)
                } else if context.state.trailingIsWinning {
                    minimalSummary(label: context.state.trailingLabel, teamColorName: context.state.trailingColorName)
                } else {
                    Image(systemName: "equal.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func summaryColumn(label: String, value: String, isWinning: Bool, teamColorName: String?, alignment: HorizontalAlignment) -> some View {
        let color = displayColor(teamColorName: teamColorName, isWinning: isWinning)
        return VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText())
        }
    }

    private func compactSummary(label: String, value: String, isWinning: Bool, teamColorName: String?) -> some View {
        let color = displayColor(teamColorName: teamColorName, isWinning: isWinning)
        return HStack(spacing: 4) {
            if teamColorName != nil {
                Image(systemName: "circle.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(color)
                    .accessibilityLabel(Text(teamColorName ?? "Team"))
            } else {
                Text(shortLabel(label))
                    .font(.caption2.bold())
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .contentTransition(.numericText())
    }

    @ViewBuilder
    private func minimalSummary(label: String, teamColorName: String?) -> some View {
        if let teamColorName {
            Image(systemName: "circle.fill")
                .font(.caption2.bold())
                .foregroundStyle(teamColor(for: teamColorName))
                .accessibilityLabel(Text(teamColorName))
        } else {
            Text(shortLabel(label))
                .font(.caption2.bold())
                .foregroundStyle(.green)
        }
    }

    private func displayColor(teamColorName: String?, isWinning: Bool) -> Color {
        if let teamColorName {
            return teamColor(for: teamColorName)
        }
        return isWinning ? .green : .primary
    }

    private func teamColor(for name: String) -> Color {
        switch name.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "purple": return .purple
        default: return .primary
        }
    }

    private func shortLabel(_ label: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "-" }
        if trimmed.localizedCaseInsensitiveContains("team 1") { return "T1" }
        if trimmed.localizedCaseInsensitiveContains("team 2") { return "T2" }
        if let firstWord = trimmed.split(separator: " ").first {
            return String(firstWord.prefix(3))
        }
        return String(trimmed.prefix(3))
    }
}

private struct RoundLockScreenView: View {
    let context: ActivityViewContext<RoundLiveActivityAttributes>

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                scoreColumn(
                    label: context.state.leadingLabel,
                    value: context.state.leadingValue,
                    isWinning: context.state.leadingIsWinning,
                    teamColorName: context.state.leadingColorName
                )

                Divider().frame(height: 44)

                VStack(spacing: 2) {
                    Image(systemName: "flag.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("H\(context.state.currentHole)")
                        .font(.caption2.bold())
                    Text(context.attributes.formatName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(width: 72)

                Divider().frame(height: 44)

                scoreColumn(
                    label: context.state.trailingLabel,
                    value: context.state.trailingValue,
                    isWinning: context.state.trailingIsWinning,
                    teamColorName: context.state.trailingColorName
                )
            }

            if !context.state.rows.isEmpty {
                HStack(spacing: 10) {
                    ForEach(context.state.rows.prefix(3)) { row in
                        VStack(spacing: 1) {
                            Text(row.label)
                                .foregroundStyle(.secondary)
                            Text(row.value)
                                .fontWeight(row.isHighlighted ? .semibold : .regular)
                                .foregroundStyle(row.isHighlighted ? .green : .primary)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                    }
                }
                .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreColumn(label: String, value: String, isWinning: Bool, teamColorName: String?) -> some View {
        let color = displayColor(teamColorName: teamColorName, isWinning: isWinning)
        return VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.title.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    private func displayColor(teamColorName: String?, isWinning: Bool) -> Color {
        if let teamColorName {
            return teamColor(for: teamColorName)
        }
        return isWinning ? .green : .primary
    }

    private func teamColor(for name: String) -> Color {
        switch name.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "purple": return .purple
        default: return .primary
        }
    }
}
