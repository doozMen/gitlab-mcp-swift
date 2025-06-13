# GitLab CLI MCP Server

A dynamic Model Context Protocol (MCP) server that provides seamless integration between AI assistants (like Claude) and GitLab through the `glab` CLI tool. This server automatically discovers all available `glab` commands and exposes them as tools.

## Features

- 🔄 **Dynamic Command Discovery**: Automatically discovers and exposes all `glab` commands
- 🔧 **Full GitLab Integration**: Access issues, merge requests, pipelines, repositories, and more
- 🤖 **AI-Friendly**: Structured JSON responses optimized for AI assistants
- 🛡️ **Secure**: Uses your existing `glab` authentication
- 🚀 **Fast**: Direct CLI wrapper with command caching
- 📦 **Easy Setup**: Simple Python package installation
- 🔍 **Self-Documenting**: Built-in help tool for exploring commands

## Available Tools

The server dynamically discovers and exposes all `glab` commands as tools. Common tools include:

- `glab_auth` - Manage authentication
- `glab_issue` - Work with issues
- `glab_mr` - Manage merge requests
- `glab_repo` - Work with repositories
- `glab_ci` - Manage CI/CD pipelines
- `glab_release` - Manage releases
- `glab_api` - Make authenticated API requests
- `glab_help` - Get detailed help for any command
- `glab_raw` - Execute any glab command with full control
- And many more...

### Special Tools

- `glab_discover` - Force re-discovery of available commands
- `glab_help` - Get detailed help for any glab command or subcommand

## Prerequisites

1. **Python 3.9+**
2. **GitLab CLI (`glab`)** installed and authenticated:
   ```bash
   # macOS
   brew install glab
   
   # Linux
   sudo snap install glab
   
   # Authenticate
   glab auth login
   ```

## Installation

### From PyPI (Recommended)

```bash
pip install glab-mcp-server
```

### From Source

```bash
git clone https://github.com/yourusername/glab-mcp
cd glab-mcp
pip install -e .
```

## Running the Server

**Important**: The MCP server must be running before it can be used by Claude or other AI assistants.

### Start the Server

After installation, run the server using the provided script:

```bash
python run_server.py
```

This will start the GitLab MCP server and keep it running. You should see output indicating the server is ready:

```
Starting GitLab MCP server...
Server is running. Press Ctrl+C to stop.
```

Keep this terminal window open while using the MCP with Claude.

### Alternative Methods

You can also run the server directly:

```bash
# If installed via pip
python -m glab_mcp

# If running from source
python src/glab_mcp/server.py
```

## Configuration

### Claude Desktop

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "glab": {
      "command": "python",
      "args": ["-m", "glab_mcp"],
      "env": {
        "PATH": "/usr/local/bin:/usr/bin:/bin"
      }
    }
  }
}
```

Or if you installed from source:

```json
{
  "mcpServers": {
    "glab": {
      "command": "python",
      "args": ["/path/to/glab-mcp/src/glab_mcp/server.py"]
    }
  }
}
```

### Claude CLI

For the Claude CLI (`claude`), add to your configuration:

```bash
# In your shell profile (.bashrc, .zshrc, etc.)
export CLAUDE_MCP_SERVERS='{"glab": {"command": "python", "args": ["-m", "glab_mcp"]}}'
```

## Usage Examples

Once configured, you can ask Claude to:

- "List all open issues in my GitLab project"
- "Create a new merge request for the feature branch"
- "Show me the failing pipelines"
- "Get information about the myorg/myproject repository"

## Development

### Setup Development Environment

```bash
# Clone the repository
git clone https://github.com/yourusername/glab-mcp
cd glab-mcp

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install in development mode
pip install -e ".[dev]"
```

### Running Tests

```bash
pytest
```

### Code Quality

```bash
# Format code
black src/

# Sort imports
isort src/

# Type checking
mypy src/
```

### Debug Mode

Enable debug logging:

```bash
export GLAB_MCP_DEBUG=1
```

## Troubleshooting

### Common Issues

1. **"glab not found" error**
   - Ensure `glab` is installed and in your PATH
   - Add the PATH to your MCP server configuration

2. **Authentication errors**
   - Run `glab auth status` to check authentication
   - Re-authenticate with `glab auth login`

3. **Permission errors**
   - Verify your GitLab token has the necessary permissions
   - Check repository access rights

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built on the [Model Context Protocol](https://github.com/anthropics/mcp)
- Powered by [GitLab CLI](https://gitlab.com/gitlab-org/cli)