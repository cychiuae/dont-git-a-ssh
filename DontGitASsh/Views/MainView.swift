import SwiftUI

/// Main application view with four-column layout
/// Column 1: Connections (sidebar)
/// Column 2: Branches (always visible)
/// Column 3: Files/Commits (content based on tab)
/// Column 4: Detail (diff/commit detail)
struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var localSelectedTabId: UUID?
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            if appState.openTabs.isEmpty {
                WelcomeView()
            } else if let tab = appState.openTabs.first(where: { $0.id == localSelectedTabId }) ?? appState.openTabs.first {
                FourColumnContentView(tab: tab)
            }
        }
        .onChange(of: localSelectedTabId) { _, newValue in
            // Defer the update to avoid publishing during view updates
            DispatchQueue.main.async {
                appState.selectedTabId = newValue
            }
        }
        .onChange(of: appState.selectedTabId) { _, newValue in
            // Sync from appState to local (e.g., when sidebar changes selection)
            if localSelectedTabId != newValue {
                localSelectedTabId = newValue
            }
        }
        .onAppear {
            localSelectedTabId = appState.selectedTabId
        }
        .sheet(isPresented: $appState.showNewConnectionSheet) {
            NewConnectionSheet()
        }
        .sheet(isPresented: $appState.showCommitSheet) {
            CommitSheet()
        }
        .sheet(isPresented: $appState.showNewBranchSheet) {
            NewBranchSheet()
        }
        .sheet(isPresented: $appState.showSwitchBranchSheet) {
            SwitchBranchSheet()
        }
    }
}

/// Welcome view shown when no tabs are open
struct WelcomeView: View {
    @EnvironmentObject var appState: AppState

