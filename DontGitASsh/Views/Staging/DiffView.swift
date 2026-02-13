import SwiftUI

/// View for displaying file diffs with hunk selection
struct DiffView: View {
    @EnvironmentObject var viewModel: RepositoryViewModel
    @ObservedObject var preferences = Preferences.shared

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            diffToolbar

            Divider()

            // Diff content
            if let diff = viewModel.fileDiff {
                if diff.isEmpty {
                    Text("No changes")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(diff.files) { file in
                                FileDiffSection(file: file)
                            }
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    var diffToolbar: some View {
        HStack {
            if let file = viewModel.selectedFile {
                Image(systemName: "doc.text")
                Text(file.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Selection actions
            Button {
                viewModel.selectAllHunks()
            } label: {
                Text("Select All")
            }
            .buttonStyle(.borderless)

            Button {
                viewModel.deselectAllHunks()
            } label: {
                Text("Deselect All")
            }
            .buttonStyle(.borderless)

            Divider()
                .frame(height: 16)

            // Stage/Unstage selected
            if viewModel.selectedFile?.isStaged == true {
                Button {
                    Task { await viewModel.unstageSelectedHunks() }
                } label: {
                    Label("Unstage Selected", systemImage: "minus.circle")
                }
                .buttonStyle(.borderless)
            } else {
                Button {
                    Task { await viewModel.stageSelectedHunks() }
                } label: {
                    Label("Stage Selected", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }

            Divider()
                .frame(height: 16)

            // View mode toggle
            Picker("View Mode", selection: $preferences.diffViewMode) {
                ForEach(DiffViewMode.allCases, id: \.self) { mode in
                    Image(systemName: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 80)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct FileDiffSection: View {
    let file: GitFileDiff
    @EnvironmentObject var viewModel: RepositoryViewModel
    @ObservedObject var preferences = Preferences.shared
    @State private var lineFrames: [String: (hunkId: UUID, lineIndex: Int, frame: CGRect)] = [:]
    @State private var lastDragLineKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // File header
            HStack {
                fileIcon

                Text(file.displayPath)
                    .fontWeight(.medium)

                Spacer()

                HStack(spacing: 8) {
                    Text("+\(file.additions)")
                        .foregroundColor(.green)
                    Text("-\(file.deletions)")
                        .foregroundColor(.red)
                }
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            // Hunks
            if file.isBinary {
                Text("Binary file")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(file.hunks) { hunk in
                        HunkView(
                            hunk: hunk,
                            selection: viewModel.hunkSelections[hunk.id],
                            viewMode: preferences.diffViewMode
                        )
                    }
                }
                .coordinateSpace(name: "diffLines")
                .onPreferenceChange(LineFramePreferenceKey.self) { prefs in
                    var frames: [String: (hunkId: UUID, lineIndex: Int, frame: CGRect)] = [:]
                    for pref in prefs {
                        let key = "\(pref.hunkId)_\(pref.index)"
                        frames[key] = (hunkId: pref.hunkId, lineIndex: pref.index, frame: pref.frame)
                    }
                    lineFrames = frames
                }
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("diffLines"))
                        .onChanged { value in
                            guard let hit = lineAt(y: value.location.y) else { return }
                            let hitKey = "\(hit.hunkId)_\(hit.lineIndex)"

                            if viewModel.dragStartLineKey == nil {
                                // Begin drag
                                guard let hunk = file.hunks.first(where: { $0.id == hit.hunkId }) else { return }
                                lastDragLineKey = hitKey
                                viewModel.beginDragSelection(at: hit.lineIndex, in: hunk)
                                // Apply to initial line
                                let range = linesInYRange(
                                    from: hit.frame.midY,
                                    to: hit.frame.midY
                                )
                                viewModel.updateDragSelection(linesInRange: range, allHunks: file.hunks)
                            } else if hitKey != lastDragLineKey {
                                // Continue drag
                                lastDragLineKey = hitKey
                                guard let startKey = viewModel.dragStartLineKey,
                                      let startEntry = lineFrames["\(startKey.hunkId)_\(startKey.lineIndex)"] else { return }
                                let range = linesInYRange(
                                    from: startEntry.frame.midY,
                                    to: hit.frame.midY
                                )
                                viewModel.updateDragSelection(linesInRange: range, allHunks: file.hunks)
                            }
                        }
                        .onEnded { _ in
                            lastDragLineKey = nil
                            viewModel.endDragSelection()
                        }
                )
            }
        }
    }

    /// Find which line the Y coordinate falls in
    private func lineAt(y: CGFloat) -> (hunkId: UUID, lineIndex: Int, frame: CGRect)? {
        for (_, entry) in lineFrames {
            if y >= entry.frame.minY && y <= entry.frame.maxY {
                return entry
            }
        }
        // Clamp to nearest line
        let sorted = lineFrames.values.sorted { $0.frame.midY < $1.frame.midY }
        if let first = sorted.first, y < first.frame.minY {
            return first
        }
        if let last = sorted.last, y > last.frame.maxY {
            return last
        }
        return nil
    }

    /// Get all lines between two Y positions, sorted by visual order
    private func linesInYRange(from y1: CGFloat, to y2: CGFloat) -> [(hunkId: UUID, lineIndex: Int)] {
        let minY = min(y1, y2)
        let maxY = max(y1, y2)
        return lineFrames.values
            .filter { $0.frame.midY >= minY - 1 && $0.frame.midY <= maxY + 1 }
            .sorted { $0.frame.midY < $1.frame.midY }
            .map { (hunkId: $0.hunkId, lineIndex: $0.lineIndex) }
    }

    @ViewBuilder
    var fileIcon: some View {
        if file.isNew {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.green)
        } else if file.isDeleted {
            Image(systemName: "minus.circle.fill")
                .foregroundColor(.red)
        } else if file.isRenamed {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundColor(.blue)
        } else {
            Image(systemName: "pencil.circle.fill")
                .foregroundColor(.orange)
        }
    }
}

#Preview {
    DiffView()
        .environmentObject(RepositoryViewModel(connection: Connection(
            name: "Test",
            host: "localhost",
            repositoryPath: "/tmp/repo"
        )))
}
