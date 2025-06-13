#!/usr/bin/env python3
"""
Dynamic GitLab CLI MCP Server
A Model Context Protocol server that dynamically discovers and wraps glab CLI commands.
"""

import asyncio
import json
import logging
import re
import subprocess
import sys
from typing import Any, Dict, List, Optional, Set

import mcp.server.stdio
import mcp.types as types
from mcp.server import Server
from mcp.server.models import InitializationOptions
from mcp.types import ServerCapabilities

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("glab-mcp-dynamic")

server = Server("glab-mcp-dynamic")

# Cache for discovered commands
_command_cache: Optional[Dict[str, Any]] = None
_cache_timestamp: Optional[float] = None
CACHE_TTL = 300  # 5 minutes


async def run_glab_command(
    args: List[str], cwd: Optional[str] = None
) -> Dict[str, Any]:
    """Execute a glab command and return the result."""
    try:
        cmd = ["glab"] + args
        logger.info(f"Running command: {' '.join(cmd)}")

        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=cwd,
        )

        stdout, stderr = await process.communicate()

        result = {
            "returncode": process.returncode,
            "stdout": stdout.decode("utf-8") if stdout else "",
            "stderr": stderr.decode("utf-8") if stderr else "",
            "success": process.returncode == 0,
        }

        # Try to parse JSON output if it looks like JSON
        if result["success"] and result["stdout"].strip():
            try:
                if result["stdout"].strip().startswith(("[", "{")):
                    result["data"] = json.loads(result["stdout"])
            except json.JSONDecodeError:
                pass  # Keep as plain text

        return result

    except Exception as e:
        logger.error(f"Error running glab command: {e}")
        return {
            "returncode": -1,
            "stdout": "",
            "stderr": str(e),
            "success": False,
            "error": str(e),
        }


async def discover_glab_commands() -> Dict[str, Any]:
    """Dynamically discover all available glab commands and their help."""
    global _command_cache, _cache_timestamp

    # Check cache
    import time

    current_time = time.time()
    if (
        _command_cache is not None
        and _cache_timestamp is not None
        and current_time - _cache_timestamp < CACHE_TTL
    ):
        return _command_cache

    logger.info("Discovering glab commands...")

    # Get glab help
    help_result = await run_glab_command(["--help"])
    if not help_result["success"]:
        logger.error("Failed to get glab help")
        return {}

    commands = {}
    help_text = help_result["stdout"]

    # Parse available commands from help output
    # Look for "Available Commands:" section
    lines = help_text.split("\n")
    in_commands_section = False

    for line in lines:
        line = line.strip()

        if (
            "Available Commands:" in line
            or "Commands:" in line
            or "CORE COMMANDS" in line
        ):
            in_commands_section = True
            continue

        if in_commands_section and line == "":
            continue

        if in_commands_section and (
            line.startswith("FLAGS") or line.startswith("LEARN MORE")
        ):
            break

        if in_commands_section and line:
            # Parse command line: "  command:    description" or "  command    description"
            if ":" in line:
                parts = line.split(":", 1)
                if len(parts) == 2:
                    command = parts[0].strip()
                    if command and not command.startswith("-"):
                        # Get detailed help for this command
                        cmd_help = await get_command_help(command)
                        commands[command] = cmd_help

    # Cache the results
    _command_cache = commands
    _cache_timestamp = current_time

    logger.info(f"Discovered {len(commands)} glab commands")
    return commands