    var recentRepos: [RecentRepository] {
        Array(appState.connectionStorage.recentRepositories.prefix(5))
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Don't Git a SSH")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Connect to a remote repository to get started")
                .foregroundColor(.secondary)

            if appState.connectionStorage.connections.isEmpty {
                Button("Add Connection") {
                    appState.showNewConnectionSheet = true
                }
                .buttonStyle(.borderedProminent)
            } else if recentRepos.isEmpty {
                // Has connections but no repositories yet
                VStack(spacing: 12) {
                    Text("No recent repositories")
                        .foregroundColor(.secondary)
                    Text("Select a connection from the sidebar to browse repositories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Repositories")
                        .font(.headline)
                        .padding(.bottom, 4)

                    ForEach(recentRepos) { recent in
                        Button {
                            appState.openRepository(connection: recent.connection, repository: recent.repository)
                        } label: {
                            HStack {
                                Image(systemName: "folder.badge.gearshape")
                                VStack(alignment: .leading) {
                                    Text(recent.repository.name)
                                        .fontWeight(.medium)
                                    Text("\(recent.connection.name) • \(recent.repository.path)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Four-column content view using HSplitView for columns 2-4
struct FourColumnContentView: View {
    let tab: RepositoryTab
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if let viewModel = appState.viewModel(for: tab.id) {
                switch viewModel.state {
                case .selectingRepository:
                    SelectRepositoryView(connection: viewModel.connection) { path in
                        Task {
                            await viewModel.setRepositoryPath(path)
                            appState.updateConnectionPath(tab.connection, path: path)
                        }
                    }
                case .connected:
                    HSplitView {
                        // Column 2: Branches (always visible)
                        BranchSidebarView()
                            .environmentObject(viewModel)
                            .frame(minWidth: 180, idealWidth: 200, maxWidth: 280)

                        // Column 3: Files/Commits (content based on tab)
                        RepositoryContentView()
                            .environmentObject(viewModel)
                            .frame(minWidth: 250, idealWidth: 300)

                        // Column 4: Detail (diff/commit detail)
                        RepositoryDetailView()
                            .environmentObject(viewModel)
                            .frame(minWidth: 300)
                    }
                case .connecting:
                    VStack {
                        ProgressView()
                        Text("Connecting...")
                            .foregroundColor(.secondary)
                    }
                case .error(let message):
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Connection Error")
                            .font(.headline)
                        Text(message)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            Task {
                                await viewModel.connect()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .disconnected:
                    VStack {
                        Image(systemName: "wifi.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Disconnected")
                            .font(.headline)
                        Button("Reconnect") {
                            Task {
                                await viewModel.connect()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                VStack {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Persistent branch sidebar (column 2) - always visible
struct BranchSidebarView: View {
    @EnvironmentObject var viewModel: RepositoryViewModel
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var showRemoteBranches = false

    var filteredLocalBranches: [GitBranch] {
        let local = viewModel.branches.filter { !$0.isRemote }
        if searchText.isEmpty {
            return local
        }
        return local.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredRemoteBranches: [GitBranch] {
        let remote = viewModel.branches.filter { $0.isRemote }
        if searchText.isEmpty {
            return remote
        }
        return remote.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.branch")
                Text("Branches")
                    .fontWeight(.semibold)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            // Branch list
            List(selection: $viewModel.selectedBranch) {
                Section("Local") {
                    ForEach(filteredLocalBranches) { branch in
                        BranchSidebarRow(branch: branch)
                            .tag(branch)
                    }
                }

                if showRemoteBranches && !filteredRemoteBranches.isEmpty {
                    Section("Remote") {
                        ForEach(filteredRemoteBranches) { branch in
                            BranchSidebarRow(branch: branch)
                                .tag(branch)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Toolbar
            HStack {
                Button {
                    appState.showNewBranchSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("New branch")

                Button {
                    if let branch = viewModel.selectedBranch, !branch.isCurrent, !branch.isRemote {
                        Task {
                            await viewModel.deleteBranch(name: branch.name)
                        }
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.selectedBranch == nil || viewModel.selectedBranch?.isCurrent == true || viewModel.selectedBranch?.isRemote == true)
                .help("Delete branch")

                Spacer()

                Toggle(isOn: $showRemoteBranches) {
                    Image(systemName: "cloud")
                }
                .toggleStyle(.button)
                .buttonStyle(.borderless)
                .help("Show remote branches")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}

/// Compact branch row for the sidebar
struct BranchSidebarRow: View {
    let branch: GitBranch
    @EnvironmentObject var viewModel: RepositoryViewModel

    var body: some View {
        HStack(spacing: 6) {
            if branch.isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else if branch.isRemote {
                Image(systemName: "cloud")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.accentColor)
                    .font(.caption)
            }

            Text(branch.isRemote ? branch.shortName : branch.name)
                .fontWeight(branch.isCurrent ? .semibold : .regular)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .contextMenu {
            Button("Checkout") {
                Task {
                    await viewModel.checkout(branch: branch.name)
                }
            }
            .disabled(branch.isCurrent)

            if !branch.isRemote {
                Divider()

                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteBranch(name: branch.name)
                    }
                }
                .disabled(branch.isCurrent)
            }

            if branch.isRemote {
                Divider()

                Button("Create Local Branch") {
                    Task {
                        await viewModel.createBranch(
                            name: branch.shortName,
                            startPoint: branch.name
                        )
                    }
                }
            }
        }
    }
}

/// Content view (column 3) for a repository tab - shows file list or commits
struct RepositoryTabContentView: View {
    let tab: RepositoryTab
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if let viewModel = appState.viewModel(for: tab.id) {
                switch viewModel.state {
                case .selectingRepository:
                    Text("Select a repository")
                        .foregroundColor(.secondary)
                case .connected:
                    RepositoryContentView()
                        .environmentObject(viewModel)
                case .connecting:
                    VStack {
                        ProgressView()
                        Text("Connecting...")
                            .foregroundColor(.secondary)
                    }
                case .error:
                    Text("Connection error")
                        .foregroundColor(.secondary)
                case .disconnected:
                    Text("Disconnected")
                        .foregroundColor(.secondary)
                }
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
    }
}

/// Detail view (column 3) for a repository tab - shows diff, commit detail, or branch detail
struct RepositoryTabDetailView: View {
    let tab: RepositoryTab
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if let viewModel = appState.viewModel(for: tab.id) {
                switch viewModel.state {
                case .selectingRepository:
                    SelectRepositoryView(connection: viewModel.connection) { path in
                        Task {
                            await viewModel.setRepositoryPath(path)
                            appState.updateConnectionPath(tab.connection, path: path)
                        }
                    }
                case .connected:
                    RepositoryDetailView()
                        .environmentObject(viewModel)
                case .connecting:
                    VStack {
                        ProgressView()
                        Text("Connecting...")
                            .foregroundColor(.secondary)
                    }
                case .error(let message):
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Connection Error")
                            .font(.headline)
                        Text(message)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            Task {
                                await viewModel.connect()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .disconnected:
                    VStack {
                        Image(systemName: "wifi.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Disconnected")
                            .font(.headline)
                        Button("Reconnect") {
                            Task {
                                await viewModel.connect()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                VStack {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// View shown when user needs to select a repository
struct SelectRepositoryView: View {
    let connection: Connection
    let onSelect: (String) -> Void
    @State private var showFilePicker = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Select a Repository")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Connected to \(connection.displayHost)")
                .foregroundColor(.secondary)

            Text("Browse the remote server to select a git repository")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Browse Directories") {
                showFilePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showFilePicker) {
            RemoteFilePicker(connection: connection) { path in
                onSelect(path)
            }
        }
    }
}

/// Sheet for creating a new connection
struct NewConnectionSheet: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ConnectionViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showSSHConfigImport = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ConnectionFormView(viewModel: viewModel)

                Divider()

                // Import from SSH config option
                HStack {
                    Button {
                        showSSHConfigImport = true
                    } label: {
                        Label("Import from SSH Config", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("New Connection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") {
                        let connection = viewModel.toConnection()
                        appState.saveConnection(connection)
                        appState.openConnection(connection)
                        dismiss()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
        .frame(width: 450, height: 370)
        .sheet(isPresented: $showSSHConfigImport) {
            SSHConfigImportView {
                // Dismiss parent sheet after import
                dismiss()
            }
        }
    }
}

/// Sheet for committing changes
struct CommitSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let viewModel = appState.selectedViewModel {
                    Text("Staged Changes: \(viewModel.status?.stagedFiles.count ?? 0) files")
                        .foregroundColor(.secondary)

                    TextEditor(text: Binding(
                        get: { viewModel.commitMessage },
                        set: { viewModel.commitMessage = $0 }
                    ))
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100)
                    .border(Color.secondary.opacity(0.3))

                    Text("Write a brief description of your changes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Commit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Commit") {
                        if let viewModel = appState.selectedViewModel {
                            Task {
                                await viewModel.commit()
                                dismiss()
                            }
                        }
                    }
                    .disabled(appState.selectedViewModel?.commitMessage.isEmpty ?? true)
                }
            }
        }
        .frame(width: 500, height: 300)
    }
}

/// Sheet for creating a new branch
struct NewBranchSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var branchName = ""
    @State private var startPoint = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Branch Name", text: $branchName)

                TextField("Start Point (optional)", text: $startPoint)

                if let currentBranch = appState.selectedViewModel?.currentBranch {
                    Text("Current branch: \(currentBranch)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("New Branch")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if let viewModel = appState.selectedViewModel {
                            Task {
                                await viewModel.createBranch(
                                    name: branchName,
                                    startPoint: startPoint.isEmpty ? nil : startPoint
                                )
                                dismiss()
                            }
                        }
                    }
                    .disabled(branchName.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 200)
    }
}

/// Sheet for switching branches
struct SwitchBranchSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var filteredBranches: [GitBranch] {
        guard let branches = appState.selectedViewModel?.branches else { return [] }
        if searchText.isEmpty {
            return branches
        }
        return branches.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Search branches", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                List(filteredBranches) { branch in
                    Button {
                        if let viewModel = appState.selectedViewModel {
                            Task {
                                await viewModel.checkout(branch: branch.name)
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            if branch.isCurrent {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                            Text(branch.name)
                            Spacer()
                            if let tracking = branch.trackingBranch {
                                Text(tracking)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(branch.isCurrent)
                }
            }
            .navigationTitle("Switch Branch")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 400)
    }
}

#Preview {
    MainView()
        .environmentObject(AppState())
}
