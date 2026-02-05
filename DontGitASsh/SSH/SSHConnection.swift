import Foundation

/// Represents an SSH connection to a remote host with connection multiplexing
actor SSHConnection {
    let host: String
    let user: String?
    let port: Int?
    let identityFile: String?

    private var isConnected: Bool = false
    private var masterProcess: Process?

    /// Unique socket path for this connection's ControlMaster
    private let controlPath: String

    /// How long the master connection persists after last use (seconds)
    private let controlPersist: Int = 300

    init(host: String, user: String? = nil, port: Int? = nil, identityFile: String? = nil) {
        self.host = host
        self.user = user
        self.port = port
        self.identityFile = identityFile

        // Create unique socket path based on connection parameters
        let socketDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh/sockets")

        // Ensure socket directory exists
        try? FileManager.default.createDirectory(at: socketDir, withIntermediateDirectories: true)

        // Generate unique socket name
        let portSuffix = port.map { "-\($0)" } ?? ""
        let userPrefix = user.map { "\($0)@" } ?? ""
        self.controlPath = socketDir
            .appendingPathComponent("\(userPrefix)\(host)\(portSuffix).sock")
            .path
    }

    deinit {
        // Clean up socket file if it exists
        try? FileManager.default.removeItem(atPath: controlPath)
    }

    /// The SSH destination string (e.g., "user@host" or just "host")
    var destination: String {
        if let user = user {
            return "\(user)@\(host)"
        }
        return host
    }

    /// Build SSH command arguments with ControlMaster multiplexing
    func sshArguments(for command: String, controlMasterMode: ControlMasterMode = .auto) -> [String] {
        var args: [String] = []

        if let port = port {
            args.append(contentsOf: ["-p", String(port)])
        }

        if let identityFile = identityFile {
            args.append(contentsOf: ["-i", identityFile])
        }

        // Disable strict host key checking for convenience (can be made configurable)
        args.append(contentsOf: ["-o", "BatchMode=yes"])
        args.append(contentsOf: ["-o", "ConnectTimeout=10"])

        // Connection multiplexing options
        args.append(contentsOf: ["-o", "ControlPath=\(controlPath)"])

        switch controlMasterMode {
        case .yes:
            // Establish master connection
            args.append(contentsOf: ["-o", "ControlMaster=yes"])
            args.append(contentsOf: ["-o", "ControlPersist=\(controlPersist)"])
        case .auto:
            // Use existing master if available, create one if not
            args.append(contentsOf: ["-o", "ControlMaster=auto"])
            args.append(contentsOf: ["-o", "ControlPersist=\(controlPersist)"])
        case .no:
            // Just use existing master, don't create
            args.append(contentsOf: ["-o", "ControlMaster=no"])
        }

        args.append(destination)
        args.append(command)

        return args
    }

    /// Mode for SSH ControlMaster
    enum ControlMasterMode {
        case yes   // Force create master connection
        case auto  // Use existing or create new
        case no    // Only use existing, don't create
    }

    /// Establish the master connection (call once when opening a repository)
    func connect() async throws {
        guard !isConnected else { return }

        // Check if a master connection already exists
        if FileManager.default.fileExists(atPath: controlPath) {
            // Verify it's still alive
            let checkResult = try await executeRaw("echo ok", controlMasterMode: .no)
            if checkResult.isSuccess {
                isConnected = true
                return
            }
            // Dead socket, remove it
            try? FileManager.default.removeItem(atPath: controlPath)
        }

        // Establish new master connection with a simple command
        let result = try await executeRaw("echo connected", controlMasterMode: .yes)
        isConnected = result.isSuccess
        if !isConnected {
            throw SSHError.connectionFailed(result.error)
        }
    }

    /// Close the master connection
    func disconnect() async {
        guard isConnected else { return }

        // Send exit command to the master
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = ["-O", "exit", "-o", "ControlPath=\(controlPath)", destination]

        try? process.run()
        process.waitUntilExit()

        // Clean up socket
        try? FileManager.default.removeItem(atPath: controlPath)
        isConnected = false
        masterProcess = nil
    }

    /// Check if the connection is active
    func checkConnection() async -> Bool {
        guard FileManager.default.fileExists(atPath: controlPath) else {
            isConnected = false
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = ["-O", "check", "-o", "ControlPath=\(controlPath)", destination]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            isConnected = process.terminationStatus == 0
            return isConnected
        } catch {
            isConnected = false
            return false
        }
    }

    /// Test the connection by running a simple command
    func testConnection() async throws -> Bool {
        let result = try await execute("echo 'connected'")
        isConnected = result.exitCode == 0 && result.output.contains("connected")
        return isConnected
    }

    /// Execute a command on the remote host (uses multiplexed connection)
    func execute(_ command: String) async throws -> CommandResult {
        // Auto-connect if not connected - first command establishes master
        return try await executeRaw(command, controlMasterMode: .auto)
    }

    /// Execute a command with explicit ControlMaster mode
    private func executeRaw(_ command: String, controlMasterMode: ControlMasterMode) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = sshArguments(for: command, controlMasterMode: controlMasterMode)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()

                process.terminationHandler = { process in
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""

                    let result = CommandResult(
                        output: output,
                        error: error,
                        exitCode: Int(process.terminationStatus)
                    )
                    continuation.resume(returning: result)
                }
            } catch {
                continuation.resume(throwing: SSHError.connectionFailed(error.localizedDescription))
            }
        }
    }

    /// Execute a command with input data (for piping content)
    func execute(_ command: String, input: Data) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = sshArguments(for: command, controlMasterMode: .auto)

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()

                // Write input data
                inputPipe.fileHandleForWriting.write(input)
                inputPipe.fileHandleForWriting.closeFile()

                process.terminationHandler = { process in
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""

                    let result = CommandResult(
                        output: output,
                        error: error,
                        exitCode: Int(process.terminationStatus)
                    )
                    continuation.resume(returning: result)
                }
            } catch {
                continuation.resume(throwing: SSHError.connectionFailed(error.localizedDescription))
            }
        }
    }
}

/// Result of executing a command
struct CommandResult: Sendable {
    let output: String
    let error: String
    let exitCode: Int

    var isSuccess: Bool {
        exitCode == 0
    }
}

/// SSH-related errors
enum SSHError: Error, LocalizedError {
    case connectionFailed(String)
    case commandFailed(String, Int)
    case timeout
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .commandFailed(let message, let code):
            return "Command failed (exit code \(code)): \(message)"
        case .timeout:
            return "Connection timed out"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}
