import Foundation

/// Represents a connected git repository
struct Repository: Identifiable {
    let id: UUID
    let connection: Connection
    let path: String
    let name: String

    init(connection: Connection, path: String) {
        self.id = UUID()
        self.connection = connection
        self.path = path
        self.name = URL(fileURLWithPath: path).lastPathComponent
    }
}

/// State of a repository tab
enum RepositoryTabState {
    case connecting
    case selectingRepository  // Connected but needs to select a repository
    case connected
    case error(String)
    case disconnected
}

/// A tab representing an open repository
struct RepositoryTab: Identifiable {
    let id: UUID
    let connection: Connection
    var state: RepositoryTabState
    var repository: Repository?

    init(connection: Connection) {
        self.id = UUID()
        self.connection = connection
        self.state = .connecting
        self.repository = nil
    }
}
