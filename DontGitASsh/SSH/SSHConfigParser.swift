import Foundation

/// Represents a parsed host entry from ~/.ssh/config
struct SSHConfigHost: Identifiable, Hashable {
    let id = UUID()
    let name: String           // Host alias (the name after "Host")
    let hostName: String?      // HostName (actual hostname/IP)
    let user: String?          // User
    let port: Int?             // Port
    let identityFile: String?  // IdentityFile

    /// The actual hostname to connect to (uses name if HostName not specified)
    var effectiveHostName: String {
        hostName ?? name
    }

    /// Display string for the host
    var displayString: String {
        var parts: [String] = []
        if let user = user {
            parts.append("\(user)@\(effectiveHostName)")
        } else {
            parts.append(effectiveHostName)
        }
        if let port = port, port != 22 {
            parts.append(":\(port)")
        }
        return parts.joined()
    }

    /// Whether this host entry is a wildcard/pattern
    var isPattern: Bool {
        name.contains("*") || name.contains("?")
    }
}

/// Parses SSH config files
enum SSHConfigParser {
    /// Default SSH config path
    static var defaultConfigPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.ssh/config"
    }

    /// Parse SSH config file at the given path
    static func parse(at path: String? = nil) throws -> [SSHConfigHost] {
        let configPath = path ?? defaultConfigPath
        let url = URL(fileURLWithPath: configPath)

        guard FileManager.default.fileExists(atPath: configPath) else {
            throw SSHConfigError.fileNotFound(configPath)
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        return parse(content: content)
    }

    /// Parse SSH config content string
    static func parse(content: String) -> [SSHConfigHost] {
        var hosts: [SSHConfigHost] = []
        var currentHost: String?
        var currentHostName: String?
        var currentUser: String?
        var currentPort: Int?
        var currentIdentityFile: String?

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Parse key-value pairs
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count >= 1 else { continue }

            let key = String(parts[0]).lowercased()
            let value = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : ""

            // Handle "key=value" format as well
            if key.contains("=") {
                let eqParts = key.split(separator: "=", maxSplits: 1)
                if eqParts.count == 2 {
                    let actualKey = String(eqParts[0]).lowercased()
                    let actualValue = String(eqParts[1])
                    processKeyValue(
                        key: actualKey,
                        value: actualValue,
                        currentHost: &currentHost,
                        currentHostName: &currentHostName,
                        currentUser: &currentUser,
                        currentPort: &currentPort,
                        currentIdentityFile: &currentIdentityFile,
                        hosts: &hosts
                    )
                    continue
                }
            }

            processKeyValue(
                key: key,
                value: value,
                currentHost: &currentHost,
                currentHostName: &currentHostName,
                currentUser: &currentUser,
                currentPort: &currentPort,
                currentIdentityFile: &currentIdentityFile,
                hosts: &hosts
            )
        }

        // Don't forget the last host
        if let host = currentHost {
            let sshHost = SSHConfigHost(
                name: host,
                hostName: currentHostName,
                user: currentUser,
                port: currentPort,
                identityFile: expandPath(currentIdentityFile)
            )
            hosts.append(sshHost)
        }

        return hosts
    }

    private static func processKeyValue(
        key: String,
        value: String,
        currentHost: inout String?,
        currentHostName: inout String?,
        currentUser: inout String?,
        currentPort: inout Int?,
        currentIdentityFile: inout String?,
        hosts: inout [SSHConfigHost]
    ) {
        switch key {
        case "host":
            // Save previous host if exists
            if let host = currentHost {
                let sshHost = SSHConfigHost(
                    name: host,
                    hostName: currentHostName,
                    user: currentUser,
                    port: currentPort,
                    identityFile: expandPath(currentIdentityFile)
                )
                hosts.append(sshHost)
            }

            // Start new host
            currentHost = value
            currentHostName = nil
            currentUser = nil
            currentPort = nil
            currentIdentityFile = nil

        case "hostname":
            currentHostName = value

        case "user":
            currentUser = value

        case "port":
            currentPort = Int(value)

        case "identityfile":
            currentIdentityFile = value

        default:
            break
        }
    }

    /// Expand ~ to home directory in paths
    private static func expandPath(_ path: String?) -> String? {
        guard let path = path else { return nil }
        if path.hasPrefix("~") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return home + path.dropFirst()
        }
        return path
    }
}

enum SSHConfigError: LocalizedError {
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "SSH config file not found at \(path)"
        }
    }
}
