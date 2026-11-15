import SwiftData
import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry {
    struct Item: Identifiable {
        let id: UUID
        let name: String
        let emoji: String
        let color: HabitColor
        let isDone: Bool
    }

    let date: Date
    let items: [Item]
    /// False when the widget can't reach the app's data (no App Group on this install).
    let isStoreAvailable: Bool

    var doneCount: Int { items.filter(\.isDone).count }

    /// Shown in the widget gallery before the app has any data.
    static let preview = TodayEntry(
        date: Date(),
        items: [
            Item(id: UUID(), name: "Drink water", emoji: "💧", color: .blue, isDone: true),
            Item(id: UUID(), name: "Read for 20 minutes", emoji: "📚", color: .orange, isDone: false),
            Item(id: UUID(), name: "Workout", emoji: "🏋️", color: .red, isDone: true),
            Item(id: UUID(), name: "Meditate", emoji: "🧘", color: .purple, isDone: false),
        ],
        isStoreAvailable: true
    )
}

private struct WidgetHabit {
    let id: UUID
    let name: String
    let emoji: String
    let color: HabitColor
    let history: HabitHistory
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        .preview
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        if context.isPreview {
            completion(.preview)
            return
        }
        let now = Date()
        completion(Self.entry(for: Day.today(now: now), date: now, habits: Self.loadHabits()))
    }

    /// One entry for now and one for midnight, so the widget moves on to the new day by itself.
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date()
        let habits = Self.loadHabits()
        let today = Day.today(now: now)
        let tomorrow = today.adding(1)
        let entries = [
            Self.entry(for: today, date: now, habits: habits),
            Self.entry(for: tomorrow, date: tomorrow.date(), habits: habits),
        ]
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private static func loadHabits() -> [WidgetHabit]? {
        guard HabitStoreFactory.sharedStoreURL != nil,
              let container = try? HabitStoreFactory.makeContainer() else { return nil }
        let context = ModelContext(container)
        guard let habits = try? context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)])) else { return nil }
        // Copied into plain values while the context is still alive.
        return habits.map { WidgetHabit(id: $0.id, name: $0.name, emoji: $0.emoji, color: $0.habitColor, history: $0.history) }
    }

    private static func entry(for day: Day, date: Date, habits: [WidgetHabit]?) -> TodayEntry {
        guard let habits else {
            return TodayEntry(date: date, items: [], isStoreAvailable: false)
        }
        let items = habits
            .filter { $0.history.isScheduled(day) }
            .map { TodayEntry.Item(id: $0.id, name: $0.name, emoji: $0.emoji, color: $0.color, isDone: $0.history.isDone(day)) }
        return TodayEntry(date: date, items: items, isStoreAvailable: true)
    }
}

struct TodayWidgetView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family

    private var maxItems: Int { family == .systemSmall ? 3 : 6 }

    var body: some View {
        if !entry.isStoreAvailable {
            message("Open Habituate to see today's habits here.")
        } else if entry.items.isEmpty {
            message("Nothing scheduled for today.")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Today")
                        .font(.headline)
                    Spacer(minLength: 4)
                    Text("\(entry.doneCount)/\(entry.items.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(entry.doneCount) of \(entry.items.count) done")
                }
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: family == .systemSmall ? 1 : 2),
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(entry.items.prefix(maxItems)) { item in
                        row(item)
                    }
                }
                if entry.items.count > maxItems {
                    Text("+\(entry.items.count - maxItems) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func row(_ item: TodayEntry.Item) -> some View {
        HStack(spacing: 6) {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.color.color)
            Text(item.emoji.isEmpty ? item.name : "\(item.emoji) \(item.name)")
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(item.isDone ? .secondary : .primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name), \(item.isDone ? "done" : "not done")")
    }

    private func message(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "checklist")
                .font(.title2)
                .foregroundStyle(.tint)
            Text(text)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TodayHabitsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayHabits", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Today's Habits")
        .description("See which of today's habits are done.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct HabituateWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayHabitsWidget()
    }
}
