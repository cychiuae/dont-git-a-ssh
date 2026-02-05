import SwiftUI

/// View for a single hunk with line-level selection
struct HunkView: View {
    let hunk: GitHunk
    let selection: HunkSelection?
    let viewMode: DiffViewMode

    @EnvironmentObject var viewModel: RepositoryViewModel
    @ObservedObject var preferences = Preferences.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hunk header
            HStack {
                // Select all checkbox
                Button {
                    viewModel.toggleHunk(hunk)
                } label: {
                    Image(systemName: selectionIcon)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)

                Text(hunk.header)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))

            // Lines
            switch viewMode {
            case .unified:
                UnifiedHunkContent(hunk: hunk, selection: selection)
            case .sideBySide:
                SideBySideHunkContent(hunk: hunk, selection: selection)
            }
        }
    }

    var selectionIcon: String {
        guard let selection = selection else {
            return "square"
        }

        if selection.isFullySelected {
            return "checkmark.square.fill"
        } else if selection.selectedLines.isEmpty {
            return "square"
        } else {
            return "minus.square.fill"
        }
    }
}

/// Unified diff view (single column with +/- lines)
struct UnifiedHunkContent: View {
    let hunk: GitHunk
    let selection: HunkSelection?

    @EnvironmentObject var viewModel: RepositoryViewModel
    @ObservedObject var preferences = Preferences.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(hunk.lines.enumerated()), id: \.element.id) { index, line in
                HunkLineRow(
                    line: line,
                    index: index,
                    hunk: hunk,
                    isSelected: selection?.selectedLines.contains(index) ?? false,
                    showLineNumbers: preferences.showLineNumbers
                )
            }
        }
    }
}

/// Side-by-side diff view
struct SideBySideHunkContent: View {
    let hunk: GitHunk
    let selection: HunkSelection?

    @EnvironmentObject var viewModel: RepositoryViewModel
    @ObservedObject var preferences = Preferences.shared

    // Pair up deletions with additions for side-by-side display
    var linePairs: [(left: DiffLine?, right: DiffLine?, leftIndex: Int?, rightIndex: Int?)] {
        var pairs: [(DiffLine?, DiffLine?, Int?, Int?)] = []
        var i = 0
        let lines = hunk.lines

        while i < lines.count {
            let line = lines[i]

            switch line.type {
            case .context:
                pairs.append((line, line, i, i))
                i += 1

            case .deletion:
                // Look ahead for matching addition
                var deletions: [(DiffLine, Int)] = [(line, i)]
                var j = i + 1

                // Collect consecutive deletions
                while j < lines.count && lines[j].type == .deletion {
                    deletions.append((lines[j], j))
                    j += 1
                }

                // Collect consecutive additions
                var additions: [(DiffLine, Int)] = []
                while j < lines.count && lines[j].type == .addition {
                    additions.append((lines[j], j))
                    j += 1
                }

                // Pair them up
                let maxCount = max(deletions.count, additions.count)
                for k in 0..<maxCount {
                    let left = k < deletions.count ? deletions[k] : nil
                    let right = k < additions.count ? additions[k] : nil
                    pairs.append((left?.0, right?.0, left?.1, right?.1))
                }

                i = j

            case .addition:
                // Lone addition
                pairs.append((nil, line, nil, i))
                i += 1
            }
        }

        return pairs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(linePairs.enumerated()), id: \.offset) { _, pair in
                HStack(spacing: 0) {
                    // Left side (old)
                    SideBySideLineView(
                        line: pair.left,
                        index: pair.leftIndex,
                        hunk: hunk,
                        isSelected: pair.leftIndex.map { selection?.selectedLines.contains($0) ?? false } ?? false,
                        isLeft: true
                    )

                    Divider()

                    // Right side (new)
                    SideBySideLineView(
                        line: pair.right,
                        index: pair.rightIndex,
                        hunk: hunk,
                        isSelected: pair.rightIndex.map { selection?.selectedLines.contains($0) ?? false } ?? false,
                        isLeft: false
                    )
                }
            }
        }
    }
}

struct SideBySideLineView: View {
    let line: DiffLine?
    let index: Int?
    let hunk: GitHunk
    let isSelected: Bool
    let isLeft: Bool

