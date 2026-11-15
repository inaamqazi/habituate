import SwiftData
import SwiftUI

/// The main screen: one row per habit, one column per day of the week.
struct WeekView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.today) private var today
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @State private var week = WeekViewModel()
    @State private var editorMode: HabitEditorMode?
    @State private var deletion: DeletionRequest?
    @State private var showingManage = false
    @State private var showingSettings = false

    var body: some View {
        Group {
            if habits.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .navigationTitle(habits.isEmpty ? "Habituate" : week.title(today: today))
        .toolbar { toolbarContent }
        .navigationDestination(for: UUID.self) { HabitDetailView(habitID: $0) }
        .habitEditorSheet($editorMode)
        .confirmHabitDeletion($deletion) { request in
            withAnimation { store.delete(id: request.id) }
        }
        .sheet(isPresented: $showingManage) { ManageHabitsView() }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .onChange(of: habits.isEmpty) { _, isEmpty in
            if isEmpty { week.goToCurrentWeek() }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Habits Yet", systemImage: "checklist")
        } description: {
            Text("Add the habits you want to build, then tick them off each day.")
        } actions: {
            Button("Add Your First Habit") { editorMode = .new }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("addFirstHabit")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button { showingManage = true } label: {
                    Label("Manage Habits", systemImage: "list.bullet")
                }
                Button { showingSettings = true } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .accessibilityIdentifier("moreMenu")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { editorMode = .new } label: {
                Label("Add Habit", systemImage: "plus")
            }
            .accessibilityIdentifier("addHabit")
        }
    }

    private var grid: some View {
        let days = week.days(today: today)
        let weekStart = week.weekStart(today: today)
        let weekRate = habits.reduce(CompletionRate()) { $0 + $1.history.weekRate(weekStart: weekStart, today: today) }
        return GeometryReader { proxy in
            let layout = GridLayout(width: proxy.size.width, stacked: dynamicTypeSize.isAccessibilitySize)
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    WeekSummaryCard(
                        rate: weekRate,
                        isCurrentWeek: week.isCurrentWeek,
                        isTodayComplete: store.isDayComplete(habits, on: today),
                        canCompleteToday: !store.habitsScheduled(habits, on: today).isEmpty,
                        onToggleToday: toggleToday
                    )
                    Section {
                        VStack(spacing: 0) {
                            ForEach(habits) { habit in
                                HabitRowView(
                                    habit: habit,
                                    days: days,
                                    layout: layout,
                                    onEdit: { editorMode = .edit(habit) },
                                    onDelete: { deletion = DeletionRequest(habit: habit) }
                                )
                                Divider().padding(.leading, 16)
                            }
                        }
                        .id(weekStart)
                        .transition(.push(from: week.transitionEdge))
                    } header: {
                        DayHeaderRow(days: days, layout: layout)
                            .id(weekStart)
                            .transition(.push(from: week.transitionEdge))
                    }
                }
                .padding(.bottom, 16)
            }
            .simultaneousGesture(swipeGesture)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            WeekNavigationBar(
                rangeText: week.rangeText(today: today),
                isCurrentWeek: week.isCurrentWeek,
                canGoBack: canGoBack,
                canGoForward: week.canGoForward,
                onBack: goBack,
                onForward: goForward,
                onToday: { withAnimation(.snappy) { week.goToCurrentWeek() } }
            )
        }
    }

    private var canGoBack: Bool {
        week.canGoBack(today: today, earliestStart: habits.map(\.start).min())
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                guard abs(horizontal) > 80, abs(horizontal) > abs(value.translation.height) * 2 else { return }
                if horizontal > 0 { goBack() } else { goForward() }
            }
    }

    private func goBack() {
        guard canGoBack else { return }
        withAnimation(.snappy) { week.goBack() }
    }

    private func goForward() {
        guard week.canGoForward else { return }
        withAnimation(.snappy) { week.goForward() }
    }

    private func toggleToday() {
        let done = !store.isDayComplete(habits, on: today)
        withAnimation(.snappy) { store.setDay(habits, on: today, done: done) }
    }
}

/// Column widths for the grid, worked out from the screen width so 7 days always fit without scrolling sideways.
struct GridLayout {
    let isStacked: Bool
    let nameWidth: CGFloat
    let cellDiameter: CGFloat

    init(width: CGFloat, stacked: Bool) {
        isStacked = stacked
        let usable = max(width - 32, 0)
        nameWidth = stacked ? 0 : min(max(usable * 0.32, 92), 200)
        let column = (usable - nameWidth) / 7
        cellDiameter = max(min(column - 6, stacked ? 40 : 34), 18)
    }
}
