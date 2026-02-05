import Foundation

/// Represents the status of a git repository
struct GitStatus {
    let branch: String?
    let upstream: String?
    let ahead: Int
    let behind: Int
    let files: [GitFileStatus]

    var hasChanges: Bool {
        !files.isEmpty
    }

    var stagedFiles: [GitFileStatus] {
        files.filter { $0.isStaged }
    }

    var unstagedFiles: [GitFileStatus] {
        files.filter { $0.hasUnstagedChanges }
    }

    var untrackedFiles: [GitFileStatus] {
        files.filter { $0.status == .untracked }
    }
}

/// Status of a single file
struct GitFileStatus: Identifiable, Hashable {
    let path: String
    let status: FileStatus
    let stagedStatus: FileStatus
    let unstagedStatus: FileStatus

    var id: String { path }

    /// File name without path
    var fileName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    /// Directory containing the file
    var directory: String {
        let url = URL(fileURLWithPath: path)
        let parent = url.deletingLastPathComponent().path
        return parent.isEmpty ? "" : parent
    }

    /// Whether the file has staged changes
    var isStaged: Bool {
        stagedStatus != .unmodified && stagedStatus != .untracked
    }

    /// Whether the file has unstaged changes
    var hasUnstagedChanges: Bool {
        unstagedStatus != .unmodified && unstagedStatus != .untracked
    }
}

/// File status codes
enum FileStatus: String, Hashable {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case untracked = "?"
    case ignored = "!"
    case unmodified = "."
    case typeChanged = "T"
    case unmerged = "U"

    var displayName: String {
        switch self {
        case .modified: return "Modified"
        case .added: return "Added"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        case .untracked: return "Untracked"
        case .ignored: return "Ignored"
        case .unmodified: return "Unmodified"
        case .typeChanged: return "Type Changed"
        case .unmerged: return "Unmerged"
        }
    }

    var icon: String {
        switch self {
        case .modified: return "pencil"
        case .added: return "plus"
        case .deleted: return "minus"
        case .renamed: return "arrow.right"
        case .copied: return "doc.on.doc"
        case .untracked: return "questionmark"
        case .ignored: return "eye.slash"
        case .unmodified: return "checkmark"
        case .typeChanged: return "arrow.triangle.2.circlepath"
        case .unmerged: return "exclamationmark.triangle"
        }
    }

    var color: String {
        switch self {
        case .modified: return "orange"
        case .added: return "green"
        case .deleted: return "red"
        case .renamed: return "blue"
        case .copied: return "blue"
        case .untracked: return "gray"
        case .ignored: return "gray"
        case .unmodified: return "gray"
        case .typeChanged: return "purple"
        case .unmerged: return "yellow"
        }
    }
}

/// Parser for git status output
struct GitStatusParser {
    /// Parse `git status --porcelain=v2 --branch`
    static func parse(_ output: String) -> GitStatus {
        let lines = output.components(separatedBy: .newlines)
        var branch: String?
        var upstream: String?
        var ahead = 0
        var behind = 0
        var files: [GitFileStatus] = []

        for line in lines {
            if line.hasPrefix("# branch.head ") {
                branch = String(line.dropFirst("# branch.head ".count))
            } else if line.hasPrefix("# branch.upstream ") {
                upstream = String(line.dropFirst("# branch.upstream ".count))
            } else if line.hasPrefix("# branch.ab ") {
                let parts = line.dropFirst("# branch.ab ".count).split(separator: " ")
                for part in parts {
                    if part.hasPrefix("+") {
                        ahead = Int(part.dropFirst()) ?? 0
                    } else if part.hasPrefix("-") {
                        behind = Int(part.dropFirst()) ?? 0
                    }
                }
            } else if line.hasPrefix("1 ") || line.hasPrefix("2 ") {
                // Changed entries
                if let file = parseChangedEntry(line) {
                    files.append(file)
                }
            } else if line.hasPrefix("? ") {
                // Untracked file
                let path = String(line.dropFirst(2))
                let file = GitFileStatus(
                    path: path,
                    status: .untracked,
                    stagedStatus: .untracked,
                    unstagedStatus: .untracked
                )
                files.append(file)
            } else if line.hasPrefix("! ") {
                // Ignored file
                let path = String(line.dropFirst(2))
                let file = GitFileStatus(
                    path: path,
                    status: .ignored,
                    stagedStatus: .ignored,
                    unstagedStatus: .ignored
                )
                files.append(file)
            } else if line.hasPrefix("u ") {
                // Unmerged entry
                if let file = parseUnmergedEntry(line) {
                    files.append(file)
                }
            }
        }

        return GitStatus(
            branch: branch,
            upstream: upstream,
            ahead: ahead,
            behind: behind,
            files: files
        )
    }

