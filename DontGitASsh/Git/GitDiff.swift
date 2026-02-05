import Foundation

/// Represents a diff for a single file
struct GitFileDiff: Identifiable, Hashable {
    let id: UUID
    let oldPath: String?
    let newPath: String?
    let hunks: [GitHunk]
    let isNew: Bool
    let isDeleted: Bool
    let isBinary: Bool
    let isRenamed: Bool

    init(
        id: UUID = UUID(),
        oldPath: String?,
        newPath: String?,
        hunks: [GitHunk],
        isNew: Bool = false,
        isDeleted: Bool = false,
        isBinary: Bool = false,
        isRenamed: Bool = false
    ) {
        self.id = id
        self.oldPath = oldPath
        self.newPath = newPath
        self.hunks = hunks
        self.isNew = isNew
        self.isDeleted = isDeleted
        self.isBinary = isBinary
        self.isRenamed = isRenamed
    }

    /// The file path to display
    var displayPath: String {
        newPath ?? oldPath ?? "unknown"
    }

    /// Total number of additions
    var additions: Int {
        hunks.reduce(0) { total, hunk in
            total + hunk.lines.filter { $0.type == .addition }.count
        }
    }

    /// Total number of deletions
    var deletions: Int {
        hunks.reduce(0) { total, hunk in
            total + hunk.lines.filter { $0.type == .deletion }.count
        }
    }

    /// Generate a full patch for this file diff
    func toPatch() -> String {
        var patch = "diff --git a/\(oldPath ?? displayPath) b/\(newPath ?? displayPath)\n"

        if isNew {
            patch += "new file mode 100644\n"
            patch += "--- /dev/null\n"
            patch += "+++ b/\(displayPath)\n"
        } else if isDeleted {
            patch += "deleted file mode 100644\n"
            patch += "--- a/\(displayPath)\n"
            patch += "+++ /dev/null\n"
        } else {
            patch += "--- a/\(oldPath ?? displayPath)\n"
            patch += "+++ b/\(newPath ?? displayPath)\n"
        }

        for hunk in hunks {
            patch += hunk.header + "\n"
            for line in hunk.lines {
                patch += line.rawLine + "\n"
            }
        }

        return patch
    }
}

/// Represents a complete diff (potentially multiple files)
struct GitDiff {
    let files: [GitFileDiff]

    var totalAdditions: Int {
        files.reduce(0) { $0 + $1.additions }
    }

    var totalDeletions: Int {
        files.reduce(0) { $0 + $1.deletions }
    }

    var isEmpty: Bool {
        files.isEmpty
    }
}
