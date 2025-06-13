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
from mcp.server import NotificationOptions, Server

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("glab-mcp-dynamic")

server = Server("glab-mcp-dynamic")

# Cache for discovered commands
_command_cache: Optional[Dict[str, Any]] = None
_cache_timestamp: Optional[float] = None
CACHE_TTL = 300  # 5 minutes

async def run_glab_command(args: List[str], cwd: Optional[str] = None) -> Dict[str, Any]:
    """Execute a glab command and return the result."""
    try:
        cmd = ["glab"] + args
        logger.info(f"Running command: {' '.join(cmd)}")
        
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=cwd
        )
        
        stdout, stderr = await process.communicate()
        
        result = {
            "returncode": process.returncode,
            "stdout": stdout.decode('utf-8') if stdout else "",
            "stderr": stderr.decode('utf-8') if stderr else "",
            "success": process.returncode == 0
        }
        
        # Try to parse JSON output if it looks like JSON
        if result["success"] and result["stdout"].strip():
            try:
                if result["stdout"].strip().startswith(('[', '{')):
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
            "error": str(e)
        }

async def discover_glab_commands() -> Dict[str, Any]:
    """Dynamically discover all available glab commands and their help."""
    global _command_cache, _cache_timestamp
    
    # Check cache
    import time
    current_time = time.time()
    if (_command_cache is not None and _cache_timestamp is not None and 
        current_time - _cache_timestamp < CACHE_TTL):
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
    lines = help_text.split('\n')
    in_commands_section = False
    
    for line in lines:
        line = line.strip()
        
        if 'Available Commands:' in line or 'Commands:' in line:
            in_commands_section = True
            continue
            
        if in_commands_section and line == '':
            continue
            
        if in_commands_section and line.startswith('Flags:') or line.startswith('Global Flags:'):
            break
            
        if in_commands_section and line:
            # Parse command line: "  command    description"
            parts = line.split()
            if len(parts) >= 2 and not line.startswith(' '):
                command = parts[0]
                if command and not command.startswith('-'):
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
            "subcommands": []
        }
    
    help_text = help_result["stdout"]
    
    # Parse the help text
    description = ""
    usage = ""
    flags = []
    subcommands = []
    
    lines = help_text.split('\n')
    current_section = None
    
    for line in lines:
        line_stripped = line.strip()
        
        # Extract description (usually first non-empty line after command name)
        if not description and line_stripped and not line_stripped.startswith('Usage:'):
            if command in line_stripped.lower() or 'command' in line_stripped.lower():
                description = line_stripped
        
        # Extract usage
        if line_stripped.startswith('Usage:'):
            usage = line_stripped.replace('Usage:', '').strip()
            
        # Identify sections
        if line_stripped in ['Flags:', 'Options:', 'Global Flags:']:
            current_section = 'flags'
            continue
        elif line_stripped in ['Available Commands:', 'Commands:']:
            current_section = 'subcommands'
            continue
        elif line_stripped.startswith('Examples:') or line_stripped.startswith('Use "'):
            current_section = None
            continue
            
        # Parse flags
        if current_section == 'flags' and line.startswith('  '):
            flag_match = re.match(r'\s*(-\w|--[\w-]+)', line)
            if flag_match:
                flag_name = flag_match.group(1)
                flag_desc = line[flag_match.end():].strip()
                # Remove type hints like [string] or [int]
                flag_desc = re.sub(r'\s*\[[\w\s,]+\]', '', flag_desc)
                flags.append({
                    "name": flag_name,
                    "description": flag_desc
                })
        
        # Parse subcommands
        elif current_section == 'subcommands' and line.startswith('  '):
            sub_parts = line.strip().split()
            if sub_parts:
                subcommand = sub_parts[0]
                sub_desc = ' '.join(sub_parts[1:]) if len(sub_parts) > 1 else ""
                subcommands.append({
                    "name": subcommand,
                    "description": sub_desc
                })
    
    return {
        "name": command,
        "description": description or f"Execute glab {command} command",
        "usage": usage or f"glab {command}",
        "flags": flags,
        "subcommands": subcommands
    }

