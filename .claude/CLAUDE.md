# Don't Git a SSH

A native macOS Git GUI for managing Git repositories on remote machines via SSH.

## Overview

**Target**: macOS 14.0+ (Sonoma)
**Language**: Swift 5.9+
**UI**: SwiftUI
**Build**: Swift Package Manager + Xcode project

The app connects to remote servers via the system's `ssh` command, leveraging existing SSH configs and ssh-agent. Key feature is **hunk-level staging** - selecting specific code chunks to commit.

## Architecture

```
┌─────────────────────────────────────────┐
│            SwiftUI Views                │
│  (MainView, SidebarView, DiffView...)   │
├─────────────────────────────────────────┤
│          ViewModels/AppState            │
│   (AppState, RepositoryViewModel)       │
├─────────────────────────────────────────┤
│           Git Service Layer             │
│  (GitRepository, DiffParser, etc.)      │
├─────────────────────────────────────────┤
│          SSH Connection Layer           │
│   (SSHConnection, RemoteExecutor)       │
├─────────────────────────────────────────┤
│       System SSH (Process-based)        │
└─────────────────────────────────────────┘
```

## Project Structure

```
DontGitASsh/
├── DontGitASshApp.swift    # App entry point with menu commands
├── Models/
│   ├── Connection.swift     # SSH connection config + storage
│   ├── Repository.swift     # RepositoryTab state model
│   └── Preferences.swift    # App preferences
├── SSH/
│   ├── SSHConnection.swift  # Actor-based SSH command execution
│   ├── RemoteExecutor.swift # Runs git commands on remote
│   └── SSHConfigParser.swift # Parses ~/.ssh/config files
├── Git/
│   ├── GitRepository.swift  # Main git operations interface
│   ├── GitCommit.swift      # Commit model + log parser
│   ├── GitBranch.swift      # Branch model + parser
│   ├── GitDiff.swift        # FileDiff model
│   ├── GitHunk.swift        # Hunk/line selection + patch generation
│   ├── GitStatus.swift      # Status model + parser
│   └── DiffParser.swift     # Parse git diff output
├── ViewModels/
│   ├── AppState.swift       # Global state, tab management
│   ├── ConnectionViewModel.swift
│   └── RepositoryViewModel.swift
└── Views/
    ├── MainView.swift       # Main window with NavigationSplitView
    ├── PreferencesView.swift
    ├── Sidebar/
    │   ├── SidebarView.swift          # Connection list + open repos
    │   ├── ConnectionListView.swift   # Connection form + list row
    │   └── SSHConfigImportView.swift  # Import from SSH config
    ├── Repository/
    │   ├── RepositoryView.swift       # Repo overview
    │   ├── CommitGraphView.swift      # Commit history
    │   └── CommitDetailView.swift     # Single commit details
    ├── Staging/
    │   ├── StagingView.swift          # Stage/unstage files
    │   ├── DiffView.swift             # File diff display
    │   └── HunkView.swift             # Hunk selection UI
    └── Branch/
        └── BranchView.swift           # Branch management
```

## Key Components

### SSHConnection (Actor)
- Executes commands via `/usr/bin/ssh`
- Supports custom port, identity file
- Has `execute(_:)` and `execute(_:input:)` for piping data

### GitRepository (Actor)
- Full git operations: status, log, diff, staging, branches, remotes, stash
- `stageHunks(patch:)` - Apply selected hunks to staging area
- `unstageHunks(patch:)` - Remove selected hunks from staging

### GitHunk
- `toPatch()` - Generate patch for entire hunk
- `toSelectivePatch()` - Generate patch for selected lines only

### AppState
- Manages open tabs (multiple connections)
- Connection storage via UserDefaults
- Sheet states for modals

## Build & Test

```bash
# Build with Xcode
open DontGitASsh.xcodeproj

# Build with SPM
swift build

# Run tests
swift test
```

Tests: 44 total (DiffParser, GitStatus, GitLog, GitBranch, HunkSelection, SSHConfigParser)

## Keyboard Shortcuts

- `Cmd+N` - New connection
- `Cmd+R` - Refresh repository
- `Cmd+Shift+A` - Stage all
- `Cmd+Shift+U` - Unstage all
- `Cmd+K` - Commit
- `Cmd+B` - Switch branch
- `Cmd+Shift+B` - New branch

## Features Implemented

- [x] SSH connection management
- [x] Import from ~/.ssh/config with file picker
- [x] Multi-tab support for multiple repositories
- [x] Git status parsing (porcelain v2)
- [x] Commit log with graph data
- [x] Diff parsing with hunk extraction
- [x] Hunk-level and line-level staging
- [x] Branch listing with tracking info
- [x] Branch create/switch/delete
- [x] Connection test functionality
- [x] Stash operations
- [x] Remote operations (fetch/pull/push)
