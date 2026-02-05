import SwiftUI

/// Enum for repository view tabs - shared between content and detail views
/// Note: Branches have their own dedicated column, so not included here
enum RepositoryViewTab: String, CaseIterable {
    case changes = "Changes"
    case history = "History"
}

/// Content view (column 2) - shows file list, commit list, or branch list
struct RepositoryContentView: View {
    @EnvironmentObject var viewModel: RepositoryViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with branch info and actions
            repositoryToolbar

            Divider()

            // Tab picker
            Picker("View", selection: $viewModel.selectedViewTab) {
                ForEach(RepositoryViewTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Content based on selected tab
            switch viewModel.selectedViewTab {
            case .changes:
                FileListView()
            case .history:
                CommitListView()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }

    var repositoryToolbar: some View {
        HStack {
            // Branch indicator
            if let branch = viewModel.currentBranch {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                    Text(branch)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(4)
            }

            // Status indicators
            if let status = viewModel.status {
                if status.ahead > 0 {
                    Label("\(status.ahead)", systemImage: "arrow.up")
                        .font(.caption)
                }
                if status.behind > 0 {
                    Label("\(status.behind)", systemImage: "arrow.down")
                        .font(.caption)
                }
            }

            Spacer()

            // Loading indicator
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }

            // Actions
            Button {
                Task { await viewModel.fetch() }
            } label: {
                Image(systemName: "arrow.down.circle")
            }
            .help("Fetch from remote")

            Button {
                Task { await viewModel.pull() }
            } label: {
                Image(systemName: "arrow.down.to.line")
            }
            .help("Pull from remote")

            Button {
                Task { await viewModel.push() }
            } label: {
                Image(systemName: "arrow.up.to.line")
            }
            .help("Push to remote")

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh repository status")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

/// Detail view (column 4) - shows diff or commit detail
struct RepositoryDetailView: View {
    @EnvironmentObject var viewModel: RepositoryViewModel

    var body: some View {
        switch viewModel.selectedViewTab {
        case .changes:
            if viewModel.selectedFile != nil {
                DiffView()
            } else {
                emptyState(
                    icon: "doc.text",
                    title: "No File Selected",
                    message: "Select a file to view changes"
                )
            }
        case .history:
            if let commit = viewModel.selectedCommit {
                CommitDetailView(commit: commit)
            } else {
                emptyState(
                    icon: "clock",
                    title: "No Commit Selected",
                    message: "Select a commit to view details"
                )
            }
        }
    }

    func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// List of commits for column 2
struct CommitListView: View {
    @EnvironmentObject var viewModel: RepositoryViewModel

    var body: some View {
        List(viewModel.commits, selection: $viewModel.selectedCommit) { commit in
            CommitRow(commit: commit)
                .tag(commit)
        }
        .listStyle(.plain)
    }
}

struct CommitRow: View {
    let commit: GitCommit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(commit.subject)
                    .lineLimit(1)
                    .fontWeight(.medium)

                Spacer()

                Text(commit.shortHash)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            HStack {
                Text(commit.author)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(commit.date, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RepositoryContentView()
        .environmentObject(RepositoryViewModel(connection: Connection(
            name: "Test",
            host: "localhost",
            repositoryPath: "/tmp/repo"
        )))
        .environmentObject(AppState())
}
