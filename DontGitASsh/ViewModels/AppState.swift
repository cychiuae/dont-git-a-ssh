import Foundation
import SwiftUI
import Combine

/// Global application state
@MainActor
class AppState: ObservableObject {
    @Published var connectionStorage = ConnectionStorage()
    @Published var openTabs: [RepositoryTab] = []
    @Published var selectedTabId: UUID?

    // Sheet states
    @Published var showNewConnectionSheet = false
    @Published var showCommitSheet = false
    @Published var showNewBranchSheet = false
    @Published var showSwitchBranchSheet = false
    @Published var showSSHConfigImportSheet = false

    // Selected tab's view model
    @Published private var viewModels: [UUID: RepositoryViewModel] = [:]

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Forward connectionStorage changes to AppState
        // Use async to avoid publishing during view updates
        connectionStorage.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    /// Subscribe to a view model's changes, deferring notifications to avoid view update conflicts
    private func observeViewModel(_ viewModel: RepositoryViewModel) {
        viewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    var selectedTab: RepositoryTab? {
        guard let id = selectedTabId else { return nil }
        return openTabs.first { $0.id == id }
    }

    var selectedViewModel: RepositoryViewModel? {
        guard let id = selectedTabId else { return nil }
        return viewModels[id]
    }

    func viewModel(for tabId: UUID) -> RepositoryViewModel? {
        return viewModels[tabId]
    }

    // MARK: - Tab Management

    func openConnection(_ connection: Connection) {
        // Check if already open
        if let existingTab = openTabs.first(where: { $0.connection.id == connection.id }) {
            selectedTabId = existingTab.id
            return
        }

        let tab = RepositoryTab(connection: connection)
        openTabs.append(tab)
        selectedTabId = tab.id

        // Create view model and start connecting
        let viewModel = RepositoryViewModel(connection: connection)
        viewModels[tab.id] = viewModel
        observeViewModel(viewModel)

        Task {
            await viewModel.connect()
        }
    }

    func closeTab(_ tabId: UUID) {
        openTabs.removeAll { $0.id == tabId }
        viewModels.removeValue(forKey: tabId)

        if selectedTabId == tabId {
            selectedTabId = openTabs.first?.id
        }
    }

    func closeCurrentTab() {
        guard let id = selectedTabId else { return }
        closeTab(id)
    }

    // MARK: - Repository Actions

    func refreshCurrentRepository() {
        guard let viewModel = selectedViewModel else { return }
        Task {
            await viewModel.refresh()
        }
    }

    func stageAll() {
        guard let viewModel = selectedViewModel else { return }
        Task {
            await viewModel.stageAll()
        }
    }

    func unstageAll() {
        guard let viewModel = selectedViewModel else { return }
        Task {
            await viewModel.unstageAll()
        }
    }

    // MARK: - Connection Management

    func saveConnection(_ connection: Connection) {
        if connectionStorage.connections.contains(where: { $0.id == connection.id }) {
            connectionStorage.updateConnection(connection)
        } else {
            connectionStorage.addConnection(connection)
        }
    }

    func deleteConnection(_ connection: Connection) {
        // Close any open tabs for this connection
        let tabsToClose = openTabs.filter { $0.connection.id == connection.id }
        for tab in tabsToClose {
            closeTab(tab.id)
        }
        connectionStorage.removeConnection(connection)
    }

    /// Update the repository path for a connection and save it
    func updateConnectionPath(_ connection: Connection, path: String) {
        let updated = connection.withRepositoryPath(path)
        connectionStorage.updateConnection(updated)

        // Update the tab's connection reference
        if let index = openTabs.firstIndex(where: { $0.connection.id == connection.id }) {
            openTabs[index] = RepositoryTab(connection: updated)
        }
    }

    // MARK: - Repository Management

    /// Open a specific repository under a connection
    func openRepository(connection: Connection, repository: SavedRepository) {
        // Update lastConnected timestamp for the repository
        let updatedConnection = connection.withRepositoryLastConnected(repository.id)
        connectionStorage.updateConnection(updatedConnection)

        // Create a connection instance with the specific repository path
        let connectionWithRepo = Connection(
            id: updatedConnection.id,
            name: updatedConnection.name,
            host: updatedConnection.host,
            user: updatedConnection.user,
            port: updatedConnection.port,
            identityFile: updatedConnection.identityFile,
            repositoryPath: repository.path,
            lastConnected: updatedConnection.lastConnected
        )

        // Check if this exact repo is already open
        if let existingTab = openTabs.first(where: {
            $0.connection.id == connection.id &&
            $0.connection.repositoryPath == repository.path
        }) {
            selectedTabId = existingTab.id
            return
        }

        let tab = RepositoryTab(connection: connectionWithRepo)
        openTabs.append(tab)
        selectedTabId = tab.id

        // Create view model and start connecting
        let viewModel = RepositoryViewModel(connection: connectionWithRepo)
        viewModels[tab.id] = viewModel
        observeViewModel(viewModel)

        Task {
            await viewModel.connect()
        }
    }

    /// Add a repository to a connection
    func addRepository(_ repository: SavedRepository, to connection: Connection) {
        let updated = connection.withRepository(repository)
        connectionStorage.updateConnection(updated)
    }

    /// Remove a repository from a connection
    func removeRepository(_ repository: SavedRepository, from connection: Connection) {
        // Close any open tabs for this repository
        let tabsToClose = openTabs.filter {
            $0.connection.id == connection.id &&
            $0.connection.repositoryPath == repository.path
        }
        for tab in tabsToClose {
            closeTab(tab.id)
        }

        let updated = connection.withoutRepository(repository.id)
        connectionStorage.updateConnection(updated)
    }
}
