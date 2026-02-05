import Foundation

/// Executes commands on a remote host within a specific working directory
actor RemoteExecutor {
    private let connection: SSHConnection
    private let workingDirectory: String

    init(connection: SSHConnection, workingDirectory: String) {
        self.connection = connection
        self.workingDirectory = workingDirectory
    }

    /// Execute a command in the working directory
    func execute(_ command: String) async throws -> CommandResult {
        let fullCommand = "cd \(workingDirectory.shellEscaped) && \(command)"
        return try await connection.execute(fullCommand)
    }

    /// Execute a command with input data
    func execute(_ command: String, input: Data) async throws -> CommandResult {
        let fullCommand = "cd \(workingDirectory.shellEscaped) && \(command)"
        return try await connection.execute(fullCommand, input: input)
    }

    /// Execute a command and return output, throwing on failure
    func run(_ command: String) async throws -> String {
        let result = try await execute(command)
        if !result.isSuccess {
            throw SSHError.commandFailed(result.error, result.exitCode)
        }
        return result.output
    }

    /// Execute a command with input and return output, throwing on failure
    func run(_ command: String, input: String) async throws -> String {
        guard let data = input.data(using: .utf8) else {
            throw SSHError.commandFailed("Failed to encode input", -1)
        }
        let result = try await execute(command, input: data)
        if !result.isSuccess {
            throw SSHError.commandFailed(result.error, result.exitCode)
        }
        return result.output
    }

    /// Check if a path exists on the remote host
    func pathExists(_ path: String) async throws -> Bool {
        let result = try await execute("test -e \(path.shellEscaped) && echo 'exists'")
        return result.output.contains("exists")
    }

    /// Check if the working directory is a git repository
    func isGitRepository() async throws -> Bool {
        let result = try await execute("git rev-parse --is-inside-work-tree 2>/dev/null")
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    /// Get the root directory of the git repository
    func gitRoot() async throws -> String {
        let output = try await run("git rev-parse --show-toplevel")
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    /// Escape a string for safe use in shell commands
    var shellEscaped: String {
        // Use single quotes and escape any existing single quotes
        let escaped = self.replacingOccurrences(of: "'", with: "'\"'\"'")
        return "'\(escaped)'"
    }
}
