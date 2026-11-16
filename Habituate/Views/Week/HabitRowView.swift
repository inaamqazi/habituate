import SwiftUI

struct HabitRowView: View {
    let habit: Habit
    let days: [Day]
    let layout: GridLayout
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(HabitStore.self) private var store
    @Environment(\.today) private var today

    private var weekStart: Day { days.first ?? today.weekStart }

    var body: some View {
        let history = habit.history
        let streak = history.currentStreak(today: today)
        let weekRate = history.weekRate(weekStart: weekStart, today: today)
        let weekComplete = store.isWeekComplete(habit, weekStart: weekStart, today: today)
        let canMarkWeek = !store.eligibleDays(for: habit, weekStart: weekStart, today: today).isEmpty

        Group {
            if layout.isStacked {
                VStack(alignment: .leading, spacing: 8) {
                    nameLink(streak: streak, weekRate: weekRate, weekComplete: weekComplete, canMarkWeek: canMarkWeek)
                    cells(history)
                }
            } else {
                HStack(spacing: 0) {
                    nameLink(streak: streak, weekRate: weekRate, weekComplete: weekComplete, canMarkWeek: canMarkWeek)
                        .frame(width: layout.nameWidth, alignment: .leading)
                    cells(history)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .contextMenu {
            Button { setWeek(done: !weekComplete) } label: {
                Label(
                    weekComplete ? "Unmark Whole Week" : "Complete Whole Week",
                    systemImage: weekComplete ? "arrow.uturn.backward.circle" : "checkmark.circle"
                )
            }
            .disabled(!canMarkWeek)
            Button(action: onEdit) {
                Label("Edit Habit", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete Habit", systemImage: "trash")
            }
        }
    }

    private func nameLink(streak: Int, weekRate: CompletionRate, weekComplete: Bool, canMarkWeek: Bool) -> some View {
        NavigationLink(value: habit.id) {
            HStack(spacing: 6) {
                HabitIcon(emoji: habit.emoji, name: habit.name, color: habit.habitColor, size: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(layout.isStacked ? nil : 2)
                        .multilineTextAlignment(.leading)
                    statsLine(streak: streak, weekRate: weekRate)
                }
                Spacer(minLength: 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilitySummary(streak: streak, weekRate: weekRate))
        .accessibilityHint("Shows history and stats.")
        .accessibilityIdentifier("habitRow.\(habit.name)")
        .accessibilityActions {
            if canMarkWeek {
                Button(weekComplete ? "Unmark whole week" : "Complete whole week") { setWeek(done: !weekComplete) }
            }
            Button("Edit habit", action: onEdit)
            Button("Delete habit", action: onDelete)
        }
    }

    private func statsLine(streak: Int, weekRate: CompletionRate) -> some View {
        HStack(spacing: 6) {
            if streak > 0 {
                // Only the flame is orange: orange text on white is too faint to read.
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(streak)")
                }
            }
            if weekRate.fraction != nil {
                Text(weekRate.percentText)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func cells(_ history: HabitHistory) -> some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                DayCell(
                    state: DayState(day: day, history: history, today: today),
                    color: habit.habitColor.color,
                    isToday: day == today,
                    diameter: layout.cellDiameter
                ) {
                    withAnimation(.snappy) { store.toggle(habit, on: day, today: today) }
                }
                .accessibilityLabel("\(habit.name), \(day.accessibilityName)\(day == today ? ", today" : "")")
                .accessibilityIdentifier("cell.\(habit.name).\(day.weekdayIndex)")
            }
        }
    }

    private func setWeek(done: Bool) {
        withAnimation(.snappy) { store.setWeek(habit, weekStart: weekStart, today: today, done: done) }
    }

    private func accessibilitySummary(streak: Int, weekRate: CompletionRate) -> String {
        var parts = [habit.name]
        if streak > 0 { parts.append("\(streak) day streak") }
        if weekRate.fraction != nil { parts.append("\(weekRate.percentText) this week") }
        return parts.joined(separator: ", ")
    }
}

struct DayCell: View {
    let state: DayState
    let color: Color
    let isToday: Bool
    let diameter: CGFloat
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                switch state {
                case .done:
                    Circle().fill(color)
                    Image(systemName: "checkmark")
                        .font(.system(size: diameter * 0.42, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                case .open:
                    Circle().strokeBorder(color.opacity(isToday ? 1 : 0.55), lineWidth: isToday ? 2.5 : 2)
                case .upcoming:
                    Circle().strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                case .unscheduled:
                    Circle().fill(Color(.systemGray5))
                }
            }
            .frame(width: diameter, height: diameter)
            .scaleEffect(state == .done ? 1 : 0.92)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!state.isInteractive)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: state)
        .accessibilityValue(state.accessibilityDescription)
        .accessibilityAddTraits(state == .done ? .isSelected : [])
    }
}
