import SwiftUI

/// Detail view for a selected branch (shown in column 3)
struct BranchDetailView: View {
    let branch: GitBranch
    @EnvironmentObject var viewModel: RepositoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: branch.isRemote ? "cloud" : "arrow.triangle.branch")
                        .font(.title2)

                    VStack(alignment: .leading) {
                        Text(branch.name)
                            .font(.title2)
                            .fontWeight(.semibold)

                        if branch.isCurrent {
                            Label("Current Branch", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }

                    Spacer()

                    if !branch.isCurrent {
                        Button("Checkout") {
                            Task {
                                await viewModel.checkout(branch: branch.name)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if let tracking = branch.trackingBranch {
                    HStack {
                        Text("Tracking:")
                            .foregroundColor(.secondary)
                        Text(tracking)
                    }
                    .font(.caption)
                }

                if let hash = branch.commitHash {
                    HStack {
                        Text("HEAD:")
                            .foregroundColor(.secondary)
                        Text(hash)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Recent commits on this branch
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Commits")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)

                List(viewModel.commits.prefix(20), id: \.hash) { commit in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(commit.subject)
                            .lineLimit(1)

                        HStack {
                            Text(commit.shortHash)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)

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
                .listStyle(.plain)
            }
        }
    }
}

#Preview {
    BranchDetailView(branch: GitBranch(
        name: "main",
        isRemote: false,
        isCurrent: true,
        trackingBranch: "origin/main",
        commitHash: "abc1234"
    ))
    .environmentObject(RepositoryViewModel(connection: Connection(
        name: "Test",
        host: "localhost",
        repositoryPath: "/tmp/repo"
    )))
}
