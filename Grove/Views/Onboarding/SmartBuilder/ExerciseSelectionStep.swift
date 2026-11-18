import SwiftUI

/// The exercise editor both setup paths end in. Own-routine days start empty and
/// generated days start filled; either way the day's list is on top (drag to reorder,
/// swipe or tap to remove), the library below is always open and search-first, and
/// "Fill the rest for me" tops a day up with suggestions that don't repeat it.
struct ExerciseSelectionStep: View {
    @Bindable var state: SmartBuilderState
    let exercises: [Exercise]

    @State private var selectedDayIndex = 0
    @State private var searchText = ""
    @State private var filter: LibraryFilter = .forDay
    @State private var appeared = false
    @State private var showingCreateExercise = false
    @FocusState private var searchFocused: Bool

    enum LibraryFilter: Hashable {
        case forDay, all, group(MuscleGroup)
    }

    private static let searchRowID = "exercise-search"

    /// How many results the library shows before asking for a narrower search.
    private let resultLimit = 40

    private var dayLabels: [String] { state.displayDayLabels }

    private var currentDayExercises: [Exercise] {
        state.dayExerciseSelections[selectedDayIndex] ?? []
    }

    private var currentDayLabel: String {
        guard selectedDayIndex < dayLabels.count else { return "" }
        return dayLabels[selectedDayIndex]
    }

    private var muscleGroupsForDay: [MuscleGroup] {
        state.muscleGroups(forDayIndex: selectedDayIndex)
    }

    /// "For Push" only makes sense when we know what the day trains.
    private var effectiveFilter: LibraryFilter {
        if filter == .forDay && muscleGroupsForDay.isEmpty { return .all }
        return filter
    }

    private var filterOptions: [LibraryFilter] {
        var options: [LibraryFilter] = []
        if !muscleGroupsForDay.isEmpty { options.append(.forDay) }
        options.append(.all)
        options += MuscleGroup.allCases
            .filter { group in exercises.contains { $0.muscleGroup == group } }
            .map { .group($0) }
        return options
    }

