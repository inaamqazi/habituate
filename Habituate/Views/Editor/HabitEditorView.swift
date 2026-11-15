import SwiftUI

struct HabitEditorView: View {
    let onDeleteRequested: (DeletionRequest) -> Void

    @Environment(HabitStore.self) private var store
    @Environment(\.today) private var today
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model: HabitEditorViewModel
    @State private var confirmingDelete: DeletionRequest?
    @FocusState private var nameFocused: Bool
    @ScaledMetric(relativeTo: .title2) private var scaledSwatch: CGFloat = 44

    /// Emoji and colour swatches are pictures; past a point, bigger only means fewer per row.
    private var swatchSize: CGFloat { min(scaledSwatch, 52) }

    init(mode: HabitEditorMode, onDeleteRequested: @escaping (DeletionRequest) -> Void) {
        self.onDeleteRequested = onDeleteRequested
        _model = State(initialValue: HabitEditorViewModel(habit: mode.habit))
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                iconSection
                colorSection
                scheduleSection
                reminderSection
                if model.habit != nil {
                    deleteSection
                }
            }
            .navigationTitle(model.isNew ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.isNew ? "Add" : "Save") {
                        model.save(using: store, today: today)
                        dismiss()
                    }
                    .disabled(!model.draft.isValid)
                    .accessibilityIdentifier("saveHabit")
                }
            }
            .interactiveDismissDisabled(model.hasChanges)
            .task {
                if model.isNew { nameFocused = true }
                await model.refreshNotificationStatus(using: store.reminders)
            }
            .confirmHabitDeletion($confirmingDelete) { request in
                onDeleteRequested(request)
                dismiss()
            }
        }
    }

    private var nameSection: some View {
        Section {
            TextField("Name", text: $model.draft.name, prompt: Text("For example, Read for 20 minutes"))
                .focused($nameFocused)
                .submitLabel(.done)
                .accessibilityIdentifier("habitNameField")
                .onChange(of: model.draft.name) { model.limitNameLength() }
        } header: {
            Text("Name")
        }
    }

    private var iconSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: swatchSize), spacing: 8)], spacing: 8) {
                iconButton(emoji: "", label: "No icon")
                ForEach(HabitEditorViewModel.suggestedEmoji, id: \.self) { emoji in
                    iconButton(emoji: emoji, label: emoji)
                }
            }
            .padding(.vertical, 4)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            TextField(
                "Custom icon",
                text: Binding(
                    get: { HabitEditorViewModel.suggestedEmoji.contains(model.draft.emoji) ? "" : model.draft.emoji },
                    set: { model.setCustomEmoji($0) }
                ),
                prompt: Text("Or type any emoji")
            )
            .accessibilityIdentifier("customEmojiField")
        } header: {
            Text("Icon")
        }
    }

    private func iconButton(emoji: String, label: String) -> some View {
        let isSelected = model.draft.emoji == emoji
        return Button { model.draft.emoji = emoji } label: {
            Group {
                if emoji.isEmpty {
                    Image(systemName: "circle.slash")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                } else {
                    Text(emoji).font(.title2)
                }
            }
            .frame(width: swatchSize, height: swatchSize)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var colorSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: swatchSize), spacing: 8)], spacing: 8) {
                ForEach(HabitColor.allCases) { color in
                    let isSelected = model.draft.color == color
                    Button { model.draft.color = color } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: swatchSize * 0.72, height: swatchSize * 0.72)
                            .overlay {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.footnote.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: swatchSize, height: swatchSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(color.displayName)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        } header: {
            Text("Colour")
        }
    }

    private var scheduleSection: some View {
        Section {
            if dynamicTypeSize.isAccessibilitySize {
                schedulePicker.pickerStyle(.menu)
            } else {
                schedulePicker.pickerStyle(.segmented)
            }
            if !model.draft.everyDay {
                WeekdayPicker(selection: $model.draft.weekdays)
            }
        } header: {
            Text("Schedule")
        } footer: {
            if !model.draft.isScheduleValid {
                Text("Choose at least one day.")
                    .foregroundStyle(.red)
            } else if !model.isNew {
                Text("Changes apply from today. Past days keep the schedule they had.")
            }
        }
    }

    private var schedulePicker: some View {
        Picker("Repeat", selection: $model.draft.everyDay) {
            Text("Every day").tag(true)
            Text("Specific days").tag(false)
        }
        .accessibilityIdentifier("schedulePicker")
    }

    private var reminderSection: some View {
        Section {
            Toggle(
                "Daily reminder",
                isOn: Binding(
                    get: { model.draft.reminderEnabled },
                    set: { enabled in Task { await model.setReminder(enabled, using: store.reminders) } }
                )
            )
            .accessibilityIdentifier("reminderToggle")
            if model.draft.reminderEnabled {
                DatePicker("Time", selection: $model.reminderTime, displayedComponents: .hourAndMinute)
            }
            if model.notificationsDenied {
                NotificationsDeniedNote()
            }
        } header: {
            Text("Reminder")
        } footer: {
            if model.draft.reminderEnabled {
                Text("You'll be reminded on the days this habit is scheduled.")
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete Habit", role: .destructive) {
                if let habit = model.habit {
                    confirmingDelete = DeletionRequest(habit: habit)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("deleteHabit")
        }
    }
}

/// Seven toggle buttons, Monday to Sunday.
struct WeekdayPicker: View {
    @Binding var selection: WeekdaySet
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: isLarge ? 2 : 7)
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<7, id: \.self) { index in
                let isOn = selection.contains(.weekday(index))
                Button { selection.formSymmetricDifference(.weekday(index)) } label: {
                    Text(isLarge ? WeekdayNames.full(index) : WeekdayNames.short(index))
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                        .background(isOn ? Color.accentColor : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(WeekdayNames.full(index))
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("weekday.\(index)")
            }
        }
        .padding(.vertical, 4)
    }
}
