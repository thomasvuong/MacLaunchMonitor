import SwiftUI

// FIX: Identifiable model for plist modal
struct PlistModal: Identifiable {
    let id: String        // use label as stable unique ID
    let label: String
    let text: String

    init(label: String, text: String) {
        self.label = label
        self.text = text
        self.id = label
    }
}

struct ContentView: View {
    @EnvironmentObject var controller: MonitorController
    @State private var showingScanner = false
    @State private var availableLabels: [String] = []
    @State private var selectedLabelForAdd: String? = nil

    // FIX: use Identifiable struct instead of tuple
    @State private var showPlistModal: PlistModal? = nil

    @State private var editNameFor: UUID? = nil
    @State private var newEditName: String = ""
    @State private var showEditSheet = false
    @State private var sortByDateAdded = true // true = newest first, false = oldest first
    
    var sortedMonitored: [MonitorController.MonitoredItem] {
        if sortByDateAdded {
            return controller.monitored.sorted { $0.dateAdded > $1.dateAdded }
        } else {
            return controller.monitored.sorted { $0.dateAdded < $1.dateAdded }
        }
    }

    var body: some View {
        ZStack {
            // background panel subtle
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.windowBackgroundColor))
                .opacity(0.95)
                .shadow(radius: 4)

            VStack(spacing: 6) {

                // header - just the add button
                HStack {
                    Button(action: { sortByDateAdded.toggle() }) {
                        Image(systemName: sortByDateAdded ? "arrow.down.circle" : "arrow.up.circle")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help(sortByDateAdded ? "Sorted: Newest first" : "Sorted: Oldest first")
                    .padding(.leading, 8)
                    
                    Spacer()
                    
                    Button(action: { showingScanner.toggle() }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.trailing, 8)
                    .padding(.top, 4)
                }

                Divider()

                // list of icons (vertical)
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(sortedMonitored) { item in
                            VStack(spacing: 2) {

                                // ICON BUTTON
                                Button(action: {
                                    withAnimation {
                                        controller.expandedLabel =
                                            (controller.expandedLabel == item.label)
                                            ? nil
                                            : item.label
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .frame(width: 14, height: 14)
                                            .foregroundColor(colorFor(label: item.label))
                                        Text(item.displayName)
                                            .font(.system(size: 10, weight: .medium))
                                            .lineLimit(1)
                                            .frame(maxWidth: 200, alignment: .leading)
                                    }
                                    .frame(minWidth: 60, maxWidth: 260, minHeight: 32)
                                    .padding(.horizontal, 8)
                                }
                                .buttonStyle(PlainButtonStyle())

                                // EXPANDED PANEL
                                if controller.expandedLabel == item.label {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(item.displayName)
                                                .font(.system(size: 12, weight: .semibold))
                                            Spacer()
                                            Button("Edit") {
                                                editNameFor = item.id
                                                newEditName = item.displayName
                                                showEditSheet = true
                                            }
                                            .font(.system(size: 10))
                                            .buttonStyle(BorderlessButtonStyle())
                                        }

                                        Text("Label: \(item.label)")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)

                                        // Control buttons
                                        VStack(spacing: 4) {
                                            HStack(spacing: 4) {
                                                Button("Load & Start") {
                                                    controller.start(label: item.label)
                                                }
                                                .help("Load and start this service")
                                                .buttonStyle(.borderedProminent)
                                                .controlSize(.small)
                                                .tint(.green)
                                                .font(.system(size: 9))
                                                .frame(maxWidth: .infinity)
                                                
                                                Button("Stop & Unload") {
                                                    controller.stop(label: item.label)
                                                }
                                                .help("Stop and unload this service")
                                                .buttonStyle(.borderedProminent)
                                                .controlSize(.small)
                                                .tint(.red)
                                                .font(.system(size: 9))
                                                .frame(maxWidth: .infinity)
                                            }
                                            
                                            HStack(spacing: 4) {
                                                Button("Restart") {
                                                    controller.restart(label: item.label)
                                                }
                                                .help("Restart this service (stop then start)")
                                                .buttonStyle(.borderedProminent)
                                                .controlSize(.small)
                                                .tint(.orange)
                                                .font(.system(size: 9))
                                                .frame(maxWidth: .infinity)
                                                
                                                Button("Remove") {
                                                    controller.removeMonitored(id: item.id)
                                                    controller.expandedLabel = nil
                                                }
                                                .help("Remove from monitoring list")
                                                .buttonStyle(.borderedProminent)
                                                .controlSize(.small)
                                                .tint(.gray)
                                                .font(.system(size: 9))
                                                .frame(maxWidth: .infinity)
                                            }
                                            
                                            HStack(spacing: 4) {
                                                Button("View (V)") {
                                                    let text = controller.readPlistContents(for: item.label)
                                                    showPlistModal = PlistModal(label: item.label, text: text)
                                                }
                                                .help("View plist file contents")
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                                .font(.system(size: 9))
                                                .frame(maxWidth: .infinity)
                                                
                                                Button("Reveal (R)") {
                                                    controller.revealPlistInFinder(for: item.label)
                                                }
                                                .help("Reveal plist file in Finder")
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                                .font(.system(size: 9))
                                                .frame(maxWidth: .infinity)
                                            }
                                        }
                                    }
                                    .padding(8)
                                    .background(
                                        Color(NSColor.controlBackgroundColor)
                                            .opacity(0.6)
                                    )
                                    .cornerRadius(8)
                                    .frame(maxWidth: 260)
                                }

                            }
                            .contextMenu {
                                Button("Remove") {
                                    controller.removeMonitored(id: item.id)
                                }
                            }
                            .padding(.bottom, 4)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Spacer()

                // legend - comprehensive explanation
                VStack(spacing: 3) {
                    Text("Legend")
                        .font(.system(size: 9, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                    
                    Text("Status Icons:")
                        .font(.system(size: 8, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 4) {
                        Circle().frame(width: 8, height: 8).foregroundColor(.green)
                        Text("Running").font(.system(size: 7)).lineLimit(1)
                        Spacer()
                    }
                    
                    HStack(spacing: 4) {
                        Circle().frame(width: 8, height: 8).foregroundColor(.red)
                        Text("Stopped").font(.system(size: 7)).lineLimit(1)
                        Spacer()
                    }
                    
                    HStack(spacing: 4) {
                        Circle().frame(width: 8, height: 8).foregroundColor(.gray)
                        Text("Not loaded").font(.system(size: 7)).lineLimit(1)
                        Spacer()
                    }
                    
                    Divider()
                    
                    Text("Buttons:")
                        .font(.system(size: 8, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.green).frame(width: 8, height: 6)
                        Text("Load & Start").font(.system(size: 7)).lineLimit(1)
                        Spacer()
                    }
                    
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.red).frame(width: 8, height: 6)
                        Text("Stop & Unload").font(.system(size: 7)).lineLimit(1)
                        Spacer()
                    }
                    
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.orange).frame(width: 8, height: 6)
                        Text("Restart").font(.system(size: 7)).lineLimit(1)
                        Spacer()
                    }
                    
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.gray).frame(width: 8, height: 6)
                        Text("Remove").font(.system(size: 7)).lineLimit(1)
                        Spacer()
                    }
                    
                    HStack(spacing: 4) {
                        Text("V").font(.system(size: 7, weight: .bold)).frame(width: 8)
                        Text("View content").font(.system(size: 7)).lineLimit(1)
                        Spacer()
                    }
                    
                    HStack(spacing: 4) {
                        Text("R").font(.system(size: 7, weight: .bold)).frame(width: 8)
                        Text("Reveal in Finder").font(.system(size: 7)).lineLimit(1)
                        Spacer()
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .padding(6)
        }
        .sheet(isPresented: $showingScanner, onDismiss: {
            controller.refreshStatuses()
        }, content: {
            ScannerView { selected, name in
                if let selected = selected {
                    controller.addMonitored(label: selected,
                                            displayName: name ?? selected)
                }
                showingScanner = false
            }
        })
        .frame(minWidth: 80, maxWidth: 320, minHeight: 120, maxHeight: 900)
        .onAppear { controller.refreshStatuses() }

        // FIXED — now works with Identifiable model
        .popover(item: $showPlistModal) { item in
            PlistView(label: item.label, text: item.text)
                .frame(width: 600, height: 400)
        }

        // edit name sheet
        .sheet(isPresented: $showEditSheet) {
            VStack(spacing: 16) {
                Text("Edit Display Name")
                    .font(.headline)
                    .padding(.top)
                
                TextField("Display Name", text: $newEditName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 300)
                    .padding(.horizontal)
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showEditSheet = false
                        editNameFor = nil
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button("Save") {
                        if let id = editNameFor {
                            controller.updateDisplayName(id: id, newName: newEditName)
                        }
                        showEditSheet = false
                        editNameFor = nil
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.bottom)
            }
            .frame(width: 350, height: 150)
        }
    }

    // status color mapping
    func colorFor(label: String) -> Color {
        let status = controller.statuses[label] ?? "NOT LOADED"
        if status.contains("RUNNING") { return .green }
        if status.contains("STOPPED") { return .red }
        return .gray
    }
}

