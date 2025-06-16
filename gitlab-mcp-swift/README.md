# GitLab MCP Server (Swift)

A Model Context Protocol (MCP) server that wraps the `glab` CLI tool to provide GitLab functionality through AI assistants. This Swift implementation provides a clean, static interface to common GitLab operations.

## Features

- 🎯 **Static Tool Definitions** - 8 well-defined tools for common GitLab operations
- 🔧 **Full glab CLI Access** - Execute any glab command with the raw tool fallback
- 📝 **Type-Safe Parameters** - Structured parameter validation with clear schemas
- 🚀 **High Performance** - Built with Swift's actor-based concurrency
- 💡 **Smart Error Messages** - Helpful tips for common error scenarios
- 📊 **Version Tracking** - Shows both MCP server and glab CLI versions

## Prerequisites

- Swift 6.0 or later
- macOS 15.0 or later
- `glab` CLI installed and authenticated (`glab auth login`)

## Installation

### Quick Install

```bash
git clone <repository-url>
cd gitlab-mcp-swift
./install.sh
```

This will:
- Build the project in release mode
- Install to `~/.swiftpm/bin/git-lab-mcp`
- Show configuration for Claude Desktop

### Manual Build

```bash
swift build -c release
```

The executable will be at `.build/release/git-lab-mcp`

## Configuration for Claude Desktop

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "gitlab-swift": {
      "type": "stdio",
      "command": "/Users/YOUR_USERNAME/.swiftpm/bin/git-lab-mcp",
      "args": ["--log-level", "info"],
      "env": {
        "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
      }
    }
  }
}
```

## Available Tools

### 1. `glab_mr` - Merge Request Operations
Work with GitLab merge requests.

**Subcommands**: `list`, `create`, `view`, `merge`, `close`, `reopen`, `update`, `approve`, `revoke`, `diff`, `checkout`

**Example**:
```json
{
  "subcommand": "list",
  "args": ["--assignee=@me", "--state=opened"]
}
```

### 2. `glab_issue` - Issue Operations
Manage GitLab issues.

**Subcommands**: `list`, `create`, `view`, `close`, `reopen`, `update`, `delete`, `subscribe`, `unsubscribe`, `note`

**Example**:
```json
{
  "subcommand": "create",
  "args": ["--title", "Bug: Login timeout", "--label", "bug"]
}
```

### 3. `glab_ci` - CI/CD Operations
Work with pipelines and jobs.

**Subcommands**: `view`, `list`, `run`, `retry`, `delete`, `cancel`, `trace`, `artifact`

**Example**:
```json
{
  "subcommand": "view"
}
```

### 4. `glab_repo` - Repository Operations
Manage GitLab repositories.

**Subcommands**: `clone`, `fork`, `view`, `archive`, `unarchive`, `delete`, `create`, `list`, `mirror`, `contributors`

**Example**:
```json
{
  "subcommand": "clone",
  "args": ["owner/repo"]
}
```

### 5. `glab_api` - Direct API Access
Make authenticated GitLab API requests.

**Example**:
```json
{
  "method": "GET",
  "endpoint": "/projects/:id/merge_requests"
}
```

### 6. `glab_auth` - Authentication
Manage GitLab authentication.

**Subcommands**: `login`, `status`, `logout`

**Example**:
```json
{
  "subcommand": "status"
}
```

### 7. `glab_version` - Version Information
Shows both MCP server and glab CLI versions.

### 8. `glab_raw` - Raw Command Execution
Execute any glab command directly.

**Example**:
```json
{
  "args": ["config", "get", "editor"]
}
```

## Development

### Running in Development
```bash
swift run git-lab-mcp --log-level debug
```

### Running Tests
```bash
swift test
```

### Building for Release
```bash
swift build -c release
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes.

## Troubleshooting

1. **"subcommand is required" error**: Make sure you're passing the subcommand as a string parameter
2. **Authentication errors**: Run `glab auth login` in your terminal
3. **Command not found**: Ensure glab is in your PATH (add `/opt/homebrew/bin` if using Homebrew)
4. **No repository**: Use the `repo` parameter or run from within a Git repository

## Architecture

- **GitLabMCPServer** - Main server implementation with static tool definitions
- **GitLabCLI** - Handles glab command execution
- **Static Tools** - 8 predefined tools with explicit parameter schemas
- **Type Safety** - Uses MCP SDK's Value type for parameter handling

## License

[Your License Here]