import Foundation

/// Represents a git branch
struct GitBranch: Identifiable, Hashable {
    let name: String
    let isRemote: Bool
    let isCurrent: Bool
    let trackingBranch: String?
    let commitHash: String?

    var id: String { name }

    /// Display name without remote prefix
    var shortName: String {
        if isRemote, let slashIndex = name.firstIndex(of: "/") {
            return String(name[name.index(after: slashIndex)...])
        }
        return name
    }

    /// Remote name for remote branches
    var remoteName: String? {
        guard isRemote else { return nil }
        if let slashIndex = name.firstIndex(of: "/") {
            return String(name[..<slashIndex])
        }
        return nil
    }
}

/// Parser for git branch output
struct GitBranchParser {
    /// Parse local branches from `git branch -v`
    static func parseLocal(_ output: String) -> [GitBranch] {
        let lines = output.components(separatedBy: .newlines)
        var branches: [GitBranch] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let isCurrent = trimmed.hasPrefix("*")
            let content = isCurrent ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces) : trimmed

            // Parse: branch_name hash commit_message
            let parts = content.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count >= 2 else { continue }

            let name = String(parts[0])
            let hash = String(parts[1])

            let branch = GitBranch(
                name: name,
                isRemote: false,
                isCurrent: isCurrent,
                trackingBranch: nil,
                commitHash: hash
            )
            branches.append(branch)
        }

        return branches
    }

    /// Parse remote branches from `git branch -r`
    static func parseRemote(_ output: String) -> [GitBranch] {
        let lines = output.components(separatedBy: .newlines)
        var branches: [GitBranch] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Skip HEAD pointer
            if trimmed.contains("->") { continue }

            let branch = GitBranch(
                name: trimmed,
                isRemote: true,
                isCurrent: false,
                trackingBranch: nil,
                commitHash: nil
            )
            branches.append(branch)
        }

        return branches
    }

    /// Parse branch with tracking info from `git branch -vv`
    static func parseWithTracking(_ output: String) -> [GitBranch] {
        let lines = output.components(separatedBy: .newlines)
        var branches: [GitBranch] = []

        let trackingRegex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]", options: [])

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let isCurrent = trimmed.hasPrefix("*")
            let content = isCurrent ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces) : trimmed

            let parts = content.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count >= 2 else { continue }

            let name = String(parts[0])
            let hash = String(parts[1])

            var trackingBranch: String?
            if parts.count > 2 {
                let remaining = String(parts[2])
                if let match = trackingRegex?.firstMatch(in: remaining, options: [], range: NSRange(remaining.startIndex..., in: remaining)),
                   let range = Range(match.range(at: 1), in: remaining) {
                    let tracking = String(remaining[range])
                    // Remove status indicators like ": ahead 1"
                    trackingBranch = tracking.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces)
                }
            }

            let branch = GitBranch(
                name: name,
                isRemote: false,
                isCurrent: isCurrent,
                trackingBranch: trackingBranch,
                commitHash: hash
            )
            branches.append(branch)
        }

        return branches
    }
}
