import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .tracker
    @State private var draftHours = 0
    @State private var draftMinutes = 0
    @State private var displayedMonth = Date()
    @State private var selectedDate = Date()
    @State private var isShowingDayDetails = false
    @State private var summaryScope: SummaryScope = .month
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @AppStorage("timeEntriesJSON") private var timeEntriesJSON = ""

    private let calendar = Calendar.current

    var body: some View {
        TabView(selection: $selectedTab) {
            trackerTab
                .tabItem {
                    Label("Tracker", systemImage: "calendar")
                }
                .tag(AppTab.tracker)

            settingsTab
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .preferredColorScheme(AppearanceMode(rawValue: appearanceModeRaw)?.colorScheme)
        .sheet(isPresented: $isShowingDayDetails) {
            dayDetailsSheet(entries: loadEntries())
        }
    }

    private var trackerTab: some View {
        let entries = loadEntries()

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard(entries: entries)

                calendarCard(entries: entries)
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGroupedBackground).opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var settingsTab: some View {
        SettingsView(
            appearanceModeRaw: $appearanceModeRaw,
            onClearHours: clearAllHours
        )
    }

    private func summaryCard(entries: [DailyHoursEntry]) -> some View {
        let range = dateRange(for: summaryScope)
        let total = totalHours(in: range, entries: entries)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Summary")
                    .font(.headline)

                Spacer()

                Picker("Summary scope", selection: $summaryScope) {
                    ForEach(SummaryScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }

            Text(formatDuration(total))
                .font(.system(size: 34, weight: .bold, design: .rounded))
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private func calendarCard(entries: [DailyHoursEntry]) -> some View {
        if summaryScope == .week {
            weekCalendarCard(entries: entries)
        } else {
            monthCalendarCard(entries: entries)
        }
    }

    private func monthCalendarCard(entries: [DailyHoursEntry]) -> some View {
        let monthDays = monthGridDates(for: displayedMonth)
        let weekdaySymbols = orderedWeekdaySymbols()

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    displayedMonth = shiftMonth(displayedMonth, by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)

                Spacer()

                VStack(spacing: 2) {
                    Text(monthTitle(for: displayedMonth))
                        .font(.title3.weight(.semibold))
                    Text("Tap a day to inspect or add time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    displayedMonth = shiftMonth(displayedMonth, by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(for: date, entries: entries)
                    } else {
                        Color.clear
                            .frame(height: 54)
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func weekCalendarCard(entries: [DailyHoursEntry]) -> some View {
        let weekDays = weekGridDates(for: selectedDate)
        let weekdaySymbols = mondayWeekdaySymbols()

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    selectedDate = shiftWeek(selectedDate, by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)

                Spacer()

                VStack(spacing: 2) {
                    Text(weekTitle(for: selectedDate))
                        .font(.title3.weight(.semibold))
                    Text("Monday to Sunday")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    selectedDate = shiftWeek(selectedDate, by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(weekDays, id: \.self) { date in
                    dayCell(for: date, entries: entries)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func dayCell(for date: Date, entries: [DailyHoursEntry]) -> some View {
        let dayHours = hours(on: date, entries: entries)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)

        return Button {
            openDayDetails(for: date)
        } label: {
            VStack(spacing: 6) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline.weight(.semibold))

                if isToday {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                } else {
                    Text(" ")
                        .font(.caption2)
                        .frame(height: 6)
                }

                if dayHours > 0 {
                    Text(formatDuration(dayHours))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text(" ")
                        .font(.caption2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func dayDetailsSheet(entries: [DailyHoursEntry]) -> some View {
        let selectedHours = hours(on: selectedDate, entries: entries)

        return NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(dayLabel(for: selectedDate))
                        .font(.title2.bold())

                    Text("Logged: \(formatDuration(selectedHours))")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hours")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Picker("Hours", selection: $draftHours) {
                            ForEach(0...24, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Minutes")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Picker("Minutes", selection: $draftMinutes) {
                            ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { value in
                                Text(String(format: "%02d", value)).tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 160)

                Button("Save Hours") {
                    let totalHours = Double(draftHours) + Double(draftMinutes) / 60.0
                    saveHours(for: selectedDate, hours: totalHours)
                    isShowingDayDetails = false
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding()
            .navigationTitle("Day Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isShowingDayDetails = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveHours(for date: Date, hours: Double) {
        var entries = loadEntries()
        let normalizedDate = calendar.startOfDay(for: date)

        if hours <= 0 {
            entries.removeAll { calendar.isDate($0.date, inSameDayAs: normalizedDate) }
        } else {
            if let index = entries.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: normalizedDate) }) {
                entries[index].hours = hours
            } else {
                entries.append(DailyHoursEntry(date: normalizedDate, hours: hours))
            }
        }

        saveEntries(entries)
    }

    private func openDayDetails(for date: Date) {
        selectedDate = date
        displayedMonth = date
        let existingHours = hours(on: date, entries: loadEntries())
        let totalMinutes = Int((existingHours * 60).rounded())
        draftHours = min(totalMinutes / 60, 24)
        draftMinutes = min(((totalMinutes % 60 + 2) / 5) * 5, 55)
        isShowingDayDetails = true
    }

    private func clearAllHours() {
        timeEntriesJSON = ""
    }

    private func loadEntries() -> [DailyHoursEntry] {
        guard !timeEntriesJSON.isEmpty, let data = timeEntriesJSON.data(using: .utf8) else {
            return []
        }

        do {
            return try JSONDecoder().decode([DailyHoursEntry].self, from: data)
        } catch {
            return []
        }
    }

    private func saveEntries(_ entries: [DailyHoursEntry]) {
        do {
            let data = try JSONEncoder().encode(entries.sorted { $0.date < $1.date })
            timeEntriesJSON = String(decoding: data, as: UTF8.self)
        } catch {
            timeEntriesJSON = ""
        }
    }

    private func hours(on date: Date, entries: [DailyHoursEntry]) -> Double {
        entries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.hours }
    }

    private func totalHours(in range: DateInterval?, entries: [DailyHoursEntry]) -> Double {
        dailyTotals(in: range, entries: entries).reduce(0) { $0 + $1.hours }
    }

    private func dailyTotals(in range: DateInterval?, entries: [DailyHoursEntry]) -> [DailyHoursEntry] {
        let filtered = entries.filter { entry in
            guard let range else { return true }
            return range.contains(entry.date)
        }

        return Dictionary(grouping: filtered, by: { calendar.startOfDay(for: $0.date) })
            .map { date, groupedEntries in
                DailyHoursEntry(date: date, hours: groupedEntries.reduce(0) { $0 + $1.hours })
            }
            .sorted { $0.date < $1.date }
    }

    private func dateRange(for scope: SummaryScope) -> DateInterval? {
        switch scope {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: selectedDate)
        case .month:
            return calendar.dateInterval(of: .month, for: selectedDate)
        case .allTime:
            return nil
        }
    }

    private func summaryLabel(for scope: SummaryScope) -> String {
        switch scope {
        case .week:
            return "This Week"
        case .month:
            return "This Month"
        case .allTime:
            return "All Time"
        }
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private func formatDuration(_ hours: Double) -> String {
        let totalMinutes = max(0, Int((hours * 60).rounded()))
        let displayHours = totalMinutes / 60
        let displayMinutes = totalMinutes % 60
        return String(format: "%d:%02d", displayHours, displayMinutes)
    }

    private func orderedWeekdaySymbols() -> [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let startIndex = calendar.firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private func mondayWeekdaySymbols() -> [String] {
        let mondayCalendar = mondayFirstCalendar
        let symbols = mondayCalendar.shortStandaloneWeekdaySymbols
        let startIndex = mondayCalendar.firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private func monthGridDates(for date: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let dayRange = calendar.range(of: .day, in: .month, for: date) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingEmptySlots = (firstWeekday - calendar.firstWeekday + 7) % 7
        let leadingBlanks = Array<Date?>(repeating: nil, count: leadingEmptySlots)

        let monthDays = dayRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }

        return leadingBlanks + monthDays.map(Optional.some)
    }

    private func weekGridDates(for date: Date) -> [Date] {
        let weekCalendar = mondayFirstCalendar
        guard let weekInterval = weekCalendar.dateInterval(of: .weekOfYear, for: date) else {
            return []
        }

        return (0..<7).compactMap { offset in
            weekCalendar.date(byAdding: .day, value: offset, to: weekCalendar.startOfDay(for: weekInterval.start))
        }
    }

    private func shiftMonth(_ date: Date, by offset: Int) -> Date {
        calendar.date(byAdding: .month, value: offset, to: date) ?? date
    }

    private func shiftWeek(_ date: Date, by offset: Int) -> Date {
        mondayFirstCalendar.date(byAdding: .weekOfYear, value: offset, to: date) ?? date
    }

    private func weekTitle(for date: Date) -> String {
        let weekCalendar = mondayFirstCalendar
        guard let weekInterval = weekCalendar.dateInterval(of: .weekOfYear, for: date) else {
            return "This Week"
        }

        let formatter = DateFormatter()
        formatter.calendar = weekCalendar
        formatter.locale = .current
        formatter.dateFormat = "MMM d"

        return "\(formatter.string(from: weekInterval.start)) - \(formatter.string(from: weekInterval.end.addingTimeInterval(-1)))"
    }

    private var mondayFirstCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }
}

private struct SettingsView: View {
    @Binding var appearanceModeRaw: String
    let onClearHours: () -> Void
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profileCard
                    appearanceCard
                    clearHoursCard
                }
                .padding()
            }
            .navigationTitle("Settings")
        }
        .alert("Clear all hours?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                onClearHours()
            }
        } message: {
            Text("This removes all saved hours from the tracker.")
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile")
                .font(.headline)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Login placeholder")
                        .font(.subheadline.weight(.semibold))
                    Text("Add account sign-in later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Log In") {}
                .buttonStyle(.bordered)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.headline)

            Picker("Theme", selection: $appearanceModeRaw) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)

            Text("Switch between light and dark mode, or follow the system setting.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var clearHoursCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data")
                .font(.headline)

            Text("Delete all saved hours on this device.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Clear Hours", role: .destructive) {
                showClearConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct DailyHoursEntry: Identifiable, Codable, Hashable {
    let date: Date
    var hours: Double

    var id: Date { date }
}

private enum SummaryScope: String, CaseIterable, Identifiable {
    case week
    case month
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week:
            return "Week"
        case .month:
            return "Month"
        case .allTime:
            return "All"
        }
    }
}

private enum AppTab: Hashable {
    case tracker
    case settings
}

private enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

#Preview {
    ContentView()
}
