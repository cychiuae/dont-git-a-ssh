import SwiftUI

/// Detailed view of a single commit
struct CommitDetailView: View {
    let commit: GitCommit
    @State private var diff: GitDiff?
    @State private var isLoadingDiff = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(commit.subject)
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let body = commit.body {
                        Text(body)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Metadata
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        GridRow {
                            Text("Commit")
                                .fontWeight(.medium)
                            Text(commit.hash)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }

                        GridRow {
                            Text("Author")
                                .fontWeight(.medium)
                            Text("\(commit.author) <\(commit.authorEmail)>")
                        }

                        GridRow {
                            Text("Date")
                                .fontWeight(.medium)
                            Text(commit.date, format: .dateTime)
                        }

                        if !commit.parentHashes.isEmpty {
                            GridRow {
                                Text("Parents")
                                    .fontWeight(.medium)
                                HStack {
                                    ForEach(commit.parentHashes, id: \.self) { hash in
                                        Text(String(hash.prefix(7)))
                                            .font(.system(.body, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                // Files changed
                if let diff = diff {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Files Changed")
                                .font(.headline)

                            Spacer()

                            Text("+\(diff.totalAdditions)")
                                .foregroundColor(.green)
                            Text("-\(diff.totalDeletions)")
                                .foregroundColor(.red)
                        }

                        ForEach(diff.files) { file in
                            CommitFileDiffView(file: file)
                        }
                    }
                } else if isLoadingDiff {
                    HStack {
                        ProgressView()
                        Text("Loading diff...")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .padding()
        }
    }
}

struct CommitFileDiffView: View {
    let file: GitFileDiff
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // File header
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .frame(width: 16)

                    fileIcon

                    Text(file.displayPath)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: 8) {
                        if file.additions > 0 {
                            Text("+\(file.additions)")
                                .foregroundColor(.green)
                        }
                        if file.deletions > 0 {
                            Text("-\(file.deletions)")
                                .foregroundColor(.red)
                        }
                    }
                    .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .buttonStyle(.plain)

            // Diff content
            if isExpanded {
                if file.isBinary {
                    Text("Binary file")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(file.hunks) { hunk in
                            VStack(alignment: .leading, spacing: 0) {
                                // Hunk header
                                Text(hunk.header)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                // Lines
                                ForEach(hunk.lines) { line in
                                    DiffLineView(line: line, showLineNumbers: true)
                                }
                            }
                        }
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                }
            }
        }
        .background(Color(nsColor: .separatorColor).opacity(0.2))
        .cornerRadius(4)
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

struct DiffLineView: View {
    let line: DiffLine
    let showLineNumbers: Bool

    var body: some View {
        HStack(spacing: 0) {
            if showLineNumbers {
                // Old line number
                Text(line.oldLineNumber.map { String($0) } ?? "")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, 4)

                // New line number
                Text(line.newLineNumber.map { String($0) } ?? "")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, 8)
            }

            // Line content
            Text(line.rawLine)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(lineBackground)
    }

    var lineBackground: Color {
        switch line.type {
        case .addition:
            return Color.green.opacity(0.2)
        case .deletion:
            return Color.red.opacity(0.2)
        case .context:
            return Color.clear
        }
    }
}

#Preview {
    CommitDetailView(commit: GitCommit(
        hash: "abc123def456789",
        shortHash: "abc123d",
        message: "Add new feature\n\nThis is a longer description of the commit that explains what was changed and why.",
        author: "John Doe",
        authorEmail: "john@example.com",
        date: Date(),
        parentHashes: ["def456", "ghi789"]
    ))
    .frame(width: 600, height: 500)
}
