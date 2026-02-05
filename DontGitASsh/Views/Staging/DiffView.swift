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
                ForEach(file.hunks) { hunk in
                    HunkView(
                        hunk: hunk,
                        selection: viewModel.hunkSelections[hunk.id],
                        viewMode: preferences.diffViewMode
                    )
                }
            }
        }
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