async def get_command_help(command: str) -> Dict[str, Any]:
    """Get detailed help for a specific glab command."""
    help_result = await run_glab_command([command, "--help"])

    if not help_result["success"]:
        return {
            "name": command,
            "description": f"Execute glab {command} command",
            "usage": f"glab {command}",
            "flags": [],
            "subcommands": [],
        }

    help_text = help_result["stdout"]

    # Parse the help text
    description = ""
    usage = ""
    flags = []
    subcommands = []

    lines = help_text.split("\n")
    current_section = None

    for line in lines:
        line_stripped = line.strip()

        # Extract description (usually first non-empty line after command name)
        if not description and line_stripped and not line_stripped.startswith("Usage:"):
            if command in line_stripped.lower() or "command" in line_stripped.lower():
                description = line_stripped

        # Extract usage
        if line_stripped.startswith("Usage:"):
            usage = line_stripped.replace("Usage:", "").strip()

        # Identify sections
        if line_stripped in ["Flags:", "Options:", "Global Flags:"]:
            current_section = "flags"
            continue
        elif line_stripped in ["Available Commands:", "Commands:"]:
            current_section = "subcommands"
            continue
        elif line_stripped.startswith("Examples:") or line_stripped.startswith('Use "'):
            current_section = None
            continue

        # Parse flags
        if current_section == "flags" and line.startswith("  "):
            flag_match = re.match(r"\s*(-\w|--[\w-]+)", line)
            if flag_match:
                flag_name = flag_match.group(1)
                flag_desc = line[flag_match.end() :].strip()
                # Remove type hints like [string] or [int]
                flag_desc = re.sub(r"\s*\[[\w\s,]+\]", "", flag_desc)
                flags.append({"name": flag_name, "description": flag_desc})

        # Parse subcommands
        elif current_section == "subcommands" and line.startswith("  "):
            sub_parts = line.strip().split()
            if sub_parts:
                subcommand = sub_parts[0]
                sub_desc = " ".join(sub_parts[1:]) if len(sub_parts) > 1 else ""
                subcommands.append({"name": subcommand, "description": sub_desc})

    return {
        "name": command,
        "description": description or f"Execute glab {command} command",
        "usage": usage or f"glab {command}",
        "flags": flags,
        "subcommands": subcommands,
    }


def create_dynamic_tool_schema(command_info: Dict[str, Any]) -> Dict[str, Any]:
    """Create a dynamic JSON schema for a glab command."""
    properties = {
        "args": {
            "type": "array",
            "items": {"type": "string"},
            "description": f"Additional arguments for 'glab {command_info['name']}'. Examples: ['123'] for MR number, ['--assignee=@me'] for filters",
        }
    }

    # Add common options
    if command_info.get("flags"):
        properties["common_flags"] = {
            "type": "object",
            "description": "Common flags (will be converted to CLI arguments). Example: {'assignee': '@me', 'label': 'bug'}",
            "properties": {},
        }

        for flag in command_info["flags"]:
            flag_name = flag["name"].lstrip("-").replace("-", "_")
            properties["common_flags"]["properties"][flag_name] = {
                "type": "string",
                "description": flag["description"],
            }

    # Add subcommand selection
    if command_info.get("subcommands"):
        subcommand_desc = "Subcommand to execute. Examples: "
        examples = []
        for sub in command_info["subcommands"][:3]:  # Show first 3 examples
            examples.append(f"'{sub['name']}' - {sub['description']}")
        subcommand_desc += ", ".join(examples)
        
        properties["subcommand"] = {
            "type": "string",
            "enum": [sub["name"] for sub in command_info["subcommands"]],
            "description": subcommand_desc,
        }

    properties["cwd"] = {
        "type": "string",
        "description": "Working directory (optional). Uses current directory if not specified",
    }

    properties["format"] = {
        "type": "string",
        "enum": ["json", "table", "text"],
        "description": "Output format (if supported). 'json' for structured data, 'table' for formatted tables, 'text' for plain text",
    }

    return {"type": "object", "properties": properties, "required": []}


