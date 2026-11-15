import SwiftUI

/// Weekday letters and dates above the grid; stays pinned while the habits scroll.
struct DayHeaderRow: View {
    let days: [Day]
    let layout: GridLayout

    @Environment(\.today) private var today

    var body: some View {
        HStack(spacing: 0) {
            if !layout.isStacked {
                Color.clear.frame(width: layout.nameWidth, height: 1)
            }
            ForEach(days, id: \.self) { day in
                let isToday = day == today
                VStack(spacing: 2) {
                    Text(WeekdayNames.veryShort(day.weekdayIndex))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(day.dayOfMonth)")
                        .font(.footnote.weight(isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? Color.white : Color.primary)
                        .frame(minWidth: 26, minHeight: 26)
                        .background {
                            if isToday { Circle().fill(Color.accentColor) }
                        }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        // One element for the whole row: every grid cell already reads out its full date.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Week of \(days.first?.accessibilityName ?? "")")
        .accessibilityAddTraits(.isHeader)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) { Divider() }
    }
}

struct WeekSummaryCard: View {
    let rate: CompletionRate
    let isCurrentWeek: Bool
    let isTodayComplete: Bool
    let canCompleteToday: Bool
    let onToggleToday: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))

        VStack(alignment: .leading, spacing: 12) {
            layout {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isCurrentWeek ? "Completed this week" : "Completed that week")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(rate.percentText)
                        .font(.largeTitle.bold())
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("weekPercent")
                if !isLarge {
                    Spacer(minLength: 0)
                }
                if isCurrentWeek {
                    Button(action: onToggleToday) {
                        Label(
                            isTodayComplete ? "Unmark Today" : "Complete Today",
                            systemImage: isTodayComplete ? "arrow.uturn.backward" : "checkmark.circle.fill"
                        )
                        .lineLimit(isLarge ? nil : 1)
                        .minimumScaleFactor(isLarge ? 1 : 0.8)
                        .frame(maxWidth: isLarge ? .infinity : nil)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(isLarge ? .roundedRectangle : .capsule)
                    .disabled(!canCompleteToday)
                    .accessibilityIdentifier("completeToday")
                }
            }
            ProgressView(value: rate.fraction ?? 0)
                .accessibilityHidden(true)
            Text(rate.total == 0 ? "Nothing scheduled yet" : "\(rate.done) of \(rate.total) scheduled check-ins done")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

/// Previous / next week buttons at the bottom of the screen, where they are easy to reach with a thumb.
struct WeekNavigationBar: View {
    let rangeText: String
    let isCurrentWeek: Bool
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    let onToday: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!canGoBack)
            .accessibilityLabel("Previous Week")
            .accessibilityIdentifier("previousWeek")

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Text(rangeText)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier("weekRange")
                Button("Today", action: onToday)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .opacity(isCurrentWeek ? 0 : 1)
                    .disabled(isCurrentWeek)
                    .accessibilityHidden(isCurrentWeek)
                    .accessibilityHint("Goes back to this week.")
                    .accessibilityIdentifier("todayButton")
            }

            Spacer(minLength: 0)

            Button(action: onForward) {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!canGoForward)
            .accessibilityLabel("Next Week")
            .accessibilityIdentifier("nextWeek")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        // Like the system tab bar, the bar stops growing at the largest sizes so the grid keeps its room;
        // opaque so content scrolling behind it can't hurt the text contrast.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) { Divider() }
    }
}
