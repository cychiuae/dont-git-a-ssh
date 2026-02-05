import Foundation

/// Represents a saved repository path under a connection
struct SavedRepository: Identifiable, Codable, Hashable {
    var id: UUID
    var path: String
    var name: String
    var lastConnected: Date?

    init(id: UUID = UUID(), path: String, name: String? = nil, lastConnected: Date? = nil) {
        self.id = id
        self.path = path
        self.name = name ?? URL(fileURLWithPath: path).lastPathComponent
        self.lastConnected = lastConnected
    }
}

/// Represents a saved SSH connection configuration
struct Connection: Identifiable, Hashable {
    var id: UUID
    var name: String
    var host: String
    var user: String?
    var port: Int?
    var identityFile: String?
    var repositories: [SavedRepository]
    var lastConnected: Date?

    // Legacy support - computed property for backwards compatibility
    var repositoryPath: String? {
        get { repositories.first?.path }
    }

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        user: String? = nil,
        port: Int? = nil,
        identityFile: String? = nil,
        repositories: [SavedRepository] = [],
        lastConnected: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.user = user
        self.port = port
        self.identityFile = identityFile
        self.repositories = repositories
        self.lastConnected = lastConnected
    }

    // Legacy initializer for backwards compatibility
    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        user: String? = nil,
        port: Int? = nil,
        identityFile: String? = nil,
        repositoryPath: String?,
        lastConnected: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.user = user
        self.port = port
        self.identityFile = identityFile
        if let path = repositoryPath {
            self.repositories = [SavedRepository(path: path)]
        } else {
            self.repositories = []
        }
        self.lastConnected = lastConnected
    }
}

// MARK: - Codable with migration support
extension Connection: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, host, user, port, identityFile, repositories, lastConnected
        case repositoryPath // Legacy key for migration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        host = try container.decode(String.self, forKey: .host)
        user = try container.decodeIfPresent(String.self, forKey: .user)
        port = try container.decodeIfPresent(Int.self, forKey: .port)
        identityFile = try container.decodeIfPresent(String.self, forKey: .identityFile)
        lastConnected = try container.decodeIfPresent(Date.self, forKey: .lastConnected)

        // Try to decode new format first, fall back to legacy format
        if let repos = try container.decodeIfPresent([SavedRepository].self, forKey: .repositories) {
            repositories = repos
        } else if let legacyPath = try container.decodeIfPresent(String.self, forKey: .repositoryPath) {
            // Migrate from old single repositoryPath format
            repositories = [SavedRepository(path: legacyPath)]
        } else {
            repositories = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(host, forKey: .host)
        try container.encodeIfPresent(user, forKey: .user)
        try container.encodeIfPresent(port, forKey: .port)
        try container.encodeIfPresent(identityFile, forKey: .identityFile)
        try container.encode(repositories, forKey: .repositories)
        try container.encodeIfPresent(lastConnected, forKey: .lastConnected)
    }

    /// Returns a new connection with a repository added
    func withRepository(_ repo: SavedRepository) -> Connection {
        var copy = self
        if !copy.repositories.contains(where: { $0.path == repo.path }) {
            copy.repositories.append(repo)
        }
        return copy
    }

    /// Returns a new connection with a repository removed
    func withoutRepository(_ repoId: UUID) -> Connection {
        var copy = self
        copy.repositories.removeAll { $0.id == repoId }
        return copy
    }

    /// Returns a new connection with the repository path set (legacy support)
    func withRepositoryPath(_ path: String) -> Connection {
        var copy = self
        let repo = SavedRepository(path: path, lastConnected: Date())
        if !copy.repositories.contains(where: { $0.path == path }) {
            copy.repositories.append(repo)
        }
        return copy
    }

    /// Returns a new connection with a repository's lastConnected timestamp updated
    func withRepositoryLastConnected(_ repoId: UUID) -> Connection {
        var copy = self
        if let index = copy.repositories.firstIndex(where: { $0.id == repoId }) {
            copy.repositories[index].lastConnected = Date()
        }
        return copy
    }

    /// Display string for the connection
    var displayHost: String {
        if let user = user {
            if let port = port, port != 22 {
                return "\(user)@\(host):\(port)"
            }
            return "\(user)@\(host)"
        }
        if let port = port, port != 22 {
            return "\(host):\(port)"
        }
        return host
    }

    /// Create an SSHConnection from this configuration
    func createSSHConnection() -> SSHConnection {
        SSHConnection(
            host: host,
            user: user,
            port: port,
            identityFile: identityFile
        )
    }
}

/// Storage for connections using UserDefaults
class ConnectionStorage: ObservableObject {
    @Published var connections: [Connection] = []

    private let storageKey = "SavedConnections"

    init() {
        loadConnections()
    }

    func loadConnections() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Connection].self, from: data) else {
            connections = []
            return
        }
        connections = decoded
    }

    func saveConnections() {
        guard let encoded = try? JSONEncoder().encode(connections) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    func addConnection(_ connection: Connection) {
        connections.append(connection)
        saveConnections()
    }

    func updateConnection(_ connection: Connection) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
            saveConnections()
        }
    }

    func removeConnection(_ connection: Connection) {
        connections.removeAll { $0.id == connection.id }
        saveConnections()
    }

    func removeConnections(at offsets: IndexSet) {
        connections.remove(atOffsets: offsets)
        saveConnections()
    }

    /// Returns all repositories across all connections, sorted by lastConnected (most recent first)
    var recentRepositories: [RecentRepository] {
        connections.flatMap { connection in
            connection.repositories.map { repo in
                RecentRepository(connection: connection, repository: repo)
            }
        }
        .sorted { ($0.repository.lastConnected ?? .distantPast) > ($1.repository.lastConnected ?? .distantPast) }
    }
}

/// Represents a repository with its parent connection for display in recent repos
struct RecentRepository: Identifiable {
    let connection: Connection
    let repository: SavedRepository

    var id: UUID { repository.id }
}