    /// Library matches, minus what's already on the day. A search looks through
    /// everything, since people type what they do regardless of the day's name.
    private var availableExercises: [Exercise] {
        let selected = Set(currentDayExercises.map(\.id))
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let pool = exercises.filter { !selected.contains($0.id) }

        let matches: [Exercise]
        if !query.isEmpty {
            matches = pool.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || $0.muscleGroup.rawValue.localizedCaseInsensitiveContains(query)
            }
        } else {
            switch effectiveFilter {
            case .forDay: matches = pool.filter { muscleGroupsForDay.contains($0.muscleGroup) }
            case .all: matches = pool
            case .group(let group): matches = pool.filter { $0.muscleGroup == group }
            }
        }
        return matches.sorted { $0.sortPriority < $1.sortPriority }
    }

    private var fillTarget: Int { max(1, state.exerciseBudget) }

    private var fillSuggestions: [Exercise] {
        SmartBuilderEngine.suggestions(
            toFill: currentDayExercises,
            muscleGroups: muscleGroupsForDay,
            target: fillTarget,
            from: exercises
        )
    }

    private var estimatedMinutes: Int {
        state.estimatedMinutes(for: selectedDayIndex)
    }

    /// Only the generated path asked for a session length to be over.
    private var isOverBudget: Bool {
        !state.isOwnRoutine && estimatedMinutes > state.minutesPerWorkout
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 16)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4), value: appeared)

            dayTabBar
                .padding(.top, 16)

            runningIndicator
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 4)

            ScrollViewReader { proxy in
                List {
                    daySection
                    librarySection
                    Section {
                        planSummary
                            .padding(.vertical, 12)
                            .editorRow()
                    }
                }
                .listStyle(.plain)
                .listSectionSpacing(.compact)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .environment(\.defaultMinListRowHeight, 0)
                // Bring the search box up so results show above the keyboard.
                .onChange(of: searchFocused) { _, focused in
                    guard focused else { return }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(Self.searchRowID, anchor: .top)
                    }
                }
            }
        }
        .onAppear {
            appeared = true
            if let empty = state.firstEmptyDayIndex, state.isOwnRoutine {
                selectedDayIndex = empty
            }
        }
        .sensoryFeedback(.selection, trigger: currentDayExercises.count)
        .sheet(isPresented: $showingCreateExercise) {
            AddExerciseView(
                prefillName: searchText.trimmingCharacters(in: .whitespaces),
                initialMuscleGroup: muscleGroupsForDay.first ?? .chest
            ) { exercise in
                add(exercise)
                searchText = ""
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text(state.isOwnRoutine ? "Add your exercises" : "Build your workouts")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.groveText)

            Text(state.isOwnRoutine
                 ? "Search for what you do, or let us fill in the rest"
                 : "Swipe to remove, search to add, drag to reorder")
                .font(.subheadline)
                .foregroundStyle(Color.groveTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Day Tab Bar

    private var dayTabBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(dayLabels.enumerated()), id: \.offset) { index, label in
                        let isSelected = selectedDayIndex == index
                        let isEmpty = (state.dayExerciseSelections[index] ?? []).isEmpty
                        Button {
                            selectDay(index)
                        } label: {
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("Day \(index + 1)")
                                    if isEmpty {
                                        Circle()
                                            .fill(Color.groveTerracotta)
                                            .frame(width: 5, height: 5)
                                    }
                                }
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(isSelected ? Color.groveSage : Color.groveTextSecondary.opacity(0.6))

                                Text(label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(isSelected ? Color.groveText : Color.groveTextSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.groveSage.opacity(0.1) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? Color.groveSage.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .padding(.horizontal, 24)
            }
            .onChange(of: selectedDayIndex) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }

    // MARK: - Running Indicator

    private var runningIndicator: some View {
        HStack(spacing: 8) {
            let count = currentDayExercises.count

            Image(systemName: "clock")
                .font(.caption)
                .foregroundStyle(isOverBudget ? Color.groveTerracotta : Color.groveSage)

            Text("\(count) exercise\(count == 1 ? "" : "s") · ~\(estimatedMinutes) min")
                .font(.caption.weight(.medium))
                .foregroundStyle(isOverBudget ? Color.groveTerracotta : Color.groveText)

            if isOverBudget {
                Text("over budget")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.groveTerracotta)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.groveTerracotta.opacity(0.1))
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.groveCardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Day Section

    @ViewBuilder
    private var daySection: some View {
        Section {
            if currentDayExercises.isEmpty {
                emptyDayRow
                    .editorRow()
            }

            ForEach(currentDayExercises, id: \.id) { exercise in
                selectedRow(exercise)
                    .editorRow()
            }
            .onMove { source, destination in
                var list = currentDayExercises
                list.move(fromOffsets: source, toOffset: destination)
                state.dayExerciseSelections[selectedDayIndex] = list
            }
            .onDelete { offsets in
                var list = currentDayExercises
                list.remove(atOffsets: offsets)
                state.dayExerciseSelections[selectedDayIndex] = list
            }

            if currentDayExercises.count < fillTarget, !fillSuggestions.isEmpty {
                fillRow
                    .editorRow()
            }
        }
    }

    private var emptyDayRow: some View {
        VStack(spacing: 6) {
            Image(systemName: "dumbbell")
                .font(.title3)
                .foregroundStyle(Color.groveSage.opacity(0.6))
            Text("No exercises for \(currentDayLabel) yet")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.groveText)
            Text("Search below for the ones you do")
                .font(.caption)
                .foregroundStyle(Color.groveTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private func selectedRow(_ exercise: Exercise) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(Color.groveTextSecondary.opacity(0.5))

            exerciseLabel(exercise)

            Spacer(minLength: 8)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { remove(exercise) }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.groveMutedRust.opacity(0.8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(exercise.name)")
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var fillRow: some View {
        let suggestions = fillSuggestions
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                var list = currentDayExercises
                list.append(contentsOf: suggestions)
                state.dayExerciseSelections[selectedDayIndex] = list
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.groveSage)
                    .frame(width: 28, height: 28)
                    .background(Color.groveSage.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(currentDayExercises.isEmpty ? "Fill this day for me" : "Fill the rest for me")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.groveSage)
                    Text("Adds \(suggestions.count) suggestion\(suggestions.count == 1 ? "" : "s") that don't repeat what's here")
                        .font(.caption2)
                        .foregroundStyle(Color.groveTextSecondary)
                }

                Spacer()
            }
            .padding(10)
            .background(Color.groveSage.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Library Section

    @ViewBuilder
    private var librarySection: some View {
        Section {
            searchField
                .padding(.top, 14)
                .padding(.bottom, 8)
                .editorRow()
                .id(Self.searchRowID)

            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                filterChips
                    .padding(.bottom, 6)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            let results = availableExercises
            ForEach(results.prefix(resultLimit), id: \.id) { exercise in
                libraryRow(exercise)
                    .editorRow()
            }

            if results.count > resultLimit {
                Text("\(results.count - resultLimit) more — search to narrow it down")
                    .font(.caption)
                    .foregroundStyle(Color.groveTextSecondary)
                    .padding(.vertical, 8)
                    .editorRow()
            }

            createRow
                .editorRow()
        } header: {
            Text("Add exercises")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.groveTextSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.top, 8)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(Color.groveTextSecondary)
            TextField("Search exercises", text: $searchText)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.groveTextSecondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .background(Color.groveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(searchFocused ? Color.groveSage.opacity(0.5) : Color.groveSage.opacity(0.15), lineWidth: 1)
        )
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filterOptions, id: \.self) { option in
                    let isSelected = effectiveFilter == option
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { filter = option }
                    } label: {
                        Text(title(for: option))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : Color.groveText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.groveSage : Color.groveCardBackground)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(isSelected ? Color.clear : Color.groveSage.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func title(for option: LibraryFilter) -> String {
        switch option {
        case .forDay: "For \(currentDayLabel)"
        case .all: "All"
        case .group(let group): group.rawValue
        }
    }

    private func libraryRow(_ exercise: Exercise) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { add(exercise) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundStyle(Color.groveSage)

                exerciseLabel(exercise)

                Spacer(minLength: 8)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(exercise.name)")
    }

    private var createRow: some View {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return Button {
            showingCreateExercise = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.groveSage)
                Text(query.isEmpty ? "Create a new exercise" : "Create \"\(query)\"")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.groveSage)
                Spacer()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Name plus what it works, e.g. "Chest · Upper" rather than a bare "Upper".
    private func exerciseLabel(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name)
                .font(.subheadline)
                .foregroundStyle(Color.groveText)

            Text([exercise.muscleGroup.rawValue, exercise.muscleSubgroup]
                .compactMap { $0 }
                .joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(Color.groveTextSecondary)
        }
    }

    // MARK: - Plan Summary

    private var planSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .font(.caption)
                    .foregroundStyle(Color.groveSage)
                Text("Your Plan")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.groveTextSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
            }

            VStack(spacing: 0) {
                ForEach(Array(dayLabels.enumerated()), id: \.offset) { index, label in
                    let count = (state.dayExerciseSelections[index] ?? []).count
                    HStack {
                        Text("Day \(index + 1)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.groveTextSecondary)
                            .frame(width: 40, alignment: .leading)

                        Text(label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedDayIndex == index ? Color.groveSage : Color.groveText)

                        Spacer()

                        Text(count == 0 ? "No exercises yet" : "\(count) exercises · ~\(count * 10) min")
                            .font(.caption2)
                            .foregroundStyle(count == 0 ? Color.groveTerracotta : Color.groveTextSecondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        selectedDayIndex == index
                            ? Color.groveSage.opacity(0.06)
                            : (index % 2 == 0 ? Color.groveCardBackground.opacity(0.4) : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selectDay(index) }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.groveSage.opacity(0.12), lineWidth: 1)
            )
        }
    }

    // MARK: - Actions

    private func selectDay(_ index: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedDayIndex = index
            searchText = ""
            filter = .forDay
            searchFocused = false
        }
    }

    private func add(_ exercise: Exercise) {
        var list = currentDayExercises
        guard !list.contains(where: { $0.id == exercise.id }) else { return }
        list.append(exercise)
        state.dayExerciseSelections[selectedDayIndex] = list
    }

    private func remove(_ exercise: Exercise) {
        var list = currentDayExercises
        list.removeAll { $0.id == exercise.id }
        state.dayExerciseSelections[selectedDayIndex] = list
    }
}

private extension View {
    /// Plain, edge-inset rows on the cream background (no list chrome).
    func editorRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
