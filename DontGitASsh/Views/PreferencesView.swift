import SwiftUI

/// Application preferences view
struct PreferencesView: View {
    @ObservedObject var preferences = Preferences.shared

    var body: some View {
        TabView {
            GeneralPreferencesView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            EditorPreferencesView()
                .tabItem {
                    Label("Editor", systemImage: "text.alignleft")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralPreferencesView: View {
    @ObservedObject var preferences = Preferences.shared

    var body: some View {
        Form {
            Section {
                Picker("Default Branch", selection: $preferences.defaultBranch) {
                    Text("main").tag("main")
                    Text("master").tag("master")
                }

                Toggle("Confirm Before Commit", isOn: $preferences.confirmBeforeCommit)

                Picker("Auto Refresh", selection: $preferences.autoRefreshInterval) {
                    Text("Disabled").tag(0)
                    Text("Every 30 seconds").tag(30)
                    Text("Every minute").tag(60)
                    Text("Every 5 minutes").tag(300)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct EditorPreferencesView: View {
    @ObservedObject var preferences = Preferences.shared

    var body: some View {
        Form {
            Section("Diff View") {
                Picker("Default View Mode", selection: $preferences.diffViewMode) {
                    ForEach(DiffViewMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                Toggle("Show Line Numbers", isOn: $preferences.showLineNumbers)

                Toggle("Wrap Lines", isOn: $preferences.wrapLines)
            }

            Section("Font") {
                HStack {
                    Text("Font Size")
                    Slider(value: $preferences.fontSize, in: 10...18, step: 1)
                    Text("\(Int(preferences.fontSize)) pt")
                        .frame(width: 50)
                }

                Stepper("Tab Size: \(preferences.tabSize)", value: $preferences.tabSize, in: 2...8)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    PreferencesView()
}
