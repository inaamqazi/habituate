import SwiftUI

/// A month of one habit's history. Past scheduled days can be ticked here too.
struct MonthCalendarView: View {
    let habit: Habit
    let history: HabitHistory
    @Binding var month: Day

    @Environment(HabitStore.self) private var store
    @Environment(\.today) private var today

    private enum Cell: Hashable {
        case header(Int)
        case blank(Int)
        case day(Day)
    }

    private var cells: [Cell] {
        let headers = (0..<7).map(Cell.header)
        let blanks = (0..<month.weekdayIndex).map(Cell.blank)
        let days = (0..<month.daysInMonth).map { Cell.day(month.adding($0)) }
        return headers + blanks + days
    }

    var body: some View {
        let rate = history.monthRate(monthStart: month, today: today)
        VStack(spacing: 12) {
            HStack {
                Button { month = month.previousMonthStart } label: {
                    Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44)
                }
                .disabled(month <= history.start.monthStart)
                .accessibilityLabel("Previous Month")
                .accessibilityIdentifier("previousMonth")
                Spacer()
                Text(month.monthTitle)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("monthTitle")
                Spacer()
                Button { month = month.nextMonthStart } label: {
                    Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44)
                }
                .disabled(month >= today.monthStart)
                .accessibilityLabel("Next Month")
                .accessibilityIdentifier("nextMonth")
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(cells, id: \.self) { cell in
                    switch cell {
                    case .header(let index):
                        Text(WeekdayNames.veryShort(index))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    case .blank:
                        Color.clear
                            .frame(height: 1)
                            .accessibilityHidden(true)
                    case .day(let day):
                        CalendarDayView(
                            day: day,
                            state: DayState(day: day, history: history, today: today),
                            color: habit.habitColor.color,
                            isToday: day == today
                        ) {
                            withAnimation(.snappy) { store.toggle(habit, on: day, today: today) }
                        }
                    }
                }
            }

            HStack(spacing: 16) {
                legendItem("Done") { Circle().fill(habit.habitColor.color) }
                legendItem("Missed") { Circle().strokeBorder(habit.habitColor.color.opacity(0.55), lineWidth: 2) }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(rate.total == 0 ? "Nothing scheduled this month" : "\(rate.done) of \(rate.total) scheduled days done this month")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func legendItem<Swatch: View>(_ title: String, @ViewBuilder swatch: () -> Swatch) -> some View {
        HStack(spacing: 6) {
            swatch().frame(width: 12, height: 12)
            Text(title)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
    }
}

private struct CalendarDayView: View {
    let day: Day
    let state: DayState
    let color: Color
    let isToday: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .callout) private var diameter: CGFloat = 34

    var body: some View {
        let size = min(diameter, 42)
        Button(action: action) {
            Text("\(day.dayOfMonth)")
                .font(.callout.weight(isToday ? .bold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background { background }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!state.isInteractive)
        .accessibilityLabel(isToday ? "\(day.accessibilityName), today" : day.accessibilityName)
        .accessibilityValue(state.accessibilityDescription)
        .accessibilityAddTraits(state == .done ? .isSelected : [])
    }

    private var foreground: Color {
        switch state {
        case .done: .white
        case .open: .primary
        case .upcoming: .secondary
        case .unscheduled: Color(.tertiaryLabel)
        }
    }

    @ViewBuilder private var background: some View {
        switch state {
        case .done:
            Circle().fill(color)
        case .open:
            Circle().strokeBorder(color.opacity(isToday ? 1 : 0.55), lineWidth: isToday ? 2.5 : 2)
        case .upcoming, .unscheduled:
            if isToday {
                Circle().strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1.5)
            }
        }
    }
}
