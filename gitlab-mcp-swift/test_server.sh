#!/bin/bash

# Test script for GitLab MCP Swift server

echo "Testing GitLab MCP Swift Server..."

# Check if executable exists
if [ ! -f ".build/release/GitLabMCP" ]; then
    echo "Error: Executable not found. Please build with: swift build -c release"
    exit 1
fi

# Check if glab is installed
if ! command -v glab &> /dev/null; then
    echo "Error: glab CLI not found. Please install it first."
    exit 1
fi

# Run help test
echo "Testing help command..."
./.build/release/GitLabMCP --help

echo ""
echo "To use with Claude Desktop, add this to your claude_desktop_config.json:"
echo ""
echo '{'
echo '  "mcpServers": {'
echo '    "gitlab-swift": {'
echo '      "type": "stdio",'
echo '      "command": "'$(pwd)'/.build/release/GitLabMCP",'
echo '      "args": ["--log-level", "info"]'
echo '    }'
echo '  }'
echo '}'
echo ""