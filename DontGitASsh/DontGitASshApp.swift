import SwiftUI

@main
struct DontGitASshApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Connection...") {
                    appState.showNewConnectionSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Repository") {
                Button("Refresh") {
                    appState.refreshCurrentRepository()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Stage All") {
                    appState.stageAll()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])

                Button("Unstage All") {
                    appState.unstageAll()
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])

                Divider()

                Button("Commit...") {
                    appState.showCommitSheet = true
                }
                .keyboardShortcut("k", modifiers: .command)
            }

            CommandMenu("Branch") {
                Button("New Branch...") {
                    appState.showNewBranchSheet = true
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Button("Switch Branch...") {
                    appState.showSwitchBranchSheet = true
                }
                .keyboardShortcut("b", modifiers: .command)
            }
        }

        Settings {
            PreferencesView()
                .environmentObject(appState)
        }
    }
}