@server.list_tools()
async def handle_list_tools() -> List[types.Tool]:
    """Dynamically list all available glab tools."""
    try:
        commands = await discover_glab_commands()
        tools = []

        # Add the raw command tool
        tools.append(
            types.Tool(
                name="glab_raw",
                description="Execute any glab command with full argument control. Use when you need precise control over command arguments. Example: args=['mr', 'list', '--assignee=@me', '--state=opened']",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "args": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Complete command arguments (without 'glab'). Example: ['mr', 'list', '--assignee=@me']",
                        },
                        "cwd": {"type": "string", "description": "Working directory (optional)"},
                    },
                    "required": ["args"],
                },
            )
        )

        # Add dynamic tools for each discovered command
        for cmd_name, cmd_info in commands.items():
            tool_name = f"glab_{cmd_name}".replace("-", "_")

            description = cmd_info.get("description", f"Execute glab {cmd_name}")
            
            # Add command-specific examples
            if cmd_name == "mr":
                description += ". Examples: List MRs with subcommand='list', Create MR with subcommand='create', View MR #123 with subcommand='view' args=['123']"
            elif cmd_name == "issue":
                description += ". Examples: List issues with subcommand='list', Create issue with subcommand='create', Close issue #45 with subcommand='close' args=['45']"
            elif cmd_name == "repo":
                description += ". Examples: Clone repo with subcommand='clone' args=['owner/repo'], Fork with subcommand='fork'"
            elif cmd_name == "ci":
                description += ". Examples: View pipelines with subcommand='view', List CI jobs with subcommand='list'"
            elif cmd_name == "api":
                description += ". Example: args=['GET', '/projects/:id/merge_requests'] to list MRs via API"
            
            if cmd_info.get("subcommands"):
                subcommand_names = [sub["name"] for sub in cmd_info["subcommands"][:5]]  # Show first 5
                if len(cmd_info["subcommands"]) > 5:
                    subcommand_names.append("...")
                description += f". Available: {', '.join(subcommand_names)}"

            tools.append(
                types.Tool(
                    name=tool_name,
                    description=description,
                    inputSchema=create_dynamic_tool_schema(cmd_info),
                )
            )

        # Add help/discovery tools
        tools.append(
            types.Tool(
                name="glab_help",
                description="Get detailed help for any glab command or subcommand. Shows available options, flags, and usage examples. Examples: command='mr' for merge request help, command='mr create' for creating MRs, command='issue list' for listing issues",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "command": {
                            "type": "string",
                            "description": "Command to get help for. Examples: 'mr', 'issue', 'mr create', 'repo clone'",
                        }
                    },
                    "required": ["command"],
                },
            )
        )

        tools.append(
            types.Tool(
                name="glab_discover",
                description="Force re-discovery of available glab commands (clears cache). Use this if you've updated glab or if commands seem outdated",
                inputSchema={"type": "object", "properties": {}, "required": []},
            )
        )
        
        # Add examples tool
        tools.append(
            types.Tool(
                name="glab_examples",
                description="Get common usage examples for GitLab operations. Shows practical examples of frequent tasks like creating MRs, managing issues, working with CI/CD, etc.",
                inputSchema={
                    "type": "object", 
                    "properties": {
                        "topic": {
                            "type": "string",
                            "enum": ["mr", "issue", "ci", "repo", "api", "general"],
                            "description": "Topic to get examples for. 'general' shows overview of common tasks"
                        }
                    },
                    "required": []
                },
            )
        )

        logger.info(f"Generated {len(tools)} dynamic tools")
        return tools

    except Exception as e:
        logger.error(f"Error generating tools: {e}")
        # Return minimal set on error
        return [
            types.Tool(
                name="glab_raw",
                description="Execute any glab command (fallback mode)",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "args": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Command arguments",
                        }
                    },
                    "required": ["args"],
                },
            )
        ]