    @EnvironmentObject var viewModel: RepositoryViewModel
    @ObservedObject var preferences = Preferences.shared

    var body: some View {
        HStack(spacing: 0) {
            if let line = line {
                // Selection checkbox for changeable lines
                if line.type != .context {
                    Button {
                        if let index = index {
                            viewModel.toggleLine(index, in: hunk)
                        }
                    } label: {
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                } else {
                    Spacer()
                        .frame(width: 20)
                }

                // Line number
                if preferences.showLineNumbers {
                    let lineNum = isLeft ? line.oldLineNumber : line.newLineNumber
                    Text(lineNum.map { String($0) } ?? "")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                        .padding(.trailing, 4)
                }

                // Content
                Text(line.content)
                    .font(.system(size: preferences.fontSize, design: .monospaced))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Empty cell
                Spacer()
                    .frame(width: 20)

                if preferences.showLineNumbers {
                    Spacer()
                        .frame(width: 44)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(lineBackground)
        .frame(maxWidth: .infinity)
    }

    var lineBackground: Color {
        guard let line = line else {
            return Color(nsColor: .textBackgroundColor)
        }

        let baseColor: Color
        switch line.type {
        case .addition:
            baseColor = .green
        case .deletion:
            baseColor = .red
        case .context:
            return Color(nsColor: .textBackgroundColor)
        }

        return isSelected ? baseColor.opacity(0.4) : baseColor.opacity(0.15)
    }
}

struct HunkLineRow: View {
    let line: DiffLine
    let index: Int
    let hunk: GitHunk
    let isSelected: Bool
    let showLineNumbers: Bool

    @EnvironmentObject var viewModel: RepositoryViewModel
    @ObservedObject var preferences = Preferences.shared

    var isChangeable: Bool {
        line.type != .context
    }

    var body: some View {
        HStack(spacing: 0) {
            // Selection checkbox
            if isChangeable {
                Button {
                    viewModel.toggleLine(index, in: hunk)
                } label: {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            } else {
                Spacer()
                    .frame(width: 24)
            }

            // Line numbers
            if showLineNumbers {
                Text(line.oldLineNumber.map { String($0) } ?? "")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, 4)

                Text(line.newLineNumber.map { String($0) } ?? "")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, 8)
            }

            // Line prefix and content
            Text(line.rawLine)
                .font(.system(size: preferences.fontSize, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(lineBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            if isChangeable {
                viewModel.toggleLine(index, in: hunk)
            }
        }
    }

    var lineBackground: Color {
        let baseColor: Color
        switch line.type {
        case .addition:
            baseColor = .green
        case .deletion:
            baseColor = .red
        case .context:
            return Color(nsColor: .textBackgroundColor)
        }

        return isSelected ? baseColor.opacity(0.4) : baseColor.opacity(0.15)
    }
}

#Preview {
    let sampleHunk = GitHunk(
        header: "@@ -1,5 +1,6 @@",
        oldStart: 1,
        oldCount: 5,
        newStart: 1,
        newCount: 6,
        lines: [
            DiffLine(type: .context, content: "line 1", oldLineNumber: 1, newLineNumber: 1, rawLine: " line 1"),
            DiffLine(type: .deletion, content: "old line 2", oldLineNumber: 2, newLineNumber: nil, rawLine: "-old line 2"),
            DiffLine(type: .addition, content: "new line 2", oldLineNumber: nil, newLineNumber: 2, rawLine: "+new line 2"),
            DiffLine(type: .addition, content: "new line 3", oldLineNumber: nil, newLineNumber: 3, rawLine: "+new line 3"),
            DiffLine(type: .context, content: "line 4", oldLineNumber: 3, newLineNumber: 4, rawLine: " line 4"),
        ]
    )

    HunkView(
        hunk: sampleHunk,
        selection: HunkSelection(hunk: sampleHunk, fullySelected: false),
        viewMode: .unified
    )
    .environmentObject(RepositoryViewModel(connection: Connection(
        name: "Test",
        host: "localhost",
        repositoryPath: "/tmp/repo"
    )))
    .frame(width: 600)
}
