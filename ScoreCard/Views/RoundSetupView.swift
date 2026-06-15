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
    @State private var golfCourseAPIKey = UserDefaults.standard.string(forKey: GolfCourseAPIService.apiKeyStorageKey) ?? ""
    @State private var isLoadingCourseDetails = false
    @State private var courseLookupMessage: String?

    // Player entry
    @State private var players: [DraftPlayer] = []
    @State private var showAddPlayer = false
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

            Section {
                SecureField("API Key", text: $golfCourseAPIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: golfCourseAPIKey) { _, newValue in
                        UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: GolfCourseAPIService.apiKeyStorageKey)
                    }
                if isLoadingCourseDetails {
                    Label("Loading course details...", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let courseLookupMessage {
                    Text(courseLookupMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("GolfCourseAPI")
            } footer: {
                Text("Optional. Add a free GolfCourseAPI key to auto-fill rating, slope, par, and hole stroke indexes after selecting a nearby course.")
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
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).font(.headline)
                            Text("Hdcp \(p.handicapIndex, specifier: "%.1f")  •  \(p.teeColor)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if format.requiresTeams, let t = p.teamNumber {
                            Text("Team \(t)")
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(t == 1 ? Color.blue.opacity(0.15) : Color.red.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
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
                    Text("Assign players to Team 1 or Team 2.")
                }
            }

            if players.count >= format.minimumPlayers {
                Section {
                    Button("Next: Review") { step = 2 }
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .sheet(isPresented: $showAddPlayer) {
            AddPlayerSheet(players: $players, format: format)
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
                        Text(p.name)
                        Spacer()
                        Text("CH: \(Player.computeCourseHandicap(index: p.handicapIndex, slope: slopeRating, rating: courseRating, par: par))")
                            .foregroundStyle(.secondary)
                    }
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

        if let cached = CourseCache.shared.find(name: result.name) {
            courseRating = cached.courseRating
            slopeRating = cached.slopeRating
            par = cached.par
            courseHoles = cached.holes
            courseLookupMessage = cached.holes?.isEmpty == false ? "Loaded cached scorecard details." : "Loaded cached course details."
        } else {
            courseRating = 72.0
            slopeRating = 113
            par = holes == 9 ? 36 : 72
            courseHoles = nil
        }

        let key = golfCourseAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            if courseLookupMessage == nil {
                courseLookupMessage = "Add a GolfCourseAPI key to auto-fill course details."
            }
            return
        }

        Task { await loadCourseDetails(for: result.name, apiKey: key) }
    }

    private func loadCourseDetails(for query: String, apiKey: String) async {
        isLoadingCourseDetails = true
        defer { isLoadingCourseDetails = false }

        do {
            let service = GolfCourseAPIService(apiKey: apiKey)
            guard let details = try await service.findCourseDetails(matching: query),
                  let tee = details.bestTee else {
                courseLookupMessage = "No API scorecard match found. Manual values are still editable."
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

// MARK: - Add Player Sheet

struct AddPlayerSheet: View {
    @Binding var players: [DraftPlayer]
    let format: GameFormat
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var handicapIndex = 1
    @State private var teeColor = "White"
    @State private var teamNumber = 1

    let teeColors = ["White", "Blue", "Gold", "Red", "Black"]

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
                    Picker("Tee Color", selection: $teeColor) {
                        ForEach(teeColors, id: \.self) { Text($0) }
                    }
                }

                if format.requiresTeams {
                    Section("Team") {
                        Picker("Team", selection: $teamNumber) {
                            Text("Team 1").tag(1)
                            Text("Team 2").tag(2)
                        }
                        .pickerStyle(.segmented)
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
                            teeColor: teeColor,
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
