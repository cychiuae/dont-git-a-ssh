# Don't Git a SSH

A native macOS Git GUI for managing Git repositories on remote machines via SSH.

<p >
  <img alt="logo" src="assets/banner.png" height="150" />
</p>

## Overview

Don't Git a SSH lets you interact with Git repositories on remote servers as if they were local. It connects via your system's `ssh` command, leveraging your existing SSH configs and ssh-agent for authentication.

**Key feature**: Hunk-level staging — select specific code chunks to include in your commits.

## Requirements

- macOS 14.0+ (Sonoma)
- Swift 5.9+
- Xcode 15+ (for building)

## Installation

### Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/dont-git-a-ssh.git
cd dont-git-a-ssh

# Build with Xcode
open DontGitASsh.xcodeproj

# Or build with Swift Package Manager
swift build -c release
```

## Features

- **SSH Connection Management** — Store and manage multiple SSH connections
- **Import SSH Config** — Import hosts from your `~/.ssh/config` file
- **Multi-tab Support** — Work with multiple repositories simultaneously
- **Hunk-level Staging** — Stage individual hunks or even specific lines
- **Branch Management** — Create, switch, and delete branches
- **Commit History** — View commit log with graph visualization
- **Stash Operations** — Save and restore work in progress
- **Remote Operations** — Fetch, pull, and push changes

## Usage

1. **Add a Connection** — Click the + button or press `Cmd+N` to add a new SSH connection
2. **Connect** — Select a connection and enter the path to a Git repository
3. **Work** — Stage changes, view diffs, and commit just like a local Git GUI

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+N` | New connection |
| `Cmd+R` | Refresh repository |
| `Cmd+Shift+A` | Stage all changes |
| `Cmd+Shift+U` | Unstage all changes |
| `Cmd+K` | Commit |
| `Cmd+B` | Switch branch |
| `Cmd+Shift+B` | Create new branch |

## Architecture

```
┌─────────────────────────────────────────┐
│            SwiftUI Views                │
├─────────────────────────────────────────┤
│          ViewModels/AppState            │
├─────────────────────────────────────────┤
│           Git Service Layer             │
├─────────────────────────────────────────┤
│          SSH Connection Layer           │
├─────────────────────────────────────────┤
│       System SSH (Process-based)        │
└─────────────────────────────────────────┘
```

The app uses your system's `/usr/bin/ssh` binary, so it automatically works with your existing SSH configuration, keys, and ssh-agent.

## Development

### Project Structure

```
DontGitASsh/
├── DontGitASshApp.swift     # App entry point
├── Models/                  # Data models
├── SSH/                     # SSH connection handling
├── Git/                     # Git operations & parsing
├── ViewModels/              # State management
└── Views/                   # SwiftUI views
```

### Running Tests

```bash
swift test
```

The test suite covers diff parsing, git status parsing, commit log parsing, branch parsing, hunk selection, and SSH config parsing.

## License

MIT License