def create_dynamic_tool_schema(command_info: Dict[str, Any]) -> Dict[str, Any]:
    """Create a dynamic JSON schema for a glab command."""
    properties = {
        "args": {
            "type": "array",
            "items": {"type": "string"},
            "description": f"Command arguments for 'glab {command_info['name']}'"
        }
    }
    
    # Add common options
    if command_info.get("flags"):
        properties["common_flags"] = {
            "type": "object",
            "description": "Common flags (will be converted to CLI arguments)",
            "properties": {}
        }
        
        for flag in command_info["flags"]:
            flag_name = flag["name"].lstrip('-').replace('-', '_')
            properties["common_flags"]["properties"][flag_name] = {
                "type": "string",
                "description": flag["description"]
            }
    
    # Add subcommand selection
    if command_info.get("subcommands"):
        properties["subcommand"] = {
            "type": "string",
            "enum": [sub["name"] for sub in command_info["subcommands"]],
            "description": "Subcommand to execute"
        }
    
    properties["cwd"] = {
        "type": "string",
        "description": "Working directory for the command"
    }
    
    properties["format"] = {
        "type": "string",
        "enum": ["json", "table", "text"],
        "description": "Output format (if supported by the command)"
    }
    
    return {
        "type": "object",
        "properties": properties,
        "required": []
    }

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
                description="Execute any glab command with full argument control",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "args": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Complete command arguments (without 'glab')"
                        },
                        "cwd": {
                            "type": "string",
                            "description": "Working directory"
                        }
                    },
                    "required": ["args"]
                }
            )
        )
        
        # Add dynamic tools for each discovered command
        for cmd_name, cmd_info in commands.items():
            tool_name = f"glab_{cmd_name}".replace('-', '_')
            
            description = cmd_info.get("description", f"Execute glab {cmd_name}")
            if cmd_info.get("subcommands"):
                subcommand_names = [sub["name"] for sub in cmd_info["subcommands"]]
                description += f". Subcommands: {', '.join(subcommand_names)}"
            
            tools.append(
                types.Tool(
                    name=tool_name,
                    description=description,
                    inputSchema=create_dynamic_tool_schema(cmd_info)
                )
            )
        
        # Add help/discovery tools
        tools.append(
            types.Tool(
                name="glab_help",
                description="Get help for any glab command or subcommand",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "command": {
                            "type": "string",
                            "description": "Command to get help for (e.g., 'issue', 'mr create')"
                        }
                    },
                    "required": ["command"]
                }
            )
        )
        
        tools.append(
            types.Tool(
                name="glab_discover",
                description="Force re-discovery of available glab commands (clears cache)",
                inputSchema={
                    "type": "object",
                    "properties": {},
                    "required": []
                }
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
                            "description": "Command arguments"
                        }
                    },
                    "required": ["args"]
                }
            )
        ]

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
                cli_flag = "--" + flag_name.replace('_', '-')
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
            result = await run_glab_command(
                arguments["args"], 
                arguments.get("cwd")
            )
        
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
            return [types.TextContent(
                type="text", 
                text="✅ Glab commands re-discovered. Use glab_help to see available commands."
            )]
        
        elif name.startswith("glab_"):
            # Extract command name from tool name
            command = name[5:].replace('_', '-')  # Remove 'glab_' prefix
            
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
                response_parts.append(f"JSON Output:\n```json\n{json.dumps(result['data'], indent=2)}\n```")
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
            if result["stdout"]:
                response_parts.append(f"Output:\n```\n{result['stdout']}\n```")
            if "error" in result:
                response_parts.append(f"Exception: {result['error']}")
            
            response = "\n\n".join(response_parts)
        
        return [types.TextContent(type="text", text=response)]
        
    except Exception as e:
        logger.error(f"Error in tool {name}: {e}")
        return [types.TextContent(
            type="text", 
            text=f"❌ Error executing {name}: {str(e)}"
        )]

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
            NotificationOptions(),
        )

if __name__ == "__main__":
    asyncio.run(main())