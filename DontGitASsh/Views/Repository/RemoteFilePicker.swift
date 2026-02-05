import SwiftUI

/// Represents a remote directory entry
struct RemoteDirectoryEntry: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let isGitRepository: Bool
}

/// View model for browsing remote directories
@MainActor
class RemoteFilePickerViewModel: ObservableObject {
    let connection: Connection
    private let sshConnection: SSHConnection

    @Published var currentPath: String = ""
    @Published var entries: [RemoteDirectoryEntry] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedPath: String?

    init(connection: Connection) {
        self.connection = connection
        self.sshConnection = connection.createSSHConnection()
    }

    func loadInitialDirectory() async {
        isLoading = true
        error = nil

        do {
            // Get home directory
            let result = try await sshConnection.execute("echo $HOME")
            let homePath = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            currentPath = homePath
            await loadDirectory(homePath)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadDirectory(_ path: String) async {
        isLoading = true
        error = nil

        // Normalize path (remove trailing slash except for root, ensure leading slash)
        let normalizedPath: String
        if path == "/" {
            normalizedPath = "/"
        } else {
            let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            normalizedPath = trimmed.isEmpty ? "/" : "/\(trimmed)"
        }
        currentPath = normalizedPath

        do {
            // List all entries and check which are directories (including symlinks to directories)
            // Only check for .git directory (faster than running git command on each)
            let listCommand = """
            find \(normalizedPath.shellEscaped) -maxdepth 1 -mindepth 1 2>/dev/null | while IFS= read -r fullpath; do
                name=$(basename "$fullpath")
                if [ -d "$fullpath" ]; then
                    # Check if it's a git repo
                    if [ -d "$fullpath/.git" ]; then
                        echo "git:$name"
                    else
                        echo "dir:$name"
                    fi
                elif [ -f "$fullpath" ]; then
                    echo "file:$name"
                fi
            done
            """

            let result = try await sshConnection.execute(listCommand)

            var newEntries: [RemoteDirectoryEntry] = []

            let lines = result.output.split(separator: "\n")
            for line in lines {
                let lineStr = String(line)
                if lineStr.hasPrefix("git:") {
                    let name = String(lineStr.dropFirst(4))
                    if !name.isEmpty && name != "." && name != ".." {
                        let entryPath = normalizedPath == "/" ? "/\(name)" : "\(normalizedPath)/\(name)"
                        newEntries.append(RemoteDirectoryEntry(
                            name: name,
                            path: entryPath,
                            isDirectory: true,
                            isGitRepository: true
                        ))
                    }
                } else if lineStr.hasPrefix("dir:") {
                    let name = String(lineStr.dropFirst(4))
                    if !name.isEmpty && name != "." && name != ".." {
                        let entryPath = normalizedPath == "/" ? "/\(name)" : "\(normalizedPath)/\(name)"
                        newEntries.append(RemoteDirectoryEntry(
                            name: name,
                            path: entryPath,
                            isDirectory: true,
                            isGitRepository: false
                        ))
                    }
                } else if lineStr.hasPrefix("file:") {
                    let name = String(lineStr.dropFirst(5))
                    if !name.isEmpty && name != "." && name != ".." {
                        let entryPath = normalizedPath == "/" ? "/\(name)" : "\(normalizedPath)/\(name)"
                        newEntries.append(RemoteDirectoryEntry(
                            name: name,
                            path: entryPath,
                            isDirectory: false,
                            isGitRepository: false
                        ))
                    }
                }
            }

            // Sort: directories first, then files. Within each group: hidden first, then alphabetically
            entries = newEntries.sorted { a, b in
                // Directories come before files
                if a.isDirectory != b.isDirectory {
                    return a.isDirectory
                }
                // Within same type: hidden items first
                let aHidden = a.name.hasPrefix(".")
                let bHidden = b.name.hasPrefix(".")
                if aHidden != bHidden {
                    return aHidden
                }
                // Alphabetically within same group
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        } catch {
            self.error = error.localizedDescription
            entries = []
        }

        isLoading = false
    }

    func navigateUp() async {
        let parentPath = (currentPath as NSString).deletingLastPathComponent
        if !parentPath.isEmpty && parentPath != currentPath {
            await loadDirectory(parentPath)
        }
    }

    func selectEntry(_ entry: RemoteDirectoryEntry) async {
        if entry.isGitRepository {
            selectedPath = entry.path
        } else if entry.isDirectory {
            await loadDirectory(entry.path)
        }
        // Files: do nothing
    }

    /// Check if a specific path is a git repository
    func checkIfGitRepository(_ path: String) async -> Bool {
        do {
            let result = try await sshConnection.execute("git -C \(path.shellEscaped) rev-parse --git-dir 2>/dev/null && echo 'is-git'")
            return result.output.contains("is-git")
        } catch {
            return false
        }
    }
}

/// A picker view for selecting a git repository directory from a remote server
struct RemoteFilePicker: View {
    @StateObject private var viewModel: RemoteFilePickerViewModel
    @Environment(\.dismiss) private var dismiss

    let connection: Connection
    let onSelect: (String) -> Void

    init(connection: Connection, onSelect: @escaping (String) -> Void) {
        self.connection = connection
        self.onSelect = onSelect
        self._viewModel = StateObject(wrappedValue: RemoteFilePickerViewModel(connection: connection))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with path and navigation
            HStack {
                Button {
                    Task {
                        await viewModel.navigateUp()
                    }
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(viewModel.currentPath == "/" || viewModel.isLoading)

                Text(viewModel.currentPath)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.head)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Directory listing
            if let error = viewModel.error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await viewModel.loadDirectory(viewModel.currentPath)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.entries.isEmpty && !viewModel.isLoading {
                VStack {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No directories found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.entries, selection: $viewModel.selectedPath) { entry in
                    DirectoryEntryRow(entry: entry)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            Task {
                                await viewModel.selectEntry(entry)
                            }
                        }
                        .onTapGesture(count: 1) {
                            if entry.isGitRepository {
                                viewModel.selectedPath = entry.path
                            }
                        }
                }
                .listStyle(.inset)
            }

            Divider()

            // Footer with selection and buttons
            HStack {
                if let selected = viewModel.selectedPath {
                    Label(URL(fileURLWithPath: selected).lastPathComponent, systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .lineLimit(1)
                } else {
                    Text("Select a git repository")
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Select") {
                    if let path = viewModel.selectedPath {
                        onSelect(path)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.selectedPath == nil)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .task {
            await viewModel.loadInitialDirectory()
        }
    }
}

struct DirectoryEntryRow: View {
    let entry: RemoteDirectoryEntry

    var iconName: String {
        if entry.isGitRepository {
            return "arrow.triangle.branch"
        } else if entry.isDirectory {
            return "folder"
        } else {
            return "doc"
        }
    }

    var iconColor: Color {
        if entry.isGitRepository {
            return .orange
        } else if entry.isDirectory {
            return .blue
        } else {
            return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .frame(width: 20)

            Text(entry.name)
                .lineLimit(1)
                .foregroundColor(entry.isDirectory ? .primary : .secondary)

            Spacer()

            if entry.isGitRepository {
                Text("Git Repository")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
            } else if entry.isDirectory {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RemoteFilePicker(
        connection: Connection(name: "Test", host: "localhost")
    ) { path in
        print("Selected: \(path)")
    }
}
