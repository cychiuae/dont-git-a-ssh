import Foundation
import SwiftUI

/// Application preferences
class Preferences: ObservableObject {
    static let shared = Preferences()

    @AppStorage("diffViewMode") var diffViewMode: DiffViewMode = .unified
    @AppStorage("fontSize") var fontSize: Double = 12
    @AppStorage("showLineNumbers") var showLineNumbers: Bool = true
    @AppStorage("tabSize") var tabSize: Int = 4
    @AppStorage("wrapLines") var wrapLines: Bool = false
    @AppStorage("confirmBeforeCommit") var confirmBeforeCommit: Bool = true
    @AppStorage("autoRefreshInterval") var autoRefreshInterval: Int = 0 // 0 = disabled
    @AppStorage("defaultBranch") var defaultBranch: String = "main"

    private init() {}
}

/// Diff view display modes
enum DiffViewMode: String, CaseIterable, Codable {
    case unified = "unified"
    case sideBySide = "sideBySide"

    var displayName: String {
        switch self {
        case .unified:
            return "Unified"
        case .sideBySide:
            return "Side by Side"
        }
    }

    var icon: String {
        switch self {
        case .unified:
            return "text.alignleft"
        case .sideBySide:
            return "rectangle.split.2x1"
        }
    }
}
