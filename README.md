# GitLab CLI MCP Server

A Model Context Protocol (MCP) server that provides seamless integration between AI assistants (like Claude) and GitLab through the `glab` CLI tool.

## Features

- 🔧 **Full GitLab Integration**: Access issues, merge requests, pipelines, and repositories
- 🤖 **AI-Friendly**: Structured JSON responses optimized for AI assistants
- 🛡️ **Secure**: Uses your existing `glab` authentication
- 🚀 **Fast**: Direct CLI wrapper with minimal overhead
- 📦 **Easy Setup**: Simple Python package installation

## Available Tools

### Repository Management
- `glab_repo_list` - List repositories with filtering options
- `glab_project_info` - Get detailed project information

### Issue Management
- `glab_issue_list` - List issues with comprehensive filtering
- `glab_issue_create` - Create new issues with full metadata

### Merge Request Management
- `glab_mr_list` - List merge requests with advanced filtering
- `glab_mr_create` - Create merge requests with all options

### CI/CD Pipeline Management
- `glab_pipeline_list` - List and filter CI/CD pipelines

### Authentication
- `glab_auth_status` - Check current authentication status

### Raw Command Access
- `glab_raw_command` - Execute any glab command directly

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