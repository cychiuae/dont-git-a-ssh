import SwiftUI
import UniformTypeIdentifiers

/// View for importing connections from ~/.ssh/config
struct SSHConfigImportView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var onImport: (() -> Void)?

    @State private var hosts: [SSHConfigHost] = []
    @State private var selectedHosts: Set<UUID> = []
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var configNotFound = false
    @State private var showFilePicker = false

    init(onImport: (() -> Void)? = nil) {
        self.onImport = onImport
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Import from SSH Config")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if isLoading {
                Spacer()
                ProgressView("Loading SSH config...")
                Spacer()
            } else if configNotFound {
                // Config file not found - show browse option
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "doc.questionmark")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("SSH config file not found at ~/.ssh/config")
                        .foregroundColor(.secondary)
                    Button("Browse for Config File...") {
                        showFilePicker = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                    Button("Browse for Config File...") {
                        showFilePicker = true
                    }
                }
                Spacer()
            } else if hosts.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No hosts found in SSH config")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                // Host list
                List(hosts, selection: $selectedHosts) { host in
                    SSHConfigHostRow(host: host)
                        .tag(host.id)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))

                Divider()

                // Footer with import button
                HStack {
                    Text("\(selectedHosts.count) selected")
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Import Selected") {
                        importSelectedHosts()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedHosts.isEmpty)
                }
                .padding()
            }
        }
        .frame(width: 550, height: 450)
        .task {
            await loadDefaultConfig()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.plainText, .data, UTType(filenameExtension: "config") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    loadHosts(from: url.path)
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadDefaultConfig() async {
        let defaultPath = SSHConfigParser.defaultConfigPath

        // Check if file exists
        if !FileManager.default.fileExists(atPath: defaultPath) {
            configNotFound = true
            isLoading = false
            return
        }

        loadHosts(from: defaultPath)
    }

    private func loadHosts(from path: String) {
        isLoading = true
        errorMessage = nil
        configNotFound = false
        hosts = []
        selectedHosts = []

        do {
            let parsedHosts = try SSHConfigParser.parse(at: path)
            // Filter out wildcard patterns
            hosts = parsedHosts.filter { !$0.isPattern }
            if hosts.isEmpty {
                errorMessage = "No hosts found in config file"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func importSelectedHosts() {
        for hostId in selectedHosts {
            guard let host = hosts.first(where: { $0.id == hostId }) else {
                continue
            }

            let connection = Connection(
                name: host.name,
                host: host.effectiveHostName,
                user: host.user,
                port: host.port,
                identityFile: host.identityFile
            )

            appState.saveConnection(connection)
        }

        dismiss()
        onImport?()
    }
}

struct SSHConfigHostRow: View {
    let host: SSHConfigHost

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(host.name)
                    .fontWeight(.medium)

                Text(host.displayString)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let identityFile = host.identityFile {
                    Text("Key: \(identityFile)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SSHConfigImportView()
        .environmentObject(AppState())
}
