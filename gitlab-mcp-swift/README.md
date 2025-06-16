# GitLab MCP Server (Swift)

A Model Context Protocol (MCP) server that wraps the `glab` CLI tool to provide dynamic GitLab functionality through AI assistants. This Swift implementation automatically discovers available glab commands and exposes them as MCP tools.

## Features

- 🚀 **Dynamic Command Discovery** - Automatically discovers all available glab commands and subcommands
- 🔧 **Full glab CLI Access** - Execute any glab command with full argument control
- 📝 **Smart Parameter Handling** - Intelligent parsing of command options and flags
- 🔄 **Caching** - Command discovery results are cached for performance
- 📚 **Built-in Help** - Access glab documentation directly through MCP tools
- 💡 **Usage Examples** - Get practical examples for common GitLab operations

## Prerequisites

- Swift 6.0 or later
- macOS 15.0 or later
- `glab` CLI installed and authenticated (`glab auth login`)

## Installation

### Option 1: System-wide Installation (Recommended)

1. Clone this repository:
```bash
git clone <repository-url>
cd gitlab-mcp-swift
```

2. Run the installation script:
```bash
./install.sh
```

This will:
- Build the project in release mode
- Remove any existing installation
- Install the executable to `/usr/local/bin` using `swift package experimental-install`
- Create a user-friendly symlink `gitlab-mcp`

To uninstall:
```bash
./uninstall.sh
```

### Option 2: Manual Build

1. Clone this repository:
```bash
git clone <repository-url>
cd gitlab-mcp-swift
```

2. Build the project:
```bash
swift build -c release
```

3. The executable will be at `.build/release/GitLabMCP`

### Option 3: Custom Installation Directory

Set the `INSTALL_DIR` environment variable:
```bash
INSTALL_DIR=~/bin ./install.sh
```

## Configuration for Claude Desktop

Add to your `claude_desktop_config.json`:

### If installed system-wide:
```json
{
  "mcpServers": {
    "gitlab-swift": {
      "type": "stdio",
      "command": "/usr/local/bin/gitlab-mcp",
      "args": ["--log-level", "info"]
    }
  }
}
```

### If using manual build:
```json
{
  "mcpServers": {
    "gitlab-swift": {
      "type": "stdio",
      "command": "/path/to/gitlab-mcp-swift/.build/release/GitLabMCP",
      "args": ["--log-level", "info"]
    }
  }
}
```

## Available Tools

The server dynamically discovers and exposes all glab commands as MCP tools:

### Core Tools

- `glab_raw` - Execute any glab command with full control
- `glab_help` - Get help for any glab command
- `glab_discover` - Force re-discovery of available commands
- `glab_examples` - Get usage examples for common operations

### Dynamic Tools (examples)

- `glab_mr` - Work with merge requests
- `glab_issue` - Manage issues
- `glab_ci` - Interact with CI/CD pipelines
- `glab_repo` - Repository operations
- `glab_api` - Direct GitLab API access

## Usage Examples

### List your merge requests
```
Tool: glab_mr
Parameters: {
  "subcommand": "list",
  "args": ["--assignee=@me"],
  "format": "json"
}
```

### Create an issue
```
Tool: glab_issue
Parameters: {
  "subcommand": "create",
  "args": ["--title", "Bug: Login fails", "--label", "bug"]
}
```

### View CI pipeline status
```
Tool: glab_ci
Parameters: {
  "subcommand": "view"
}
```

### Execute custom glab command
```
Tool: glab_raw
Parameters: {
  "args": ["api", "GET", "/user"],
  "format": "json"
}
```

## Development

### Running in development mode
```bash
swift run gitlab-mcp --log-level debug
```

### Running tests
```bash
swift test
```

## Architecture

- **GitLabCLI** - Handles subprocess execution and command discovery
- **GitLabMCPServer** - Implements the MCP protocol and tool generation
- **Dynamic Tool Discovery** - Parses glab help output to generate tools
- **Smart Caching** - Commands are cached for 5 minutes to improve performance

## Troubleshooting

1. **Authentication errors**: Run `glab auth login` in your terminal
2. **Command not found**: Ensure glab is installed and in your PATH
3. **Permission errors**: Check your GitLab access rights
4. **No repository**: Some commands require being in a git repository

## License

[Your License Here]