import Foundation
import SwiftUI

/// View model for a connected repository
@MainActor
class RepositoryViewModel: ObservableObject {
    @Published var connection: Connection

    @Published var state: RepositoryTabState = .connecting
    @Published var status: GitStatus?
    @Published var currentBranch: String?
    @Published var branches: [GitBranch] = []
    @Published var commits: [GitCommit] = []
    @Published var selectedFile: GitFileStatus?
    @Published var fileDiff: GitDiff?
    @Published var isLoading = false
    @Published var error: String?

    // Three-column navigation state
    @Published var selectedViewTab: RepositoryViewTab = .changes
    @Published var selectedCommit: GitCommit?
    @Published var selectedBranch: GitBranch?

    // Hunk selection state
    @Published var hunkSelections: [UUID: HunkSelection] = [:]

    // Drag selection state
    var dragStartLineKey: (hunkId: UUID, lineIndex: Int)?
    var dragSelectMode: Bool? // true = selecting, false = deselecting
    private var preDragSelections: [UUID: HunkSelection]?

    // Commit message
    @Published var commitMessage: String = ""

    private var sshConnection: SSHConnection?
    private var executor: RemoteExecutor?
    private var repository: GitRepository?

    init(connection: Connection) {
        self.connection = connection
    }

    /// The repository name derived from the path
    var repositoryName: String? {
        guard let path = connection.repositoryPath else { return nil }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    // MARK: - Connection

    func connect() async {
        state = .connecting
        error = nil

        let ssh = connection.createSSHConnection()
        self.sshConnection = ssh

        do {
            let connected = try await ssh.testConnection()
            guard connected else {
                state = .error("Failed to connect")
                return
            }

            // If no repository path is set, prompt user to select one
            guard let repoPath = connection.repositoryPath else {
                state = .selectingRepository
                return
            }

            await initializeRepository(path: repoPath)
        } catch {
            state = .error(error.localizedDescription)
            self.error = error.localizedDescription
        }
    }

    /// Set the repository path and initialize the repository
    func setRepositoryPath(_ path: String) async {
        connection = connection.withRepositoryPath(path)
        state = .connecting
        await initializeRepository(path: path)
    }

    private func initializeRepository(path: String) async {
        guard let ssh = sshConnection else {
            state = .error("SSH connection not available. Please reconnect.")
            return
        }

        do {
            let exec = RemoteExecutor(connection: ssh, workingDirectory: path)
            self.executor = exec

            let isRepo = try await exec.isGitRepository()
            guard isRepo else {
                state = .error("Not a git repository")
                return
            }

            let repo = GitRepository(executor: exec, path: path)
            self.repository = repo

            state = .connected
            await refresh()
        } catch {
            state = .error(error.localizedDescription)
            self.error = error.localizedDescription
        }
    }

    func disconnect() async {
        // Close the SSH master connection to clean up resources
        if let ssh = sshConnection {
            await ssh.disconnect()
        }
        sshConnection = nil
        executor = nil
        repository = nil
        state = .disconnected
    }

    // MARK: - Refresh

    /// Full refresh - fetches all repository state (use sparingly)
    func refresh() async {
        guard let repository = repository else { return }
        isLoading = true
        error = nil

        do {
            async let statusTask = repository.status()
            async let branchTask = repository.currentBranch()
            async let branchesTask = repository.branchesWithTracking()
            async let commitsTask = repository.log(maxCount: 100)

            let (newStatus, newBranch, newBranches, newCommits) = try await (
                statusTask,
                branchTask,
                branchesTask,
                commitsTask
            )

            self.status = newStatus
            self.currentBranch = newBranch
            self.branches = newBranches
            self.commits = newCommits

            // Refresh selected file diff if applicable
            if let file = selectedFile {
                await loadDiff(for: file)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Refresh only status - for staging/unstaging operations (1 SSH call)
    private func refreshStatus() async {
        guard let repository = repository else { return }

        do {
            self.status = try await repository.status()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Refresh status and reload diff for selected file (2 SSH calls)
    private func refreshStatusAndDiff() async {
        guard let repository = repository else { return }

        do {
            self.status = try await repository.status()

            // Re-select the file to update its staged/unstaged state and reload diff
            if let file = selectedFile,
               let updatedFile = status?.files.first(where: { $0.path == file.path }) {
                selectedFile = updatedFile
                await loadDiff(for: updatedFile)
            } else {
                // File no longer in status (fully staged or reverted)
                selectedFile = nil
                fileDiff = nil
                hunkSelections.removeAll()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Refresh after commit - status + commits (2 SSH calls)
    private func refreshAfterCommit() async {
        guard let repository = repository else { return }

        do {
            async let statusTask = repository.status()
            async let commitsTask = repository.log(maxCount: 100)

            let (newStatus, newCommits) = try await (statusTask, commitsTask)

            self.status = newStatus
            self.commits = newCommits

            // Clear selection since staged files are now committed
            selectedFile = nil
            fileDiff = nil
            hunkSelections.removeAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Refresh after branch operations - status + current branch + branches (3 SSH calls)
    private func refreshAfterBranchChange() async {
        guard let repository = repository else { return }

        do {
            async let statusTask = repository.status()
            async let branchTask = repository.currentBranch()
            async let branchesTask = repository.branchesWithTracking()

            let (newStatus, newBranch, newBranches) = try await (
                statusTask, branchTask, branchesTask
            )

            self.status = newStatus
            self.currentBranch = newBranch
            self.branches = newBranches

            // Clear file selection on branch change
            selectedFile = nil
            fileDiff = nil
            hunkSelections.removeAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Refresh only branches list (1 SSH call)
    private func refreshBranches() async {
        guard let repository = repository else { return }

        do {
            self.branches = try await repository.branchesWithTracking()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - File Selection and Diff

    func selectFile(_ file: GitFileStatus?) async {
        selectedFile = file
        hunkSelections.removeAll()

        if let file = file {
            await loadDiff(for: file)
        } else {
            fileDiff = nil
        }
    }

    private func loadDiff(for file: GitFileStatus) async {
        guard let repository = repository else { return }

        do {
            let diff: GitDiff
            if file.isStaged {
                diff = try await repository.diffStaged(file: file.path)
            } else {
                diff = try await repository.diff(file: file.path)
            }
            self.fileDiff = diff

            // Initialize hunk selections
            for fileDiff in diff.files {
                for hunk in fileDiff.hunks {
                    hunkSelections[hunk.id] = HunkSelection(hunk: hunk, fullySelected: false)
                }
            }
        } catch {
            self.error = error.localizedDescription
            self.fileDiff = nil
        }
    }

    // MARK: - Staging

    func stageFile(_ file: GitFileStatus) async {
        guard let repository = repository else { return }

        do {
            try await repository.stage(file: file.path)
            await refreshStatusAndDiff()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func unstageFile(_ file: GitFileStatus) async {
        guard let repository = repository else { return }

        do {
            try await repository.unstage(file: file.path)
            await refreshStatusAndDiff()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func stageAll() async {
        guard let repository = repository else { return }

        do {
            try await repository.stageAll()
            await refreshStatus()
            // Clear selection since all files moved to staged
            selectedFile = nil
            fileDiff = nil
            hunkSelections.removeAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func unstageAll() async {
        guard let repository = repository else { return }

        do {
            try await repository.unstageAll()
            await refreshStatus()
            // Clear selection since all files moved to unstaged
            selectedFile = nil
            fileDiff = nil
            hunkSelections.removeAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func stageSelectedHunks() async {
        guard let repository = repository,
              selectedFile != nil,
              let diff = fileDiff else { return }

        var patches: [String] = []

        for fileDiff in diff.files {
            for hunk in fileDiff.hunks {
                guard let selection = hunkSelections[hunk.id],
                      !selection.selectedLines.isEmpty else { continue }

                if selection.isFullySelected {
                    let patch = hunk.toPatch(filePath: fileDiff.displayPath, isNew: fileDiff.isNew, isDeleted: fileDiff.isDeleted)
                    patches.append(patch)
                } else if let patch = hunk.toSelectivePatch(filePath: fileDiff.displayPath, selectedLineIndices: selection.selectedLines, isNew: fileDiff.isNew, isDeleted: fileDiff.isDeleted) {
                    patches.append(patch)
                }
            }
        }

        guard !patches.isEmpty else { return }

        do {
            let fullPatch = patches.joined(separator: "\n")
            try await repository.stageHunks(patch: fullPatch)
            await refreshStatusAndDiff()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func unstageSelectedHunks() async {
        guard let repository = repository,
              selectedFile != nil,
              let diff = fileDiff else { return }

        var patches: [String] = []

        for fileDiff in diff.files {
            for hunk in fileDiff.hunks {
                guard let selection = hunkSelections[hunk.id],
                      !selection.selectedLines.isEmpty else { continue }

                if selection.isFullySelected {
                    let patch = hunk.toPatch(filePath: fileDiff.displayPath, isNew: fileDiff.isNew, isDeleted: fileDiff.isDeleted)
                    patches.append(patch)
                } else if let patch = hunk.toSelectivePatch(filePath: fileDiff.displayPath, selectedLineIndices: selection.selectedLines, isNew: fileDiff.isNew, isDeleted: fileDiff.isDeleted) {
                    patches.append(patch)
                }
            }
        }

        guard !patches.isEmpty else { return }

        do {
            let fullPatch = patches.joined(separator: "\n")
            try await repository.unstageHunks(patch: fullPatch)
            await refreshStatusAndDiff()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func discardChanges(file: GitFileStatus) async {
        guard let repository = repository else { return }

        do {
            try await repository.discardChanges(file: file.path)
            await refreshStatusAndDiff()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Hunk Selection

    func toggleHunk(_ hunk: GitHunk) {
        if var selection = hunkSelections[hunk.id] {
            if selection.isFullySelected {
                selection.deselectAll()
            } else {
                selection.selectAll(in: hunk)
            }
            hunkSelections[hunk.id] = selection
        }
    }

    func toggleLine(_ lineIndex: Int, in hunk: GitHunk) {
        if var selection = hunkSelections[hunk.id] {
            selection.toggleLine(lineIndex, in: hunk)
            hunkSelections[hunk.id] = selection
        }
    }

    func selectAllHunks() {
        guard let diff = fileDiff else { return }
        for fileDiff in diff.files {
            for hunk in fileDiff.hunks {
                hunkSelections[hunk.id] = HunkSelection(hunk: hunk, fullySelected: true)
            }
        }
    }

    func deselectAllHunks() {
        for key in hunkSelections.keys {
            hunkSelections[key]?.deselectAll()
        }
    }

    // MARK: - Drag Selection

    func beginDragSelection(at lineIndex: Int, in hunk: GitHunk) {
        guard lineIndex >= 0 && lineIndex < hunk.lines.count,
              hunk.lines[lineIndex].type != .context else { return }

        // Snapshot current selections so we can revert as drag range changes
        preDragSelections = hunkSelections

        let wasSelected = hunkSelections[hunk.id]?.selectedLines.contains(lineIndex) ?? false
        dragStartLineKey = (hunkId: hunk.id, lineIndex: lineIndex)
        dragSelectMode = !wasSelected
    }

    /// Apply drag selection to the given lines (sorted by visual position).
    /// Restores from pre-drag snapshot then applies mode to the range.
    func updateDragSelection(linesInRange: [(hunkId: UUID, lineIndex: Int)], allHunks: [GitHunk]) {
        guard let preDrag = preDragSelections, let mode = dragSelectMode else { return }

        // Restore from snapshot
        hunkSelections = preDrag

        // Apply drag mode to all lines in range
        for (hunkId, lineIndex) in linesInRange {
            guard let hunk = allHunks.first(where: { $0.id == hunkId }),
                  lineIndex >= 0 && lineIndex < hunk.lines.count,
                  hunk.lines[lineIndex].type != .context else { continue }

            if var selection = hunkSelections[hunkId] {
                if mode {
                    selection.selectedLines.insert(lineIndex)
                } else {
                    selection.selectedLines.remove(lineIndex)
                }
                let changeableLines = Set(hunk.lines.indices.filter { hunk.lines[$0].type != .context })
                selection.isFullySelected = selection.selectedLines == changeableLines
                hunkSelections[hunkId] = selection
            }
        }
    }

    func endDragSelection() {
        dragStartLineKey = nil
        dragSelectMode = nil
        preDragSelections = nil
    }

    // MARK: - Commits

    func commit() async {
        guard let repository = repository,
              !commitMessage.isEmpty else { return }

        do {
            try await repository.commit(message: commitMessage)
            commitMessage = ""
            await refreshAfterCommit()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Branches

    func checkout(branch: String) async {
        guard let repository = repository else { return }

        do {
            try await repository.checkout(branch: branch)
            await refreshAfterBranchChange()
            // Also refresh commits since we're on a different branch
            self.commits = try await repository.log(maxCount: 100)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createBranch(name: String, startPoint: String? = nil) async {
        guard let repository = repository else { return }

        do {
            try await repository.createBranch(name: name, startPoint: startPoint)
            await refreshBranches()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteBranch(name: String, force: Bool = false) async {
        guard let repository = repository else { return }

        do {
            try await repository.deleteBranch(name: name, force: force)
            await refreshBranches()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Remote Operations

    func fetch() async {
        guard let repository = repository else { return }
        isLoading = true

        do {
            try await repository.fetch(prune: true)
            // Fetch updates remote tracking info, refresh branches only
            await refreshBranches()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func pull() async {
        guard let repository = repository else { return }
        isLoading = true

        do {
            try await repository.pull()
            // Pull changes files and commits
            async let statusTask = repository.status()
            async let commitsTask = repository.log(maxCount: 100)
            async let branchesTask = repository.branchesWithTracking()

            let (newStatus, newCommits, newBranches) = try await (
                statusTask, commitsTask, branchesTask
            )

            self.status = newStatus
            self.commits = newCommits
            self.branches = newBranches

            // Clear selection as working tree may have changed
            selectedFile = nil
            fileDiff = nil
            hunkSelections.removeAll()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func push() async {
        guard let repository = repository else { return }
        isLoading = true

        do {
            try await repository.push()
            // Push only updates remote tracking info
            await refreshBranches()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
