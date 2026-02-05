import SwiftUI

/// View for staging changes - now just wraps FileListView for column 2
/// DiffView is shown separately in column 3 (detail)
struct StagingView: View {
    @EnvironmentObject var viewModel: RepositoryViewModel

    var body: some View {
        FileListView()
    }
}

/// List of changed files organized by staging status
struct FileListView: View {
    @EnvironmentObject var viewModel: RepositoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Staged files
            FileSection(
                title: "Staged Changes",
                files: viewModel.status?.stagedFiles ?? [],
                icon: "checkmark.circle.fill",
                iconColor: .green
            ) { file in
                Task { await viewModel.unstageFile(file) }
            }

            Divider()

            // Unstaged files
            FileSection(
                title: "Changes",
                files: viewModel.status?.unstagedFiles ?? [],
                icon: "circle",
                iconColor: .orange
            ) { file in
                Task { await viewModel.stageFile(file) }
            }

            Divider()

            // Untracked files
            FileSection(
                title: "Untracked",
                files: viewModel.status?.untrackedFiles ?? [],
                icon: "questionmark.circle",
                iconColor: .secondary
            ) { file in
                Task { await viewModel.stageFile(file) }
            }

            Spacer()

            // Commit area
            if let status = viewModel.status, !status.stagedFiles.isEmpty {
                CommitArea()
            }
        }
    }
}

struct FileSection: View {
    let title: String
    let files: [GitFileStatus]
    let icon: String
    let iconColor: Color
    let onToggle: (GitFileStatus) -> Void

    @EnvironmentObject var viewModel: RepositoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .fontWeight(.medium)
                Spacer()
                Text("\(files.count)")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            // Files
            if files.isEmpty {
                Text("No files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(files) { file in
                    FileRow(file: file, onToggle: onToggle)
                }
            }
        }
    }
}

struct FileRow: View {
    let file: GitFileStatus
    let onToggle: (GitFileStatus) -> Void

    @EnvironmentObject var viewModel: RepositoryViewModel

    var isSelected: Bool {
        viewModel.selectedFile?.path == file.path
    }

    var body: some View {
        HStack {
            // Status icon
            statusIcon

            // File name
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .lineLimit(1)

                if !file.directory.isEmpty {
                    Text(file.directory)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Stage/unstage button
            Button {
                onToggle(file)
            } label: {
                Image(systemName: file.isStaged ? "minus.circle" : "plus.circle")
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            Task {
                await viewModel.selectFile(file)
            }
        }
        .contextMenu {
            Button("Stage") {
                Task { await viewModel.stageFile(file) }
            }
            .disabled(file.isStaged)

            Button("Unstage") {
                Task { await viewModel.unstageFile(file) }
            }
            .disabled(!file.isStaged)

            Divider()

            Button("Discard Changes", role: .destructive) {
                Task { await viewModel.discardChanges(file: file) }
            }
        }
    }

    @ViewBuilder
    var statusIcon: some View {
        let status = file.isStaged ? file.stagedStatus : file.unstagedStatus

        Image(systemName: status.icon)
            .foregroundColor(statusColor(for: status))
            .frame(width: 16)
    }

    func statusColor(for status: FileStatus) -> Color {
        switch status {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        case .renamed: return .blue
        case .copied: return .blue
        case .untracked: return .secondary
        case .unmerged: return .yellow
        default: return .secondary
        }
    }
}

struct CommitArea: View {
    @EnvironmentObject var viewModel: RepositoryViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 8) {
            Divider()

            TextEditor(text: $viewModel.commitMessage)
                .font(.system(.body, design: .default))
                .frame(height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 8)

            HStack {
                Text("\(viewModel.status?.stagedFiles.count ?? 0) files staged")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Commit") {
                    Task {
                        await viewModel.commit()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.commitMessage.isEmpty)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

#Preview {
    StagingView()
        .environmentObject(RepositoryViewModel(connection: Connection(
            name: "Test",
            host: "localhost",
            repositoryPath: "/tmp/repo"
        )))
        .environmentObject(AppState())
}
