# Changelog

All notable changes to the GitLab MCP Swift server will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2025-06-16

### Added
- **Prompts support** for common GitLab workflows:
  - `my-mrs` - Check user's merge requests with authentication context
  - `create-mr` - Create merge requests with guided parameters
  - `daily-standup` - Gather GitLab activity for daily standup
  - `review-pipeline` - Check CI/CD pipeline status
- Enhanced tool descriptions with concrete examples
- Tool annotations for better AI guidance
- Authentication context in tool descriptions

### Changed
- Improved tool descriptions with specific examples
- Version command now mentions current authentication
- Better guidance for AI assistants on how to use each tool

### Developer Notes
- Implemented ListPrompts and GetPrompt handlers
- Added prompts capability to server initialization
- Version tracking now consistent across all components

## [0.2.1] - 2025-06-16

### Fixed
- Fixed parameter handling to use MCP SDK's `Value` type instead of `Any`
- Fixed "subcommand is required" and "args array is required" errors
- Added proper pattern matching for extracting values from MCP Value types
- Added `stringValue` helper extension on Value type for convenience

### Changed
- Updated all handler methods to work with `[String: Value]` parameters
- Improved error messages with proper type handling

## [0.2.0] - 2025-06-16

### Changed
- **BREAKING**: Complete refactor from dynamic to static tool definitions
- Removed dynamic command discovery in favor of hardcoded tools
- Simplified architecture by removing unnecessary abstractions
- Changed from `glab-mcp-dynamic` to `gitlab-mcp-swift` server name

### Added
- 8 static, well-defined tools:
  - `glab_mr` - Merge request operations
  - `glab_issue` - Issue operations
  - `glab_ci` - CI/CD operations
  - `glab_repo` - Repository operations
  - `glab_api` - Direct API calls
  - `glab_auth` - Authentication management
  - `glab_version` - Version information
  - `glab_raw` - Raw command execution fallback
- Explicit subcommand enums for better type safety
- Structured parameter validation

### Removed
- Dynamic command discovery logic
- Command caching mechanism
- `GitLabCommand` struct and related models
- Complex command parsing logic

## [0.1.3] - 2025-06-16

### Fixed
- Fixed `glab_version` to show both MCP server version and glab CLI version

### Added
- Special handling for `glab_version` command
- Build date information in version output

## [0.1.2] - 2025-06-16

### Fixed
- Fixed command argument handling for subcommands
- Added debug logging to trace argument processing

### Added
- Debug logging for custom args processing
- Detection of subcommands vs flags in arguments

## [0.1.1] - 2025-06-16

### Fixed
- Fixed subcommand detection in `buildCommandArgs`
- Commands now properly execute instead of showing help text

### Added
- List of commands that don't use subcommands
- Improved argument parsing logic

## [0.1.0] - 2025-06-16

### Added
- Initial Swift implementation of GitLab MCP server
- Dynamic tool discovery from glab CLI
- Command caching with 5-minute TTL
- Actor-based concurrency for thread safety
- JSON response parsing with fallback to plain text
- Comprehensive error handling
- Support for all glab CLI commands
- Special tools: `glab_help`, `glab_discover`, `glab_examples`
- Installation script using SwiftPM experimental-install
- Claude Desktop configuration support

### Technical Details
- Built with Swift MCP SDK
- Uses ArgumentParser for CLI interface
- Sendable conformance for thread-safe data types
- StdioTransport for JSON-RPC communication
- Structured logging with swift-log

## [Unreleased] - Python Version

### Initial Python Implementation
- Basic wrapper around glab CLI
- Simple command execution
- Limited error handling
- No dynamic discovery

---

## Migration Guide

### From Python to Swift (0.1.0)
1. Remove Python MCP server from claude_desktop_config.json
2. Install Swift version using `./install.sh`
3. Update configuration to use new executable path

### From Dynamic to Static (0.2.0)
1. Tools now have explicit subcommand parameters
2. No more automatic discovery - tools are predefined
3. Better parameter validation and error messages
4. Simplified codebase for easier maintenance

### Fixing Parameter Issues (0.2.1)
1. No user-facing changes required
2. Parameters now properly handled internally
3. Same API structure as 0.2.0