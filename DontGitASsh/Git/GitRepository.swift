import Foundation

/// Main interface for git operations on a remote repository
actor GitRepository {
    private let executor: RemoteExecutor
    let path: String

    init(executor: RemoteExecutor, path: String) {
        self.executor = executor
        self.path = path
    }

    // MARK: - Status

    /// Get the current repository status
    func status() async throws -> GitStatus {
        let output = try await executor.run("git status --porcelain=v2 --branch")
        return GitStatusParser.parse(output)
    }

    // MARK: - Branches

    /// Get all local branches
    func localBranches() async throws -> [GitBranch] {
        let output = try await executor.run("git branch -v")
        return GitBranchParser.parseLocal(output)
    }

    /// Get all remote branches
    func remoteBranches() async throws -> [GitBranch] {
        let output = try await executor.run("git branch -r")
        return GitBranchParser.parseRemote(output)
    }

    /// Get local branches with tracking info
    func branchesWithTracking() async throws -> [GitBranch] {
        let output = try await executor.run("git branch -vv")
        return GitBranchParser.parseWithTracking(output)
    }

    /// Get current branch name
    func currentBranch() async throws -> String {
        let output = try await executor.run("git rev-parse --abbrev-ref HEAD")
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Switch to a branch
    func checkout(branch: String) async throws {
        _ = try await executor.run("git checkout \(branch.shellEscaped)")
    }

    /// Create a new branch
    func createBranch(name: String, startPoint: String? = nil) async throws {
        var command = "git checkout -b \(name.shellEscaped)"
        if let startPoint = startPoint {
            command += " \(startPoint.shellEscaped)"
        }
        _ = try await executor.run(command)
    }

    /// Delete a local branch
    func deleteBranch(name: String, force: Bool = false) async throws {
        let flag = force ? "-D" : "-d"
        _ = try await executor.run("git branch \(flag) \(name.shellEscaped)")
    }

    // MARK: - Commits

    /// Get commit log
    func log(maxCount: Int = 100, branch: String? = nil) async throws -> [GitCommit] {
        var command = "git log --format='\(GitLogParser.logFormat)' -n \(maxCount)"
        if let branch = branch {
            command += " \(branch.shellEscaped)"
        }
        let output = try await executor.run(command)
        return GitLogParser.parse(output)
    }

    /// Get commit log with graph data for visualization
    func logWithGraph(maxCount: Int = 100) async throws -> [GitCommit] {
        let command = "git log --format='\(GitLogParser.logFormat)' --all -n \(maxCount)"
        let output = try await executor.run(command)
        return GitLogParser.parse(output)
    }

    /// Get a single commit by hash
    func commit(hash: String) async throws -> GitCommit? {
        let output = try await executor.run("git log --format='\(GitLogParser.logFormat)' -n 1 \(hash.shellEscaped)")
        return GitLogParser.parse(output).first
    }

    /// Create a new commit
    func commit(message: String) async throws {
        // Use HEREDOC-style input for the message to handle special characters
        _ = try await executor.run("git commit -m \(message.shellEscaped)")
    }

    /// Amend the last commit
    func amendCommit(message: String? = nil) async throws {
        if let message = message {
            _ = try await executor.run("git commit --amend -m \(message.shellEscaped)")
        } else {
            _ = try await executor.run("git commit --amend --no-edit")
        }
    }

    // MARK: - Diff

    /// Get diff for unstaged changes
    func diff(file: String? = nil) async throws -> GitDiff {
        var command = "git diff"
        if let file = file {
            command += " -- \(file.shellEscaped)"
        }
        let output = try await executor.run(command)
        return DiffParser.parse(output)
    }

    /// Get diff for staged changes
    func diffStaged(file: String? = nil) async throws -> GitDiff {
        var command = "git diff --cached"
        if let file = file {
            command += " -- \(file.shellEscaped)"
        }
        let output = try await executor.run(command)
        return DiffParser.parse(output)
    }

    /// Get diff between commits
    func diffCommits(from: String, to: String, file: String? = nil) async throws -> GitDiff {
        var command = "git diff \(from.shellEscaped) \(to.shellEscaped)"
        if let file = file {
            command += " -- \(file.shellEscaped)"
        }
        let output = try await executor.run(command)
        return DiffParser.parse(output)
    }

    /// Get diff for a single commit
    func diffCommit(hash: String) async throws -> GitDiff {
        let output = try await executor.run("git diff \(hash.shellEscaped)^..\(hash.shellEscaped)")
        return DiffParser.parse(output)
    }

    // MARK: - Staging

    /// Stage a file
    func stage(file: String) async throws {
        _ = try await executor.run("git add \(file.shellEscaped)")
    }

    /// Stage all changes
    func stageAll() async throws {
        _ = try await executor.run("git add -A")
    }

    /// Unstage a file
    func unstage(file: String) async throws {
        _ = try await executor.run("git reset HEAD -- \(file.shellEscaped)")
    }

    /// Unstage all changes
    func unstageAll() async throws {
        _ = try await executor.run("git reset HEAD")
    }

    /// Stage specific hunks using a patch
    func stageHunks(patch: String) async throws {
        _ = try await executor.run("git apply --cached", input: patch)
    }

    /// Unstage specific hunks using a patch
    func unstageHunks(patch: String) async throws {
        _ = try await executor.run("git apply --cached --reverse", input: patch)
    }

    /// Discard changes to a file
    func discardChanges(file: String) async throws {
        _ = try await executor.run("git checkout -- \(file.shellEscaped)")
    }

    /// Discard specific hunks using a patch
    func discardHunks(patch: String) async throws {
        _ = try await executor.run("git apply --reverse", input: patch)
    }

    // MARK: - Remote Operations

    /// Fetch from remote
    func fetch(remote: String = "origin", prune: Bool = false) async throws {
        var command = "git fetch \(remote.shellEscaped)"
        if prune {
            command += " --prune"
        }
        _ = try await executor.run(command)
    }

    /// Pull from remote
    func pull(remote: String = "origin", branch: String? = nil) async throws {
        var command = "git pull \(remote.shellEscaped)"
        if let branch = branch {
            command += " \(branch.shellEscaped)"
        }
        _ = try await executor.run(command)
    }

    /// Push to remote
    func push(remote: String = "origin", branch: String? = nil, setUpstream: Bool = false, force: Bool = false) async throws {
        var command = "git push"
        if setUpstream {
            command += " -u"
        }
        if force {
            command += " --force-with-lease"
        }
        command += " \(remote.shellEscaped)"
        if let branch = branch {
            command += " \(branch.shellEscaped)"
        }
        _ = try await executor.run(command)
    }

    /// List remotes
    func remotes() async throws -> [(name: String, url: String)] {
        let output = try await executor.run("git remote -v")
        var remotes: [(String, String)] = []
        var seen: Set<String> = []

        for line in output.components(separatedBy: .newlines) {
            let parts = line.split(separator: "\t")
            guard parts.count >= 2 else { continue }
            let name = String(parts[0])
            let urlPart = String(parts[1]).components(separatedBy: " ").first ?? ""

            if !seen.contains(name) {
                remotes.append((name, urlPart))
                seen.insert(name)
            }
        }

        return remotes
    }

    // MARK: - Merge/Rebase

    /// Merge a branch
    func merge(branch: String, noFastForward: Bool = false) async throws {
        var command = "git merge"
        if noFastForward {
            command += " --no-ff"
        }
        command += " \(branch.shellEscaped)"
        _ = try await executor.run(command)
    }

    /// Rebase onto a branch
    func rebase(onto: String) async throws {
        _ = try await executor.run("git rebase \(onto.shellEscaped)")
    }

    /// Abort an in-progress merge
    func abortMerge() async throws {
        _ = try await executor.run("git merge --abort")
    }

    /// Abort an in-progress rebase
    func abortRebase() async throws {
        _ = try await executor.run("git rebase --abort")
    }

    // MARK: - Stash

    /// Stash changes
    func stash(message: String? = nil) async throws {
        var command = "git stash push"
        if let message = message {
            command += " -m \(message.shellEscaped)"
        }
        _ = try await executor.run(command)
    }

    /// Apply stash
    func stashApply(index: Int = 0) async throws {
        _ = try await executor.run("git stash apply stash@{\(index)}")
    }

    /// Pop stash
    func stashPop(index: Int = 0) async throws {
        _ = try await executor.run("git stash pop stash@{\(index)}")
    }

    /// Drop stash
    func stashDrop(index: Int = 0) async throws {
        _ = try await executor.run("git stash drop stash@{\(index)}")
    }

    /// List stashes
    func stashList() async throws -> [String] {
        let output = try await executor.run("git stash list")
        return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    // MARK: - File Operations

    /// Get file content at a specific revision
    func showFile(path: String, revision: String = "HEAD") async throws -> String {
        return try await executor.run("git show \(revision.shellEscaped):\(path.shellEscaped)")
    }

    /// Get blame for a file
    func blame(file: String) async throws -> String {
        return try await executor.run("git blame \(file.shellEscaped)")
    }
}
