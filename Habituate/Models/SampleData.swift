import Foundation

/// Demo habits with a few weeks of believable history, added on first launch.
enum SampleData {
    static let historyLength = 56

    private struct Template {
        let name: String
        let emoji: String
        let color: HabitColor
        let weekdays: WeekdaySet
        let rate: Double
        /// Every scheduled day in this many recent days is ticked, so the demo shows live streaks.
        let recentRun: Int
        let doneToday: Bool
    }

    private static let templates: [Template] = [
        Template(name: "Drink 8 glasses of water", emoji: "💧", color: .blue, weekdays: .all, rate: 0.85, recentRun: 12, doneToday: true),
        Template(name: "Read for 20 minutes", emoji: "📚", color: .orange, weekdays: .all, rate: 0.7, recentRun: 4, doneToday: false),
        Template(name: "Workout", emoji: "🏋️", color: .red, weekdays: WeekdaySet(indices: [0, 2, 4]), rate: 0.8, recentRun: 21, doneToday: false),
        Template(name: "Meditate", emoji: "🧘", color: .purple, weekdays: .all, rate: 0.6, recentRun: 2, doneToday: false),
        Template(name: "Practice guitar", emoji: "🎸", color: .green, weekdays: WeekdaySet(indices: [1, 3, 5]), rate: 0.75, recentRun: 9, doneToday: true),
        Template(name: "Journal", emoji: "✍️", color: .teal, weekdays: .workdays, rate: 0.65, recentRun: 0, doneToday: false),
    ]

    static func makeHabits(today: Day) -> [Habit] {
        var generator = SeededGenerator(seed: 2_024)
        let start = today.adding(-historyLength).weekStart
        return templates.enumerated().map { index, template in
            let habit = Habit(
                name: template.name,
                emoji: template.emoji,
                color: template.color,
                weekdays: template.weekdays,
                start: start,
                sortOrder: index
            )
            habit.isSample = true
            for day in start..<today where template.weekdays.contains(day) {
                let isRecent = day.distance(to: today) <= template.recentRun
                if isRecent || Double.random(in: 0..<1, using: &generator) < template.rate {
                    habit.setDone(true, on: day)
                }
            }
            if template.doneToday && template.weekdays.contains(today) {
                habit.setDone(true, on: today)
            }
            return habit
        }
    }
}

/// SplitMix64, so the sample history looks the same on every install.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
