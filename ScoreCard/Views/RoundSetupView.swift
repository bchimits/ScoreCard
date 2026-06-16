import SwiftUI

struct RoundSetupView: View {
    @EnvironmentObject var vm: RoundViewModel
    @Environment(\.dismiss) var dismiss

    // Round info
    @State private var roundName = ""
    @State private var format: GameFormat = .strokePlay
    @State private var holes = 18
    @State private var courseName = ""
    @State private var courseRating = 72.0
    @State private var slopeRating = 113
    @State private var par = 72
    @State private var courseHoles: [Hole]?
    @State private var isLoadingCourseDetails = false
    @State private var courseLookupMessage: String?

    // Player entry
    @State private var players: [DraftPlayer] = []
    @State private var showAddPlayer = false
    @State private var editingPlayerID: UUID?
    @State private var showCoursePicker = false
    @StateObject private var courseSearch = CourseSearchService()

    @State private var step = 0  // 0 = round info, 1 = players, 2 = confirm

    var body: some View {
        NavigationStack {
            Group {
                if step == 0 { roundInfoStep }
                else if step == 1 { playersStep }
                else { confirmStep }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step == 0 {
                        Button("Cancel") { dismiss() }
                    } else {
                        Button("Back") { step -= 1 }
                    }
                }
            }
            .sheet(isPresented: $showCoursePicker) {
                CoursePickerSheet(
                    courseSearch: courseSearch,
                    onSelect: { result in
                        applySelectedCourse(result)
                        showCoursePicker = false
                    }
                )
            }
        }
    }

    private var stepTitle: String {
        ["Round Info", "Add Players", "Review & Start"][step]
    }

    // MARK: - Step 0: Round Info

    private var roundInfoStep: some View {
        Form {
            Section("Round") {
                TextField("Round Name (e.g. Saturday Game)", text: $roundName)
                Picker("Game Format", selection: $format) {
                    ForEach(GameFormat.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                Picker("Holes", selection: $holes) {
                    Text("9 Holes").tag(9)
                    Text("18 Holes").tag(18)
                }
                .pickerStyle(.segmented)
                .onChange(of: holes) { _, newValue in
                    if let courseHoles, !courseHoles.isEmpty {
                        par = courseHoles.prefix(newValue).reduce(0) { $0 + $1.par }
                    } else if par == 36 || par == 72 {
                        par = newValue == 9 ? 36 : 72
                    }
                }
            }

            Section("Format Description") {
                Text(format.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    showCoursePicker = true
                    Task { await courseSearch.findNearbyCourses() }
                } label: {
                    Label("Find Nearby Courses", systemImage: "location.fill")
                }

                if !courseName.isEmpty {
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(.green)
                        Text(courseName)
                            .font(.headline)
                    }
                }
            } header: {
                Text("Course")
            } footer: {
                Text("Tap to search by GPS, or fill in manually below.")
                    .font(.caption)
            }

            if isLoadingCourseDetails || courseLookupMessage != nil {
                Section("Course Data") {
                    if isLoadingCourseDetails {
                        Label("Loading course details...", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let courseLookupMessage {
                        Text(courseLookupMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Course Details") {
                TextField("Course Name", text: $courseName)
                HStack {
                    Text("Course Rating")
                    Spacer()
                    TextField("72.0", value: $courseRating, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                }
                HStack {
                    Text("Slope Rating")
                    Spacer()
                    TextField("113", value: $slopeRating, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                }
                HStack {
                    Text("Par")
                    Spacer()
                    TextField("72", value: $par, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                }
            }

            Section {
                Button("Next: Add Players") {
                    step = 1
                }
                .disabled(roundName.isEmpty || courseName.isEmpty)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Step 1: Players

    private var playersStep: some View {
        Form {
            Section {
                ForEach(players) { p in
                    Button {
                        editingPlayerID = p.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(.headline)
                                Text("Hdcp \(p.handicapIndex, specifier: "%.1f")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if format.requiresTeams, let teamNumber = p.teamNumber {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(TeamColorChoice.color(for: teamNumber))
                                        .frame(width: 8, height: 8)
                                    Text(TeamColorChoice.name(for: teamNumber))
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(TeamColorChoice.color(for: teamNumber).opacity(0.15))
                                .clipShape(Capsule())
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { players.remove(atOffsets: $0) }

                Button {
                    showAddPlayer = true
                } label: {
                    Label("Add Player", systemImage: "plus")
                }
            } header: {
                Text("Players (\(players.count))")
            } footer: {
                if format.requiresTeams {
                    Text("You can start the round now to get a join code, then assign team colors after everyone joins.")
                }
            }

            if canReviewRound {
                Section {
                    Button("Next: Review") { step = 2 }
                        .frame(maxWidth: .infinity)
                } footer: {
                    if format.requiresTeams && !hasValidTeamAssignments {
                        Text("Team colors can be completed later from the scoreboard after players join.")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddPlayer) {
            AddPlayerSheet(players: $players, format: format)
        }
        .sheet(isPresented: isEditingPlayer) {
            if let player = editingPlayerBinding {
                EditPlayerSheet(
                    player: player,
                    format: format,
                    onDelete: {
                        if let editingPlayerID {
                            players.removeAll { $0.id == editingPlayerID }
                        }
                        editingPlayerID = nil
                    }
                )
            }
        }
    }

    private var isEditingPlayer: Binding<Bool> {
        Binding(
            get: { editingPlayerBinding != nil },
            set: { isPresented in
                if !isPresented { editingPlayerID = nil }
            }
        )
    }

    private var editingPlayerBinding: Binding<DraftPlayer>? {
        guard let editingPlayerID,
              let index = players.firstIndex(where: { $0.id == editingPlayerID }) else { return nil }
        return $players[index]
    }

    private var canReviewRound: Bool {
        if format.requiresTeams {
            return !players.isEmpty
        }
        return players.count >= format.minimumPlayers
    }

    private var hasValidTeamAssignments: Bool {
        guard format.requiresTeams else { return true }
        let selectedTeams = Array(Set(players.compactMap(\.teamNumber)))
        return selectedTeams.count == 2 && selectedTeams.allSatisfy { teamNumber in
            players.filter { $0.teamNumber == teamNumber }.count == 2
        }
    }

    // MARK: - Step 2: Confirm

    private var confirmStep: some View {
        Form {
            Section("Round") {
                LabeledContent("Name", value: roundName)
                LabeledContent("Format", value: format.rawValue)
                LabeledContent("Holes", value: "\(holes)")
                LabeledContent("Course", value: courseName)
                LabeledContent("Rating / Slope", value: String(format: "%.1f / %d", courseRating, slopeRating))
            }

            Section("Players") {
                ForEach(players) { p in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name)
                            if format.requiresTeams, let teamNumber = p.teamNumber {
                                Label(TeamColorChoice.name(for: teamNumber), systemImage: "circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(TeamColorChoice.color(for: teamNumber))
                            }
                        }
                        Spacer()
                        Text("CH: \(Player.computeCourseHandicap(index: p.handicapIndex, slope: slopeRating, rating: courseRating, par: par))")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if format.requiresTeams && !hasValidTeamAssignments {
                Section("Teams") {
                    Label("Roster and team colors can be finished after players join with the code.", systemImage: "person.2.badge.gearshape")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Start Round") {
                    Task { await startRound() }
                }
                .disabled(vm.isLoading)
                .frame(maxWidth: .infinity)
                .foregroundStyle(.green)
                .fontWeight(.bold)
            }
        }
        .overlay {
            if vm.isLoading {
                ProgressView("Creating round…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Actions

    private func applySelectedCourse(_ result: CourseResult) {
        courseName = result.name
        courseLookupMessage = nil

        if let knownCourse = KnownCourseData.course(matching: result.name) {
            applyCourseDetails(knownCourse, selectedName: result.name)
            CourseCache.shared.save(knownCourse)
            courseLookupMessage = "Loaded Arrowood scorecard details from built-in data."
            return
        }

        if let cached = CourseCache.shared.find(name: result.name) {
            applyCourseDetails(cached, selectedName: result.name)
            courseLookupMessage = cached.holes?.isEmpty == false ? "Loaded cached scorecard details." : "Loaded cached course details."
        } else {
            courseRating = 72.0
            slopeRating = 113
            par = holes == 9 ? 36 : 72
            courseHoles = nil
        }

        Task { await loadCourseDetails(for: result.name) }
    }

    private func applyCourseDetails(_ course: CachedCourse, selectedName: String? = nil) {
        courseName = selectedName ?? course.name
        courseRating = course.courseRating
        slopeRating = course.slopeRating
        courseHoles = course.holes.map { Array($0.prefix(holes)) }
        par = courseHoles?.reduce(0) { $0 + $1.par } ?? course.par
    }

    private func loadCourseDetails(for query: String) async {
        isLoadingCourseDetails = true
        defer { isLoadingCourseDetails = false }

        do {
            let service = GolfCourseAPIService()
            guard let details = try await service.findCourseDetails(matching: query),
                  let tee = details.bestTee else {
                if let knownCourse = KnownCourseData.course(matching: query) {
                    applyCourseDetails(knownCourse)
                    CourseCache.shared.save(knownCourse)
                    courseLookupMessage = "Loaded Arrowood scorecard details from built-in data."
                } else {
                    courseLookupMessage = "No API scorecard match found. Manual values are still editable."
                }
                return
            }

            let fetchedHoles = tee.scorecardHoles
            let selectedHoles = fetchedHoles.isEmpty ? nil : Array(fetchedHoles.prefix(holes))
            courseName = details.displayName
            courseRating = tee.courseRating ?? courseRating
            slopeRating = tee.slopeRating ?? slopeRating
            courseHoles = selectedHoles
            par = selectedHoles?.reduce(0) { $0 + $1.par } ?? tee.parTotal ?? par

            CourseCache.shared.save(CachedCourse(
                name: query,
                courseRating: courseRating,
                slopeRating: slopeRating,
                par: par,
                holes: courseHoles
            ))

            let teeDescription = tee.teeName.map { " from \($0) tees" } ?? ""
            courseLookupMessage = "Auto-filled rating, slope, par, and holes\(teeDescription)."
        } catch {
            courseLookupMessage = error.localizedDescription
        }
    }

    private func startRound() async {
        // Persist course details so they auto-fill next time
        if !courseName.isEmpty {
            CourseCache.shared.save(CachedCourse(
                name: courseName,
                courseRating: courseRating,
                slopeRating: slopeRating,
                par: par,
                holes: courseHoles
            ))
        }

        await vm.createRound(
            name: roundName,
            format: format,
            holes: holes,
            courseName: courseName,
            courseRating: courseRating,
            slopeRating: slopeRating,
            par: par,
            courseHoles: courseHoles
        )
        guard vm.round != nil else { return }

        // Build Player models from drafts
        for draft in players {
            vm.addPlayer(
                name: draft.name,
                handicapIndex: draft.handicapIndex,
                teeColor: draft.teeColor,
                teamNumber: draft.teamNumber
            )
        }
        await vm.savePlayers()

        if vm.round != nil { dismiss() }
    }
}

// MARK: - Draft Player (local only during setup)

struct DraftPlayer: Identifiable {
    let id = UUID()
    var name: String
    var handicapIndex: Double
    var teeColor: String
    var teamNumber: Int?
}

// MARK: - Team Colors

struct TeamColorChoice: Identifiable {
    let id: Int
    let name: String
    let color: Color

    static let all: [TeamColorChoice] = [
        TeamColorChoice(id: 1, name: "Red", color: .red),
        TeamColorChoice(id: 2, name: "Blue", color: .blue),
        TeamColorChoice(id: 3, name: "Green", color: .green),
        TeamColorChoice(id: 4, name: "Yellow", color: .yellow),
        TeamColorChoice(id: 5, name: "Purple", color: .purple)
    ]

    static func name(for id: Int) -> String {
        all.first { $0.id == id }?.name ?? "Team \(id)"
    }

    static func color(for id: Int) -> Color {
        all.first { $0.id == id }?.color ?? .secondary
    }
}

// MARK: - Add Player Sheet

struct AddPlayerSheet: View {
    @Binding var players: [DraftPlayer]
    let format: GameFormat
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var handicapIndex = 1
    @State private var teamNumber = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("Player Info") {
                    TextField("Name", text: $name)
                    Picker("Handicap Index", selection: $handicapIndex) {
                        ForEach(1...32, id: \.self) { i in
                            Text("\(i)").tag(i)
                        }
                    }
                }

                if format.requiresTeams {
                    Section("Team") {
                        Picker("Team Color", selection: $teamNumber) {
                            ForEach(TeamColorChoice.all) { choice in
                                Label {
                                    Text(choice.name)
                                } icon: {
                                    Image(systemName: "circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(choice.color)
                                }
                                .tag(choice.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            .navigationTitle("Add Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        players.append(DraftPlayer(
                            name: name,
                            handicapIndex: Double(handicapIndex),
                            teeColor: "White",
                            teamNumber: format.requiresTeams ? teamNumber : nil
                        ))
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Player Sheet

struct EditPlayerSheet: View {
    @Binding var player: DraftPlayer
    let format: GameFormat
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var handicapIndex: Double
    @State private var teamNumber: Int

    init(player: Binding<DraftPlayer>, format: GameFormat, onDelete: @escaping () -> Void) {
        self._player = player
        self.format = format
        self.onDelete = onDelete
        self._name = State(initialValue: player.wrappedValue.name)
        self._handicapIndex = State(initialValue: player.wrappedValue.handicapIndex)
        self._teamNumber = State(initialValue: player.wrappedValue.teamNumber ?? 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Player Info") {
                    TextField("Name", text: $name)
                    HStack {
                        Text("Handicap Index")
                        Spacer()
                        TextField("0.0", value: $handicapIndex, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                    }
                }

                if format.requiresTeams {
                    Section("Team") {
                        Picker("Team Color", selection: $teamNumber) {
                            ForEach(TeamColorChoice.all) { choice in
                                Label {
                                    Text(choice.name)
                                } icon: {
                                    Image(systemName: "circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(choice.color)
                                }
                                .tag(choice.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section {
                    Button("Delete Player", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Edit Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        player.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        player.handicapIndex = handicapIndex
                        player.teamNumber = format.requiresTeams ? teamNumber : nil
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Course Picker Sheet

struct CoursePickerSheet: View {
    @ObservedObject var courseSearch: CourseSearchService
    let onSelect: (CourseResult) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if courseSearch.isSearching {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Finding nearby courses…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = courseSearch.locationError {
                    VStack(spacing: 16) {
                        Image(systemName: "location.slash.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if courseSearch.nearbyCourses.isEmpty {
                    ContentUnavailableView(
                        "No Courses Found",
                        systemImage: "flag.slash",
                        description: Text("No golf courses were found nearby. Enter the course details manually.")
                    )
                } else {
                    List(courseSearch.nearbyCourses) { result in
                        let cached = CourseCache.shared.find(name: result.name)
                        Button {
                            onSelect(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(result.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    if cached != nil {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                    }
                                }
                                if !result.address.isEmpty {
                                    Text(result.address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let c = cached {
                                    Text("Rating \(c.courseRating, specifier: "%.1f")  •  Slope \(c.slopeRating)  •  Par \(c.par)")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .badge(result.distanceString)
                    }
                }
            }
            .navigationTitle("Nearby Courses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await courseSearch.findNearbyCourses() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(courseSearch.isSearching)
                }
            }
        }
    }
}
