import Foundation

/// Represents a git commit
struct GitCommit: Identifiable, Hashable {
    let hash: String
    let shortHash: String
    let message: String
    let author: String
    let authorEmail: String
    let date: Date
    let parentHashes: [String]

    var id: String { hash }

    /// First line of the commit message
    var subject: String {
        message.components(separatedBy: .newlines).first ?? message
    }

    /// Remaining lines of the commit message
    var body: String? {
        let lines = message.components(separatedBy: .newlines)
        guard lines.count > 1 else { return nil }
        return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if this is a merge commit
    var isMerge: Bool {
        parentHashes.count > 1
    }
}

/// Parser for git log output
struct GitLogParser {
    /// Parse git log output with custom format
    /// Format: %H|%h|%s|%an|%ae|%aI|%P
    static func parse(_ output: String) -> [GitCommit] {
        let lines = output.components(separatedBy: .newlines)
        var commits: [GitCommit] = []

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.components(separatedBy: "|")
            guard parts.count >= 6 else { continue }

            let hash = parts[0]
            let shortHash = parts[1]
            let message = parts[2]
            let author = parts[3]
            let authorEmail = parts[4]
            let dateString = parts[5]
            let parentString = parts.count > 6 ? parts[6] : ""

            let date = dateFormatter.date(from: dateString) ?? Date()
            let parentHashes = parentString.isEmpty ? [] : parentString.components(separatedBy: " ")

            let commit = GitCommit(
                hash: hash,
                shortHash: shortHash,
                message: message,
                author: author,
                authorEmail: authorEmail,
                date: date,
                parentHashes: parentHashes
            )
            commits.append(commit)
        }

        return commits
    }

    /// Git log format string for parsing
    static let logFormat = "%H|%h|%s|%an|%ae|%aI|%P"
}

/// Represents commit graph data for visualization
struct CommitGraphData {
    let commit: GitCommit
    let column: Int
    let connections: [GraphConnection]
}

struct GraphConnection {
    let fromColumn: Int
    let toColumn: Int
    let type: ConnectionType

    enum ConnectionType {
        case parent
        case merge
        case branch
    }
}
