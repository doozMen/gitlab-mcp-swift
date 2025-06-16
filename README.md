# GitLab MCP Server (Swift)

A Model Context Protocol (MCP) server that wraps the GitLab CLI (`glab`) to provide GitLab functionality to AI assistants like Claude Desktop.

## Features

- 🚀 **Native Swift implementation** using the official MCP Swift SDK
- 🔧 **Full GitLab CLI integration** - supports all `glab` commands
- 🎯 **Smart prompts** for common workflows (merge requests, CI/CD, daily standup)
- 📊 **JSON output parsing** with fallback to plain text
- 🔐 **Secure authentication** via system `glab` credentials
- ⚡ **High performance** with Swift's async/await concurrency

## Prerequisites

- macOS (Swift 5.9+ installed via Xcode)
- [glab CLI](https://gitlab.com/gitlab-org/cli) installed and authenticated
- Claude Desktop or another MCP-compatible client

## Installation

### Quick Install

```bash
# Clone the repository
git clone https://github.com/yourusername/gitlab-mcp-swift.git
cd gitlab-mcp-swift

# Run the install script
./install.sh
```

The install script will:
1. Build the server using Swift Package Manager
2. Install it to `~/.swiftpm/bin/git-lab-mcp`
3. Display the configuration for Claude Desktop

### Manual Installation

```bash
# Build the project
swift build -c release

# Install to a location in your PATH
cp .build/release/git-lab-mcp ~/.swiftpm/bin/
```

## Configuration

Add to your Claude Desktop configuration (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "gitlab": {
      "command": "/Users/YOUR_USERNAME/.swiftpm/bin/git-lab-mcp",
      "args": ["--log-level", "info"],
      "env": {
        "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
      }
    }
  }
}
```

## Authentication

The server uses your existing `glab` CLI authentication:

```bash
# Login to GitLab
glab auth login

# Check authentication status
glab auth status
```

## Available Tools

### Core Tools

- **`glab_mr`** - Merge request operations (list, create, view, merge, approve)
- **`glab_issue`** - Issue management (list, create, view, close, update)
- **`glab_ci`** - CI/CD pipeline operations (view, list, run, retry)
- **`glab_repo`** - Repository operations (clone, fork, view, archive)
- **`glab_api`** - Direct GitLab API access
- **`glab_auth`** - Authentication management
- **`glab_version`** - Version information
- **`glab_raw`** - Execute any glab command directly

### Prompts

The server includes intelligent prompts for common workflows:

- **`my-mrs`** - Check your merge requests
- **`create-mr`** - Create a merge request with guided parameters
- **`daily-standup`** - Gather GitLab activity for daily standups
- **`review-pipeline`** - Review CI/CD pipeline status

## Usage Examples

### Check Your Merge Requests
```
Use the prompt "my-mrs" to see all your open merge requests
```

### Create a Merge Request
```
Use the prompt "create-mr" with:
- title: "Fix: Memory leak in user service"
- source_branch: "fix/memory-leak"
- target_branch: "main"
```

### Run CI/CD Pipeline
```
Use tool "glab_ci" with:
- subcommand: "run"
- repo: "myteam/myproject"
```

## Development

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/gitlab-mcp-swift.git
cd gitlab-mcp-swift

# Build in debug mode
swift build

# Run tests
swift test

# Build for release
swift build -c release
```

### Project Structure

```
gitlab-mcp-swift/
├── Sources/
│   └── GitLabMCP/
│       ├── GitLabMCPServer.swift    # Main server implementation
│       ├── GitLabMCPCommand.swift   # CLI entry point
│       └── GitLabCLI.swift          # GitLab CLI wrapper
├── Package.swift                     # Swift package manifest
├── install.sh                        # Installation script
└── README.md                         # This file
```

## Troubleshooting

### Server fails to start
- Ensure `glab` is installed: `which glab`
- Check authentication: `glab auth status`
- Run with debug logging: `--log-level debug`

### Commands return "not authenticated"
- Run `glab auth login` to authenticate
- For self-hosted instances: `glab auth login --hostname your.gitlab.instance`

### MCP connection issues
- Restart Claude Desktop after configuration changes
- Check the logs in Claude Desktop's developer console
- Verify the executable path is correct in the configuration

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Built with the [Model Context Protocol Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)
- Wraps the excellent [GitLab CLI (glab)](https://gitlab.com/gitlab-org/cli)
- Inspired by the need for better GitLab integration in AI assistants