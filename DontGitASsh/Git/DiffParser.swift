import Foundation

/// Parser for git diff output
struct DiffParser {
    /// Parse git diff output into structured data
    static func parse(_ output: String) -> GitDiff {
        let lines = output.components(separatedBy: "\n")
        var files: [GitFileDiff] = []
        var currentFile: FileParseState?

        for line in lines {
            if line.hasPrefix("diff --git") {
                // Save previous file
                if let file = currentFile?.toFileDiff() {
                    files.append(file)
                }
                currentFile = FileParseState()
                parseGitDiffLine(line, into: &currentFile!)
            } else if let state = currentFile {
                var mutableState = state
                parseLine(line, into: &mutableState)
                currentFile = mutableState
            }
        }

        // Save last file
        if let file = currentFile?.toFileDiff() {
            files.append(file)
        }

        return GitDiff(files: files)
    }

    private static func parseGitDiffLine(_ line: String, into state: inout FileParseState) {
        // diff --git a/path b/path
        let regex = try? NSRegularExpression(pattern: "diff --git a/(.*) b/(.*)", options: [])
        if let match = regex?.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) {
            if let range1 = Range(match.range(at: 1), in: line) {
                state.oldPath = String(line[range1])
            }
            if let range2 = Range(match.range(at: 2), in: line) {
                state.newPath = String(line[range2])
            }
        }
    }

    private static func parseLine(_ line: String, into state: inout FileParseState) {
        if line.hasPrefix("new file mode") {
            state.isNew = true
        } else if line.hasPrefix("deleted file mode") {
            state.isDeleted = true
        } else if line.hasPrefix("rename from") {
            state.isRenamed = true
        } else if line.hasPrefix("Binary files") {
            state.isBinary = true
        } else if line.hasPrefix("--- ") {
            let path = String(line.dropFirst(4))
            if path != "/dev/null" {
                state.oldPath = path.hasPrefix("a/") ? String(path.dropFirst(2)) : path
            }
        } else if line.hasPrefix("+++ ") {
            let path = String(line.dropFirst(4))
            if path != "/dev/null" {
                state.newPath = path.hasPrefix("b/") ? String(path.dropFirst(2)) : path
            }
        } else if line.hasPrefix("@@") {
            // Save previous hunk
            if let hunk = state.currentHunk?.toHunk() {
                state.hunks.append(hunk)
            }
            state.currentHunk = parseHunkHeader(line)
        } else if state.currentHunk != nil {
            parseHunkLine(line, into: &state.currentHunk!)
        }
    }

    private static func parseHunkHeader(_ line: String) -> HunkParseState? {
        // @@ -oldStart,oldCount +newStart,newCount @@ optional context
        let regex = try? NSRegularExpression(
            pattern: "@@ -(\\d+)(?:,(\\d+))? \\+(\\d+)(?:,(\\d+))? @@(.*)?",
            options: []
        )

        guard let match = regex?.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        func intValue(at index: Int) -> Int {
            guard let range = Range(match.range(at: index), in: line) else { return 1 }
            return Int(line[range]) ?? 1
        }

        let oldStart = intValue(at: 1)
        let oldCount = match.range(at: 2).location != NSNotFound ? intValue(at: 2) : 1
        let newStart = intValue(at: 3)
        let newCount = match.range(at: 4).location != NSNotFound ? intValue(at: 4) : 1

        return HunkParseState(
            header: line,
            oldStart: oldStart,
            oldCount: oldCount,
            newStart: newStart,
            newCount: newCount,
            currentOldLine: oldStart,
            currentNewLine: newStart
        )
    }

    private static func parseHunkLine(_ line: String, into state: inout HunkParseState) {
        guard !line.isEmpty else { return }

        let firstChar = line.first!
        let content = String(line.dropFirst())

        switch firstChar {
        case "+":
            let diffLine = DiffLine(
                type: .addition,
                content: content,
                oldLineNumber: nil,
                newLineNumber: state.currentNewLine,
                rawLine: line
            )
            state.lines.append(diffLine)
            state.currentNewLine += 1

        case "-":
            let diffLine = DiffLine(
                type: .deletion,
                content: content,
                oldLineNumber: state.currentOldLine,
                newLineNumber: nil,
                rawLine: line
            )
            state.lines.append(diffLine)
            state.currentOldLine += 1

        case " ":
            let diffLine = DiffLine(
                type: .context,
                content: content,
                oldLineNumber: state.currentOldLine,
                newLineNumber: state.currentNewLine,
                rawLine: line
            )
            state.lines.append(diffLine)
            state.currentOldLine += 1
            state.currentNewLine += 1

        case "\\":
            // "\ No newline at end of file" - skip
            break

        default:
            // Treat as context if it doesn't start with a known prefix
            // This handles edge cases in diff output
            let diffLine = DiffLine(
                type: .context,
                content: line,
                oldLineNumber: state.currentOldLine,
                newLineNumber: state.currentNewLine,
                rawLine: " " + line
            )
            state.lines.append(diffLine)
            state.currentOldLine += 1
            state.currentNewLine += 1
        }
    }
}

// MARK: - Parse State Types

private struct FileParseState {
    var oldPath: String?
    var newPath: String?
    var isNew: Bool = false
    var isDeleted: Bool = false
    var isBinary: Bool = false
    var isRenamed: Bool = false
    var hunks: [GitHunk] = []
    var currentHunk: HunkParseState?

    func toFileDiff() -> GitFileDiff? {
        var finalHunks = hunks
        if let hunk = currentHunk?.toHunk() {
            finalHunks.append(hunk)
        }

        guard oldPath != nil || newPath != nil else { return nil }

        return GitFileDiff(
            oldPath: oldPath,
            newPath: newPath,
            hunks: finalHunks,
            isNew: isNew,
            isDeleted: isDeleted,
            isBinary: isBinary,
            isRenamed: isRenamed
        )
    }
}

private struct HunkParseState {
    let header: String
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    var currentOldLine: Int
    var currentNewLine: Int
    var lines: [DiffLine] = []

    func toHunk() -> GitHunk {
        GitHunk(
            header: header,
            oldStart: oldStart,
            oldCount: oldCount,
            newStart: newStart,
            newCount: newCount,
            lines: lines
        )
    }
}
