# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a GitLab CLI MCP (Model Context Protocol) Server that wraps the `glab` CLI tool to provide structured access to GitLab functionality through AI assistants.

## Common Development Commands

### Setup and Dependencies
```bash
# Install Python dependencies
pip install mcp pydantic

# Install development dependencies
pip install -e ".[dev]"

# Ensure glab CLI is installed and authenticated
glab auth status
```

### Code Quality and Testing
```bash
# Format code with Black
black glab_mcp_server.py

# Sort imports
isort glab_mcp_server.py

# Type checking
mypy glab_mcp_server.py

# Run tests
pytest

# Run async tests
pytest -s -v --asyncio-mode=auto
```

### Running the Server
```bash
# Make executable and run directly
chmod +x glab_mcp_server.py
python glab_mcp_server.py
```

## Architecture

### Core Components

1. **MCP Server Implementation** (`glab_mcp_server.py`)
   - Async Python server using `mcp.server.stdio`
   - Single entry point wrapping the glab CLI
   - JSON response parsing with fallback to plain text
   - Comprehensive error handling with exit codes and stderr capture

2. **Command Execution Pattern**
   - All GitLab operations go through `run_glab_command()` function
   - Commands are built with specific argument patterns for JSON output
   - Automatic detection and parsing of JSON responses
   - Repository context can be specified with `-R` flag

3. **Tool Structure**
   - Each tool corresponds to specific glab commands with structured schemas
   - Tools follow naming pattern: `glab_{resource}_{action}`
   - Input validation through Pydantic schemas
   - Optional parameters handled gracefully with default values

### GitLab Integration Points

- **Authentication**: Uses system glab authentication (`glab auth login`)
- **Repository Operations**: Can work with repos specified as `owner/name` or full URLs
- **JSON Output**: Most commands use `--format json` for structured responses
- **Filtering**: Comprehensive filtering options passed through to glab CLI

### Extension Pattern

To add new GitLab operations:
1. Add tool definition in `handle_list_tools()` with proper schema
2. Add command handling in `handle_call_tool()` following the pattern:
   - Build command args array
   - Map tool parameters to glab CLI flags
   - Use `--format json` where available
   - Return structured result with success/error info