def get_usage_examples(topic: str) -> str:
    """Get usage examples for common GitLab operations."""
    examples = {
        "general": """# GitLab MCP Tool Usage Examples

## Quick Start
The GitLab MCP provides tools for interacting with GitLab. Here are the most common patterns:

### Tool Naming Convention
- `glab_mr` - Work with merge requests
- `glab_issue` - Work with issues  
- `glab_ci` - Work with CI/CD pipelines
- `glab_repo` - Work with repositories
- `glab_raw` - Execute any glab command directly

### Basic Pattern
Most tools follow this pattern:
```
tool_name: glab_{resource}
parameters:
  subcommand: "{action}"  # like 'list', 'create', 'view'
  args: [...]            # additional arguments
  format: "json"         # optional: get structured output
```

## Common Tasks

1. **List your merge requests**
   - Tool: `glab_mr`
   - Parameters: `{"subcommand": "list", "args": ["--assignee=@me"]}`

2. **Create a new issue**
   - Tool: `glab_issue`
   - Parameters: `{"subcommand": "create", "args": ["--title", "Bug: Login fails"]}`

3. **View CI pipeline status**
   - Tool: `glab_ci`
   - Parameters: `{"subcommand": "view"}`

4. **Get help for any command**
   - Tool: `glab_help`
   - Parameters: `{"command": "mr create"}`

Use `glab_examples` with topic='mr', 'issue', 'ci', 'repo', or 'api' for specific examples.""",

        "mr": """# Merge Request Examples

## List Merge Requests
```
Tool: glab_mr
Parameters: {
  "subcommand": "list",
  "args": ["--assignee=@me", "--state=opened"],
  "format": "json"
}
```

## Create a Merge Request
```
Tool: glab_mr
Parameters: {
  "subcommand": "create",
  "args": ["--title", "Feature: Add dark mode", "--description", "Implements dark mode toggle"]
}
```

## View a Specific MR
```
Tool: glab_mr
Parameters: {
  "subcommand": "view", 
  "args": ["123"]  # MR number
}
```

## Approve an MR
```
Tool: glab_mr
Parameters: {
  "subcommand": "approve",
  "args": ["123"]
}
```

## Update MR Description
```
Tool: glab_mr
Parameters: {
  "subcommand": "update",
  "args": ["123", "--description", "Updated description here"]
}
```

## Add a Comment
```
Tool: glab_mr
Parameters: {
  "subcommand": "note",
  "args": ["123", "-m", "LGTM! Ready to merge."]
}
```""",

        "issue": """# Issue Examples

## List Issues
```
Tool: glab_issue
Parameters: {
  "subcommand": "list",
  "args": ["--assignee=@me", "--label=bug"],
  "format": "json"
}
```

## Create an Issue
```
Tool: glab_issue
Parameters: {
  "subcommand": "create",
  "args": ["--title", "Bug: Login timeout", "--label", "bug", "--assignee", "@me"]
}
```

## View Issue Details
```
Tool: glab_issue
Parameters: {
  "subcommand": "view",
  "args": ["45"]  # Issue number
}
```

## Close an Issue
```
Tool: glab_issue
Parameters: {
  "subcommand": "close",
  "args": ["45"]
}
```

## Add Issue Comment
```
Tool: glab_issue
Parameters: {
  "subcommand": "note", 
  "args": ["45", "-m", "Fixed in PR #123"]
}
```""",

        "ci": """# CI/CD Pipeline Examples

## View Current Pipeline
```
Tool: glab_ci
Parameters: {
  "subcommand": "view"
}
```

## List Recent Pipelines
```
Tool: glab_ci
Parameters: {
  "subcommand": "list",
  "format": "json"
}
```

## View Pipeline for Specific Branch
```
Tool: glab_ci
Parameters: {
  "subcommand": "view",
  "args": ["--branch", "feature/dark-mode"]
}
```

## Retry Failed Pipeline
```
Tool: glab_ci
Parameters: {
  "subcommand": "retry",
  "args": ["12345"]  # Pipeline ID
}
```

## View Job Logs
```
Tool: glab_job
Parameters: {
  "subcommand": "view",
  "args": ["--log", "987654"]  # Job ID
}
```""",

        "repo": """# Repository Examples

## Clone a Repository
```
Tool: glab_repo
Parameters: {
  "subcommand": "clone",
  "args": ["group/project"]
}
```

## Fork a Repository
```
Tool: glab_repo
Parameters: {
  "subcommand": "fork",
  "args": ["--clone"]
}
```

## View Repository Info
```
Tool: glab_repo
Parameters: {
  "subcommand": "view",
  "args": ["owner/repo"]
}
```

## List User Repositories
```
Tool: glab_repo
Parameters: {
  "subcommand": "list",
  "args": ["--mine"],
  "format": "json"
}
```

## Archive a Repository
```
Tool: glab_repo
Parameters: {
  "subcommand": "archive",
  "args": ["owner/repo", "--yes"]
}
```""",

        "api": """# GitLab API Examples

## List Project Merge Requests
```
Tool: glab_api
Parameters: {
  "args": ["GET", "/projects/:id/merge_requests", "--paginate"]
}
```

## Get User Info
```
Tool: glab_api
Parameters: {
  "args": ["GET", "/user"]
}
```

## Create a Project Label
```
Tool: glab_api
Parameters: {
  "args": ["POST", "/projects/:id/labels", "-f", "name=priority", "-f", "color=#FF0000"]
}
```

## Update Issue
```
Tool: glab_api
Parameters: {
  "args": ["PUT", "/projects/:id/issues/123", "-f", "state_event=close"]
}
```

## Raw API with Custom Headers
```
Tool: glab_raw
Parameters: {
  "args": ["api", "GET", "/projects", "--header", "X-Custom: value", "--paginate"]
}
```

Note: The API tool automatically handles authentication and pagination."""
    }
    
    return examples.get(topic, examples["general"])


def build_command_args(command: str, arguments: Dict[str, Any]) -> List[str]:
    """Build glab command arguments from tool arguments."""
    args = [command]

    # Add subcommand if specified
    if arguments.get("subcommand"):
        args.append(arguments["subcommand"])

    # Add custom args
    if arguments.get("args"):
        args.extend(arguments["args"])

    # Convert common flags
    if arguments.get("common_flags"):
        for flag_name, flag_value in arguments["common_flags"].items():
            if flag_value:  # Only add non-empty values
                cli_flag = "--" + flag_name.replace("_", "-")
                args.extend([cli_flag, str(flag_value)])

    # Add format flag if specified and not already present
    if arguments.get("format") and not any(arg.startswith("--format") for arg in args):
        args.extend(["--format", arguments["format"]])

    return args


