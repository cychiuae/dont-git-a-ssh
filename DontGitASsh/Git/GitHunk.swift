import Foundation

/// Represents a hunk in a git diff
struct GitHunk: Identifiable, Hashable {
    let id: UUID
    let header: String
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    let lines: [DiffLine]

    init(
        id: UUID = UUID(),
        header: String,
        oldStart: Int,
        oldCount: Int,
        newStart: Int,
        newCount: Int,
        lines: [DiffLine]
    ) {
        self.id = id
        self.header = header
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.lines = lines
    }

    /// Generate a patch for this hunk
    func toPatch(filePath: String, isNew: Bool = false, isDeleted: Bool = false) -> String {
        var patch = ""

        if isNew {
            patch += "--- /dev/null\n"
            patch += "+++ b/\(filePath)\n"
        } else if isDeleted {
            patch += "--- a/\(filePath)\n"
            patch += "+++ /dev/null\n"
        } else {
            patch += "--- a/\(filePath)\n"
            patch += "+++ b/\(filePath)\n"
        }

        patch += header + "\n"

        for line in lines {
            patch += line.rawLine + "\n"
        }

        return patch
    }

    /// Generate a patch with only selected lines
    func toSelectivePatch(filePath: String, selectedLineIndices: Set<Int>, isNew: Bool = false, isDeleted: Bool = false) -> String? {
        var selectedLines: [DiffLine] = []
        var newOldCount = 0
        var newNewCount = 0

        for (index, line) in lines.enumerated() {
            switch line.type {
            case .context:
                selectedLines.append(line)
                newOldCount += 1
                newNewCount += 1
            case .addition:
                if selectedLineIndices.contains(index) {
                    selectedLines.append(line)
                    newNewCount += 1
                }
            case .deletion:
                if selectedLineIndices.contains(index) {
                    selectedLines.append(line)
                    newOldCount += 1
                } else {
                    // Convert unselected deletion to context
                    let contextLine = DiffLine(
                        type: .context,
                        content: line.content,
                        oldLineNumber: line.oldLineNumber,
                        newLineNumber: line.newLineNumber,
                        rawLine: " " + line.content
                    )
                    selectedLines.append(contextLine)
                    newOldCount += 1
                    newNewCount += 1
                }
            }
        }

        // If no changes are selected, return nil
        let hasChanges = selectedLines.contains { $0.type != .context }
        guard hasChanges else { return nil }

        // Build new header
        let newHeader = "@@ -\(oldStart),\(newOldCount) +\(newStart),\(newNewCount) @@"

        var patch = ""

        if isNew {
            patch += "--- /dev/null\n"
            patch += "+++ b/\(filePath)\n"
        } else if isDeleted {
            patch += "--- a/\(filePath)\n"
            patch += "+++ /dev/null\n"
        } else {
            patch += "--- a/\(filePath)\n"
            patch += "+++ b/\(filePath)\n"
        }

        patch += newHeader + "\n"

        for line in selectedLines {
            patch += line.rawLine + "\n"
        }

        return patch
    }
}

/// A single line in a diff
struct DiffLine: Identifiable, Hashable {
    let id: UUID
    let type: DiffLineType
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?
    let rawLine: String

    init(
        id: UUID = UUID(),
        type: DiffLineType,
        content: String,
        oldLineNumber: Int?,
        newLineNumber: Int?,
        rawLine: String
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
        self.rawLine = rawLine
    }
}

/// Type of diff line
enum DiffLineType: Hashable {
    case context
    case addition
    case deletion
}

/// Selection state for hunks
struct HunkSelection {
    var hunkId: UUID
    var selectedLines: Set<Int> // Indices of selected lines within the hunk
    var isFullySelected: Bool

    init(hunk: GitHunk, fullySelected: Bool = true) {
        self.hunkId = hunk.id
        self.isFullySelected = fullySelected
        if fullySelected {
            self.selectedLines = Set(hunk.lines.indices.filter { index in
                hunk.lines[index].type != .context
            })
        } else {
            self.selectedLines = []
        }
    }

    mutating func toggleLine(_ index: Int, in hunk: GitHunk) {
        guard hunk.lines[index].type != .context else { return }

        if selectedLines.contains(index) {
            selectedLines.remove(index)
        } else {
            selectedLines.insert(index)
        }

        updateFullySelectedState(for: hunk)
    }

    mutating func selectAll(in hunk: GitHunk) {
        selectedLines = Set(hunk.lines.indices.filter { index in
            hunk.lines[index].type != .context
        })
        isFullySelected = true
    }

    mutating func deselectAll() {
        selectedLines.removeAll()
        isFullySelected = false
    }

    private mutating func updateFullySelectedState(for hunk: GitHunk) {
        let changeableLines = Set(hunk.lines.indices.filter { index in
            hunk.lines[index].type != .context
        })
        isFullySelected = selectedLines == changeableLines
    }
}
