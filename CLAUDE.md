# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a GitLab CLI MCP (Model Context Protocol) Server written in Swift that wraps the `glab` CLI tool to provide structured access to GitLab functionality through AI assistants.

## Common Development Commands

### Setup and Dependencies
```bash
# Install glab CLI (required)
brew install glab

# Authenticate with GitLab
glab auth login

# Check authentication status
glab auth status
```

### Code Quality and Testing
```bash
# Build in debug mode
swift build

# Run tests
swift test

# Build for release
swift build -c release

# Format code (if swift-format is installed)
swift-format -i Sources/**/*.swift
```

### Running the Server
```bash
# Run directly in debug mode
swift run git-lab-mcp --log-level debug

# Or use the built executable
.build/debug/git-lab-mcp --log-level debug
```

### Installation
```bash
# Use the install script
./install.sh

# Or manually install
swift build -c release
cp .build/release/git-lab-mcp ~/.swiftpm/bin/
```

## Architecture

### Core Components

1. **MCP Server Implementation** (`Sources/GitLabMCP/GitLabMCPServer.swift`)
   - Async Swift server using MCP Swift SDK
   - Single entry point wrapping the glab CLI
   - JSON response parsing with fallback to plain text
   - Comprehensive error handling with exit codes and stderr capture
   - Prompts support for guided workflows

2. **Command Execution Pattern**
   - All GitLab operations go through `GitLabCLI.runCommand()` function
   - Commands are built with specific argument patterns for JSON output
   - Automatic detection and parsing of JSON responses
   - Repository context can be specified with `-R` flag

3. **Tool Structure**
   - Static tool definitions for better type safety
   - Each tool corresponds to specific glab commands with structured schemas
   - Tools follow naming pattern: `glab_{resource}_{action}`
   - Input validation through Value types
   - Optional parameters handled gracefully with default values

### GitLab Integration Points

- **Authentication**: Uses system glab authentication (`glab auth login`)
- **Repository Operations**: Can work with repos specified as `owner/name` or full URLs
- **JSON Output**: Most commands use `--format json` for structured responses
- **Filtering**: Comprehensive filtering options passed through to glab CLI

### Extension Pattern

To add new GitLab operations:
1. Add tool definition in `getStaticTools()` with proper schema
2. Add command handling in `handleToolCall()` following the pattern:
   - Build command args array
   - Map tool parameters to glab CLI flags
   - Use `--format json` where available
   - Return structured result with success/error info
3. Update version in GitLabMCPCommand.swift and server initialization
4. Document the new tool in README.md

## Version Management

When creating a new version:
1. Update version in `Sources/GitLabMCP/GitLabMCPCommand.swift`
2. Update version in `Sources/GitLabMCP/GitLabMCPServer.swift` (server init and handleVersion)
3. Update `CHANGELOG.md` with version notes
4. Run `./install.sh` to build and install
5. Commit with message format: `feat: Add [feature] - v[version]`

## Important Instructions

- ALWAYS use the TodoWrite and TodoRead tools when working on features
- Test changes by running the server with debug logging
- Ensure glab CLI is authenticated before testing
- Follow Swift naming conventions and style
- Keep error messages helpful with actionable suggestions
- Remember that this wraps the glab CLI - we don't implement GitLab API directly