@server.call_tool()
async def handle_call_tool(
    name: str, arguments: Dict[str, Any] | None
) -> List[types.TextContent]:
    """Handle dynamic tool calls."""
    if arguments is None:
        arguments = {}

    try:
        if name == "glab_raw":
            result = await run_glab_command(arguments["args"], arguments.get("cwd"))

        elif name == "glab_help":
            command = arguments["command"]
            # Split command into parts (e.g., "mr create" -> ["mr", "create"])
            cmd_parts = command.split()
            help_args = cmd_parts + ["--help"]
            result = await run_glab_command(help_args)

        elif name == "glab_discover":
            global _command_cache, _cache_timestamp
            _command_cache = None
            _cache_timestamp = None
            await discover_glab_commands()
            return [
                types.TextContent(
                    type="text",
                    text="✅ Glab commands re-discovered. Use glab_help to see available commands.",
                )
            ]
            
        elif name == "glab_examples":
            topic = arguments.get("topic", "general")
            examples = get_usage_examples(topic)
            return [
                types.TextContent(
                    type="text",
                    text=examples,
                )
            ]

        elif name.startswith("glab_"):
            # Extract command name from tool name
            command = name[5:].replace("_", "-")  # Remove 'glab_' prefix

            # Build command arguments
            cmd_args = build_command_args(command, arguments)

            result = await run_glab_command(cmd_args, arguments.get("cwd"))

        else:
            raise ValueError(f"Unknown tool: {name}")

        # Format response
        if result["success"]:
            response_parts = []

            if "data" in result:
                response_parts.append("✅ Command executed successfully")
                response_parts.append(
                    f"JSON Output:\n```json\n{json.dumps(result['data'], indent=2)}\n```"
                )
            elif result["stdout"]:
                response_parts.append("✅ Command executed successfully")
                response_parts.append(f"Output:\n```\n{result['stdout']}\n```")
            else:
                response_parts.append("✅ Command executed successfully (no output)")

            if result["stderr"]:
                response_parts.append(f"Warnings/Info:\n```\n{result['stderr']}\n```")

            response = "\n\n".join(response_parts)
        else:
            response_parts = [f"❌ Command failed (exit code {result['returncode']})"]

            if result["stderr"]:
                response_parts.append(f"Error:\n```\n{result['stderr']}\n```")
                
                # Add helpful suggestions based on common errors
                stderr_lower = result["stderr"].lower()
                if "authentication" in stderr_lower or "401" in stderr_lower:
                    response_parts.append("\n💡 **Tip**: This looks like an authentication issue. Try running `glab auth login` in your terminal.")
                elif "not found" in stderr_lower or "404" in stderr_lower:
                    response_parts.append("\n💡 **Tip**: The resource was not found. Check if the MR/issue number or repository name is correct.")
                elif "permission" in stderr_lower or "403" in stderr_lower:
                    response_parts.append("\n💡 **Tip**: You don't have permission to perform this action. Check your access rights.")
                elif "no repository" in stderr_lower:
                    response_parts.append("\n💡 **Tip**: Make sure you're in a Git repository or specify the repository with -R flag.")
                    
            if result["stdout"]:
                response_parts.append(f"Output:\n```\n{result['stdout']}\n```")
            if "error" in result:
                response_parts.append(f"Exception: {result['error']}")
                
            response_parts.append("\n📚 Use `glab_help` with the command name for usage details, or `glab_examples` for practical examples.")

            response = "\n\n".join(response_parts)

        return [types.TextContent(type="text", text=response)]

    except Exception as e:
        logger.error(f"Error in tool {name}: {e}")
        return [
            types.TextContent(type="text", text=f"❌ Error executing {name}: {str(e)}")
        ]


async def main():
    # Pre-warm the command cache
    try:
        await discover_glab_commands()
        logger.info("✅ Glab command discovery completed")
    except Exception as e:
        logger.warning(f"Initial command discovery failed: {e}")

    # Run the server using stdin/stdout streams
    async with mcp.server.stdio.stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="glab-mcp-dynamic",
                server_version="0.1.0",
                capabilities=ServerCapabilities(
                    tools={}  # We provide tools dynamically
                ),
            ),
        )


def run():
    """Entry point for the console script."""
    asyncio.run(main())


if __name__ == "__main__":
    run()