    private static func parseChangedEntry(_ line: String) -> GitFileStatus? {
        let parts = line.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: false)
        guard parts.count >= 9 else { return nil }

        let xy = String(parts[1])
        guard xy.count >= 2 else { return nil }

        let stagedChar = xy[xy.startIndex]
        let unstagedChar = xy[xy.index(after: xy.startIndex)]

        let stagedStatus = FileStatus(rawValue: String(stagedChar)) ?? .unmodified
        let unstagedStatus = FileStatus(rawValue: String(unstagedChar)) ?? .unmodified

        // For renamed/copied, path is in last part after tab
        let pathPart = parts[8...]
        let pathString = pathPart.joined(separator: " ")
        let path: String
        if pathString.contains("\t") {
            // Renamed: old_path\tnew_path
            let pathParts = pathString.split(separator: "\t")
            path = pathParts.count > 1 ? String(pathParts[1]) : String(pathParts[0])
        } else {
            path = pathString
        }

        let overallStatus: FileStatus
        if stagedStatus != .unmodified {
            overallStatus = stagedStatus
        } else if unstagedStatus != .unmodified {
            overallStatus = unstagedStatus
        } else {
            overallStatus = .unmodified
        }

        return GitFileStatus(
            path: path,
            status: overallStatus,
            stagedStatus: stagedStatus,
            unstagedStatus: unstagedStatus
        )
    }

    private static func parseUnmergedEntry(_ line: String) -> GitFileStatus? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count >= 11 else { return nil }

        let path = parts[10...].joined(separator: " ")

        return GitFileStatus(
            path: path,
            status: .unmerged,
            stagedStatus: .unmerged,
            unstagedStatus: .unmerged
        )
    }

    /// Parse simple `git status --porcelain` output
    static func parseSimple(_ output: String) -> [GitFileStatus] {
        let lines = output.components(separatedBy: .newlines)
        var files: [GitFileStatus] = []

        for line in lines {
            guard line.count >= 3 else { continue }

            let stagedChar = line[line.startIndex]
            let unstagedChar = line[line.index(after: line.startIndex)]
            let path = String(line.dropFirst(3))

            // In porcelain v1 format, space means unmodified
            let stagedStatus = stagedChar == " " ? .unmodified : (FileStatus(rawValue: String(stagedChar)) ?? .unmodified)
            let unstagedStatus = unstagedChar == " " ? .unmodified : (FileStatus(rawValue: String(unstagedChar)) ?? .unmodified)

            let overallStatus: FileStatus
            if stagedStatus != .unmodified && stagedStatus != .untracked {
                overallStatus = stagedStatus
            } else if unstagedStatus != .unmodified {
                overallStatus = unstagedStatus
            } else if stagedStatus == .untracked {
                overallStatus = .untracked
            } else {
                overallStatus = .unmodified
            }

            let file = GitFileStatus(
                path: path,
                status: overallStatus,
                stagedStatus: stagedStatus,
                unstagedStatus: unstagedStatus
            )
            files.append(file)
        }

        return files
    }
}