// MARK: - Scanner sheet
struct ScannerView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var allLabels: [String] = []
    @State private var selectedLabel: String? = nil
    @State private var customName: String = ""
    @State private var serviceDetails: [String: String] = [:] // label -> description
    @State private var searchText: String = ""
    @State private var sortOrder: SortOrder = .alphabetical
    var completion: (String?, String?) -> Void
    
    enum SortOrder: String, CaseIterable {
        case alphabetical = "A-Z"
        case reverseAlphabetical = "Z-A"
        case dateNewest = "Newest"
        case dateOldest = "Oldest"
    }
    
    var filteredAndSortedLabels: [String] {
        var filtered = allLabels
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { label in
                label.localizedCaseInsensitiveContains(searchText) ||
                (serviceDetails[label]?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply sorting
        switch sortOrder {
        case .alphabetical:
            return filtered.sorted()
        case .reverseAlphabetical:
            return filtered.sorted().reversed()
        case .dateNewest, .dateOldest:
            // Sort by plist modification date (more relevant than creation)
            return filtered.sorted { label1, label2 in
                let info1 = getPlistInfo(for: label1)
                let info2 = getPlistInfo(for: label2)
                
                // Prioritize user LaunchAgents over system
                if info1.isUserAgent != info2.isUserAgent {
                    return sortOrder == .dateNewest ? info1.isUserAgent : info2.isUserAgent
                }
                
                // Then sort by date
                let date1 = info1.date ?? Date.distantPast
                let date2 = info2.date ?? Date.distantPast
                return sortOrder == .dateNewest ? date1 > date2 : date1 < date2
            }
        }
    }
    
    func getPlistInfo(for label: String) -> (date: Date?, isUserAgent: Bool) {
        let userPath = "\(NSHomeDirectory())/Library/LaunchAgents"
        let paths = [
            userPath,
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
            "/System/Library/LaunchAgents",
            "/System/Library/LaunchDaemons"
        ]
        
        for base in paths {
            let fileGuess = "\(base)/\(label).plist"
            if FileManager.default.fileExists(atPath: fileGuess),
               let attrs = try? FileManager.default.attributesOfItem(atPath: fileGuess) {
                // Use modification date as it's more relevant for recent changes
                let date = (attrs[.modificationDate] as? Date) ?? (attrs[.creationDate] as? Date)
                let isUserAgent = base == userPath
                return (date, isUserAgent)
            }
        }
        return (nil, false)
    }

    var body: some View {
        VStack {
            HStack {
                Text("Select a service to add").font(.headline)
                Spacer()
                Button("Close") { presentationMode.wrappedValue.dismiss() }
            }
            .padding()

            // Search and sort controls
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search services...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sort by:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .labelsHidden()
                }
            }
            .padding(.horizontal)

            List(filteredAndSortedLabels, id: \.self, selection: $selectedLabel) { lbl in
                VStack(alignment:.leading, spacing: 2) {
                    Text(lbl)
                        .font(.system(size:12, weight: .medium))
                    if let details = serviceDetails[lbl], !details.isEmpty {
                        Text(details)
                            .font(.system(size:10))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .onTapGesture {
                    selectedLabel = lbl
                    customName = lbl
                }
            }
            .onAppear(perform: loadLabels)
            .frame(minWidth: 600, minHeight: 400)

            HStack {
                TextField("Friendly name", text: $customName)
                    .frame(minWidth: 300)
                Spacer()

                Button("Add") {
                    completion(selectedLabel,
                               customName.isEmpty ? selectedLabel : customName)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(selectedLabel == nil)
            }
            .padding()
        }
    }

    func loadLabels() {
        DispatchQueue.global(qos: .userInitiated).async {
            // Use launchctl list and parse the output
            let out = shell("launchctl list")
            print("DEBUG: Shell output length: \(out.count)")
            print("DEBUG: First 500 chars: \(String(out.prefix(500)))")
            
            let lines = out.split(separator: "\n")
                .dropFirst() // skip header line
                .compactMap { line -> String? in
                    // Split by any whitespace and get last component (the label)
                    let parts = line.split(whereSeparator: \.isWhitespace)
                    guard parts.count >= 3 else { return nil }
                    let label = String(parts.last!)
                    return label == "-" ? nil : label
                }
                .filter { !$0.isEmpty }

            print("DEBUG: Parsed \(lines.count) labels")
            if lines.count > 0 {
                print("DEBUG: First 5 labels: \(lines.prefix(5))")
            }
            
            // Load descriptions for each service
            var details: [String: String] = [:]
            for label in lines {
                if let desc = self.getServiceDescription(label: label) {
                    details[label] = desc
                }
            }
            
            DispatchQueue.main.async {
                allLabels = lines
                serviceDetails = details
                print("DEBUG: Updated allLabels with \(lines.count) items")
            }
        }
    }
    
    func getServiceDescription(label: String) -> String? {
        // Find plist and extract Label or ProgramArguments for description
        let paths = [
            "\(NSHomeDirectory())/Library/LaunchAgents",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
            "/System/Library/LaunchAgents",
            "/System/Library/LaunchDaemons"
        ]
        
        for base in paths {
            // Try direct filename match first (faster)
            let fileGuess = "\(base)/\(label).plist"
            if FileManager.default.fileExists(atPath: fileGuess) {
                return extractDescription(from: fileGuess)
            }
        }
        
        return nil
    }
    
    func extractDescription(from plistPath: String) -> String? {
        // Read the plist and extract meaningful info
        let cmd = "plutil -p '\(plistPath)' 2>/dev/null"
        let result = shell(cmd)
        
        // Look for Program or ProgramArguments
        var program: String? = nil
        
        // Try to extract Program key
        if let programMatch = result.range(of: #""Program" => "([^"]+)""#, options: .regularExpression) {
            program = String(result[programMatch]).replacingOccurrences(of: #""Program" => ""#, with: "").replacingOccurrences(of: "\"", with: "")
        }
        
        // If no Program, try ProgramArguments (get first element)
        if program == nil {
            let lines = result.split(separator: "\n")
            var inProgramArgs = false
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.contains("\"ProgramArguments\"") {
                    inProgramArgs = true
                    continue
                }
                if inProgramArgs && trimmed.starts(with: "\"") {
                    // Extract the path from the first argument
                    program = trimmed.replacingOccurrences(of: "\"", with: "")
                    break
                }
                if inProgramArgs && trimmed.starts(with: ")") {
                    break
                }
            }
        }
        
        // Clean up and get just the executable name
        if let prog = program {
            let cleanPath = prog.replacingOccurrences(of: "0 => ", with: "")
            let components = cleanPath.split(separator: "/")
            if let execName = components.last {
                return String(execName)
            }
            return cleanPath
        }
        
        return nil
    }

    private func shell(_ command: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            print("DEBUG shell: command=\(command), exitCode=\(task.terminationStatus), output.count=\(output.count)")
            return output
        } catch {
            print("ERROR running shell command: \(error)")
            return ""
        }
    }
}

// MARK: - Plist viewer
struct PlistView: View {
    let label: String
    let text: String

    var body: some View {
        VStack {
            HStack {
                Text("Plist: \(label)").font(.headline)
                Spacer()
                Button("Close") { NSApp.keyWindow?.close() }
            }
            .padding()

            ScrollView {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .padding()
            }
        }
    }
}
