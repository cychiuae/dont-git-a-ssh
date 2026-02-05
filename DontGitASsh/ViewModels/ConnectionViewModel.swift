import Foundation
import SwiftUI

/// View model for connection editing/creation
@MainActor
class ConnectionViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var host: String = ""
    @Published var user: String = ""
    @Published var port: String = ""
    @Published var identityFile: String = ""
    @Published var repositoryPath: String = ""

    @Published var isTestingConnection = false
    @Published var connectionTestResult: ConnectionTestResult?

    private var existingConnection: Connection?

    enum ConnectionTestResult {
        case success
        case failure(String)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }

        var message: String {
            switch self {
            case .success:
                return "Connection successful"
            case .failure(let error):
                return error
            }
        }
    }

    init(connection: Connection? = nil) {
        if let connection = connection {
            self.existingConnection = connection
            self.name = connection.name
            self.host = connection.host
            self.user = connection.user ?? ""
            self.port = connection.port.map { String($0) } ?? ""
            self.identityFile = connection.identityFile ?? ""
            self.repositoryPath = connection.repositoryPath ?? ""
        }
    }

    var isValid: Bool {
        !name.isEmpty && !host.isEmpty
    }

    func toConnection() -> Connection {
        // Preserve existing repositories when editing
        var repositories = existingConnection?.repositories ?? []

        // If there's a new repository path entered, add it
        if !repositoryPath.isEmpty {
            let repo = SavedRepository(path: repositoryPath)
            if !repositories.contains(where: { $0.path == repositoryPath }) {
                repositories.append(repo)
            }
        }

        return Connection(
            id: existingConnection?.id ?? UUID(),
            name: name,
            host: host,
            user: user.isEmpty ? nil : user,
            port: port.isEmpty ? nil : Int(port),
            identityFile: identityFile.isEmpty ? nil : identityFile,
            repositories: repositories,
            lastConnected: existingConnection?.lastConnected
        )
    }

    func testConnection() async {
        isTestingConnection = true
        connectionTestResult = nil

        let connection = toConnection()
        let sshConnection = connection.createSSHConnection()

        do {
            let connected = try await sshConnection.testConnection()
            if connected {
                connectionTestResult = .success
            } else {
                connectionTestResult = .failure("Connection failed")
            }
        } catch {
            connectionTestResult = .failure(error.localizedDescription)
        }

        isTestingConnection = false
    }
}
