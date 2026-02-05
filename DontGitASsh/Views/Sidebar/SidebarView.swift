import SwiftUI

/// Sidebar view showing connections and open repositories
struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            Section("Open Repositories") {
                ForEach(appState.openTabs) { tab in
                    OpenRepoRow(tab: tab)
                }
                .onDelete { offsets in
                    for offset in offsets {
                        appState.closeTab(appState.openTabs[offset].id)
                    }
                }
            }

            Section("Saved Connections") {
                ForEach(appState.connectionStorage.connections) { connection in
                    ConnectionDisclosureGroup(connection: connection)
                }
                .onDelete { offsets in
                    for offset in offsets {
                        let connection = appState.connectionStorage.connections[offset]
                        appState.deleteConnection(connection)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                Button {
                    appState.showNewConnectionSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add new connection")
            }
        }
    }
}

/// Disclosure group showing a connection with its repositories
struct ConnectionDisclosureGroup: View {
    let connection: Connection
    @EnvironmentObject var appState: AppState
    @State private var isExpanded = true
    @State private var isEditing = false
    @State private var showAddRepoSheet = false

    var hasOpenRepo: Bool {
        appState.openTabs.contains { $0.connection.id == connection.id }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(connection.repositories) { repo in
                SavedRepoRow(connection: connection, repository: repo)
            }
        } label: {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(hasOpenRepo ? .accentColor : .secondary)

                VStack(alignment: .leading) {
                    Text(connection.name)
                    Text(connection.displayHost)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if hasOpenRepo {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                }
            }
        }
        .contextMenu {
            Button("Add Repository...") {
                showAddRepoSheet = true
            }

            Button("Connect") {
                appState.openConnection(connection)
            }

            Divider()

            Button("Edit...") {
                isEditing = true
            }

            Button("Delete", role: .destructive) {
                appState.deleteConnection(connection)
            }
        }
        .sheet(isPresented: $isEditing) {
            EditConnectionSheet(connection: connection)
        }
        .sheet(isPresented: $showAddRepoSheet) {
            AddRepositorySheet(connection: connection)
        }
    }
}

/// Row for a saved repository under a connection
struct SavedRepoRow: View {
    let connection: Connection
    let repository: SavedRepository
    @EnvironmentObject var appState: AppState

    var isOpen: Bool {
        appState.openTabs.contains {
            $0.connection.id == connection.id &&
            $0.connection.repositoryPath == repository.path
        }
    }

    var body: some View {
        Button {
            appState.openRepository(connection: connection, repository: repository)
        } label: {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(isOpen ? .accentColor : .secondary)
                    .font(.system(size: 12))

                Text(repository.name)
                    .lineLimit(1)

                Spacer()

                if isOpen {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.green)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open") {
                appState.openRepository(connection: connection, repository: repository)
            }
            .disabled(isOpen)

            Divider()

            Button("Remove from Connection", role: .destructive) {
                appState.removeRepository(repository, from: connection)
            }
        }
    }
}

/// Row for an open repository tab
struct OpenRepoRow: View {
    let tab: RepositoryTab
    @EnvironmentObject var appState: AppState

    var viewModel: RepositoryViewModel? {
        appState.viewModel(for: tab.id)
    }

    var body: some View {
        Button {
            appState.selectedTabId = tab.id
        } label: {
            HStack {
                statusIcon

                VStack(alignment: .leading) {
                    if let vm = viewModel, let repoName = vm.repositoryName {
                        Text(repoName)
                            .fontWeight(appState.selectedTabId == tab.id ? .semibold : .regular)
                        Text(tab.connection.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(tab.connection.name)
                            .fontWeight(appState.selectedTabId == tab.id ? .semibold : .regular)
                        Text("No repository selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Close") {
                appState.closeTab(tab.id)
            }
        }
    }

    @ViewBuilder
    var statusIcon: some View {
        if let vm = viewModel {
            switch vm.state {
            case .connecting:
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            case .selectingRepository:
                Image(systemName: "folder.badge.questionmark")
                    .foregroundColor(.orange)
            case .connected:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
            case .disconnected:
                Image(systemName: "wifi.slash")
                    .foregroundColor(.secondary)
            }
        } else {
            Image(systemName: "circle")
                .foregroundColor(.secondary)
        }
    }
}

/// Sheet for adding a repository to a connection using remote file picker
struct AddRepositorySheet: View {
    let connection: Connection
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        RemoteFilePicker(connection: connection) { path in
            let repo = SavedRepository(path: path)
            appState.addRepository(repo, to: connection)
            dismiss()
        }
    }
}

/// Sheet for editing an existing connection
struct EditConnectionSheet: View {
    let connection: Connection
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ConnectionViewModel
    @Environment(\.dismiss) private var dismiss

    init(connection: Connection) {
        self.connection = connection
        _viewModel = StateObject(wrappedValue: ConnectionViewModel(connection: connection))
    }

    var body: some View {
        NavigationStack {
            ConnectionFormView(viewModel: viewModel)
                .navigationTitle("Edit Connection")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            appState.saveConnection(viewModel.toConnection())
                            dismiss()
                        }
                        .disabled(!viewModel.isValid)
                    }
                }
        }
        .frame(width: 450, height: 320)
    }
}

#Preview {
    SidebarView()
        .environmentObject(AppState())
        .frame(width: 250)
}
