import SwiftUI

/// Form view for connection configuration
struct ConnectionFormView: View {
    @ObservedObject var viewModel: ConnectionViewModel

    var body: some View {
        Form {
            Section("Connection") {
                TextField("Name", text: $viewModel.name)
                    .textContentType(.name)

                TextField("Host", text: $viewModel.host)
                    .textContentType(.URL)

                TextField("User (optional)", text: $viewModel.user)
                    .textContentType(.username)

                TextField("Port (optional)", text: $viewModel.port)
                    .textContentType(.none)

                TextField("Identity File (optional)", text: $viewModel.identityFile)
                    .textContentType(.none)
            }

            Section {
                HStack {
                    Button {
                        Task {
                            await viewModel.testConnection()
                        }
                    } label: {
                        if viewModel.isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Test Connection")
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isTestingConnection)

                    Spacer()

                    if let result = viewModel.connectionTestResult {
                        HStack {
                            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.isSuccess ? .green : .red)
                            Text(result.message)
                                .font(.caption)
                                .foregroundColor(result.isSuccess ? .green : .red)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// List view for managing all connections
struct ConnectionListView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedConnection: Connection?

    var body: some View {
        VStack {
            List(appState.connectionStorage.connections, selection: $selectedConnection) { connection in
                ConnectionListRow(connection: connection)
            }
            .contextMenu(forSelectionType: Connection.self) { connections in
                if let connection = connections.first {
                    Button("Connect") {
                        appState.openConnection(connection)
                    }

                    Divider()

                    Button("Delete", role: .destructive) {
                        appState.deleteConnection(connection)
                    }
                }
            } primaryAction: { connections in
                if let connection = connections.first {
                    appState.openConnection(connection)
                }
            }

            HStack {
                Button {
                    appState.showNewConnectionSheet = true
                } label: {
                    Image(systemName: "plus")
                }

                Button {
                    if let connection = selectedConnection {
                        appState.deleteConnection(connection)
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selectedConnection == nil)

                Spacer()
            }
            .padding(8)
        }
    }
}

struct ConnectionListRow: View {
    let connection: Connection
    @EnvironmentObject var appState: AppState

    var isOpen: Bool {
        appState.openTabs.contains { $0.connection.id == connection.id }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(connection.name)
                        .fontWeight(.medium)

                    if isOpen {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(connection.displayHost)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let path = connection.repositoryPath {
                    Text(path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let lastConnected = connection.lastConnected {
                Text(lastConnected, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ConnectionFormView(viewModel: ConnectionViewModel())
        .frame(width: 400, height: 400)
}
