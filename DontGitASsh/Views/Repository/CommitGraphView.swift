import SwiftUI

/// Visual commit graph showing branch history
struct CommitGraphView: View {
    let commits: [GitCommit]
    @Binding var selectedCommit: GitCommit?

    private let columnWidth: CGFloat = 20
    private let rowHeight: CGFloat = 30
    private let colors: [Color] = [.blue, .green, .orange, .purple, .red, .cyan, .pink, .yellow]

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(commits.enumerated()), id: \.element.id) { index, commit in
                    CommitGraphRow(
                        commit: commit,
                        index: index,
                        isSelected: selectedCommit?.hash == commit.hash,
                        columnWidth: columnWidth,
                        rowHeight: rowHeight,
                        color: colors[index % colors.count]
                    )
                    .onTapGesture {
                        selectedCommit = commit
                    }
                }
            }
        }
    }
}

struct CommitGraphRow: View {
    let commit: GitCommit
    let index: Int
    let isSelected: Bool
    let columnWidth: CGFloat
    let rowHeight: CGFloat
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            // Graph column
            ZStack {
                // Vertical line
                Rectangle()
                    .fill(color.opacity(0.5))
                    .frame(width: 2)

                // Commit node
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)

                // Merge lines (simplified)
                if commit.isMerge {
                    Path { path in
                        path.move(to: CGPoint(x: columnWidth, y: rowHeight / 2))
                        path.addLine(to: CGPoint(x: columnWidth / 2, y: rowHeight / 2))
                    }
                    .stroke(color.opacity(0.5), lineWidth: 2)
                }
            }
            .frame(width: columnWidth, height: rowHeight)

            // Commit info
            HStack {
                Text(commit.shortHash)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)

                Text(commit.subject)
                    .lineLimit(1)

                Spacer()

                Text(commit.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 120, alignment: .trailing)

                Text(commit.date, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: rowHeight)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }
}

/// Simple inline graph indicator for list views
struct CommitGraphIndicator: View {
    let commit: GitCommit
    let column: Int
    let maxColumns: Int

    private let nodeSize: CGFloat = 8
    private let columnWidth: CGFloat = 14
    private let colors: [Color] = [.blue, .green, .orange, .purple, .red, .cyan]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<maxColumns, id: \.self) { col in
                ZStack {
                    if col == column {
                        Circle()
                            .fill(colors[col % colors.count])
                            .frame(width: nodeSize, height: nodeSize)
                    }

                    // Vertical line indicator
                    if col <= column {
                        Rectangle()
                            .fill(colors[col % colors.count].opacity(0.3))
                            .frame(width: 2)
                    }
                }
                .frame(width: columnWidth)
            }
        }
    }
}

#Preview {
    let sampleCommits = [
        GitCommit(
            hash: "abc123def456",
            shortHash: "abc123d",
            message: "Add new feature",
            author: "John Doe",
            authorEmail: "john@example.com",
            date: Date(),
            parentHashes: ["def456"]
        ),
        GitCommit(
            hash: "def456789012",
            shortHash: "def4567",
            message: "Fix bug in authentication",
            author: "Jane Smith",
            authorEmail: "jane@example.com",
            date: Date().addingTimeInterval(-3600),
            parentHashes: ["ghi789"]
        ),
        GitCommit(
            hash: "ghi789012345",
            shortHash: "ghi7890",
            message: "Initial commit",
            author: "John Doe",
            authorEmail: "john@example.com",
            date: Date().addingTimeInterval(-7200),
            parentHashes: []
        )
    ]

    CommitGraphView(commits: sampleCommits, selectedCommit: .constant(nil))
        .frame(width: 600, height: 200)
}
