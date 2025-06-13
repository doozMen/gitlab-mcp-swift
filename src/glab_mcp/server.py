#!/usr/bin/env python3
"""
GitLab CLI MCP Server
A Model Context Protocol server that wraps the glab CLI tool.
"""

import asyncio
import json
import logging
import subprocess
import sys
from typing import Any, Dict, List, Optional, Sequence

import mcp.server.stdio
import mcp.types as types
from mcp.server import NotificationOptions, Server
from pydantic import AnyUrl

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("glab-mcp")

server = Server("glab-mcp")

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

@server.list_tools()
async def handle_list_tools() -> List[types.Tool]:
    """List available glab tools."""
    return [
        types.Tool(
            name="glab_auth_status",
            description="Check GitLab authentication status",
            inputSchema={
                "type": "object",
                "properties": {},
                "required": []
            }
        ),
        types.Tool(
            name="glab_repo_list",
            description="List GitLab repositories",
            inputSchema={
                "type": "object",
                "properties": {
                    "group": {"type": "string", "description": "Filter by group"},
                    "owned": {"type": "boolean", "description": "Show only owned repos"},
                    "starred": {"type": "boolean", "description": "Show only starred repos"},
                    "limit": {"type": "integer", "description": "Limit number of results"}
                },
                "required": []
            }
        ),
        types.Tool(
            name="glab_issue_list",
            description="List issues in a repository",
            inputSchema={
                "type": "object",
                "properties": {
                    "repo": {"type": "string", "description": "Repository (owner/name or URL)"},
                    "state": {"type": "string", "enum": ["opened", "closed", "all"], "description": "Issue state"},
                    "assignee": {"type": "string", "description": "Filter by assignee"},
                    "author": {"type": "string", "description": "Filter by author"},
                    "labels": {"type": "string", "description": "Filter by labels (comma-separated)"},
                    "milestone": {"type": "string", "description": "Filter by milestone"},
                    "limit": {"type": "integer", "description": "Limit number of results"}
                },
                "required": []
            }
        ),
        types.Tool(
            name="glab_issue_create",
            description="Create a new issue",
            inputSchema={
                "type": "object",
                "properties": {
                    "repo": {"type": "string", "description": "Repository (owner/name or URL)"},
                    "title": {"type": "string", "description": "Issue title"},
                    "description": {"type": "string", "description": "Issue description"},
                    "assignee": {"type": "string", "description": "Assignee username"},
                    "labels": {"type": "string", "description": "Labels (comma-separated)"},
                    "milestone": {"type": "string", "description": "Milestone"}
                },
                "required": ["title"]
            }
        ),
        types.Tool(
            name="glab_mr_list",
            description="List merge requests in a repository",
            inputSchema={
                "type": "object",
                "properties": {
                    "repo": {"type": "string", "description": "Repository (owner/name or URL)"},
                    "state": {"type": "string", "enum": ["opened", "closed", "merged", "all"], "description": "MR state"},
                    "author": {"type": "string", "description": "Filter by author"},
                    "assignee": {"type": "string", "description": "Filter by assignee"},
                    "reviewer": {"type": "string", "description": "Filter by reviewer"},
                    "labels": {"type": "string", "description": "Filter by labels (comma-separated)"},
                    "target_branch": {"type": "string", "description": "Filter by target branch"},
                    "source_branch": {"type": "string", "description": "Filter by source branch"},
                    "limit": {"type": "integer", "description": "Limit number of results"}
                },
                "required": []
            }
        ),
        types.Tool(
            name="glab_mr_create",
            description="Create a new merge request",
            inputSchema={
                "type": "object",
                "properties": {
                    "repo": {"type": "string", "description": "Repository (owner/name or URL)"},
                    "title": {"type": "string", "description": "MR title"},
                    "description": {"type": "string", "description": "MR description"},
                    "source_branch": {"type": "string", "description": "Source branch"},
                    "target_branch": {"type": "string", "description": "Target branch (default: main)"},
                    "assignee": {"type": "string", "description": "Assignee username"},
                    "reviewer": {"type": "string", "description": "Reviewer username"},
                    "labels": {"type": "string", "description": "Labels (comma-separated)"},
                    "milestone": {"type": "string", "description": "Milestone"},
                    "draft": {"type": "boolean", "description": "Create as draft MR"}
                },
                "required": ["title"]
            }
        ),
        types.Tool(
            name="glab_pipeline_list",
            description="List CI/CD pipelines",
            inputSchema={
                "type": "object",
                "properties": {
                    "repo": {"type": "string", "description": "Repository (owner/name or URL)"},
                    "status": {"type": "string", "enum": ["running", "pending", "success", "failed", "canceled", "skipped"], "description": "Pipeline status"},
                    "ref": {"type": "string", "description": "Filter by branch/tag"},
                    "limit": {"type": "integer", "description": "Limit number of results"}
                },
                "required": []
            }
        ),
        types.Tool(
            name="glab_project_info",
            description="Get project information",
            inputSchema={
                "type": "object",
                "properties": {
                    "repo": {"type": "string", "description": "Repository (owner/name or URL)"}
                },
                "required": []
            }
        ),
        types.Tool(
            name="glab_raw_command",
            description="Execute a raw glab command with custom arguments",
            inputSchema={
                "type": "object",
                "properties": {
                    "args": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Command arguments (without 'glab')"
                    },
                    "cwd": {"type": "string", "description": "Working directory"}
                },
                "required": ["args"]
            }
        )
    ]

@server.call_tool()
async def handle_call_tool(
    name: str, arguments: Dict[str, Any] | None
) -> List[types.TextContent]:
    """Handle tool calls."""
    if arguments is None:
        arguments = {}
    
    try:
        if name == "glab_auth_status":
            result = await run_glab_command(["auth", "status"])
            
        elif name == "glab_repo_list":
            args = ["repo", "list", "--format", "json"]
            if arguments.get("group"):
                args.extend(["--group", arguments["group"]])
            if arguments.get("owned"):
                args.append("--owned")
            if arguments.get("starred"):
                args.append("--starred")
            if arguments.get("limit"):
                args.extend(["--limit", str(arguments["limit"])])
            result = await run_glab_command(args)
            
        elif name == "glab_issue_list":
            args = ["issue", "list", "--format", "json"]
            if arguments.get("repo"):
                args.extend(["-R", arguments["repo"]])
            if arguments.get("state"):
                args.extend(["--state", arguments["state"]])
            if arguments.get("assignee"):
                args.extend(["--assignee", arguments["assignee"]])
            if arguments.get("author"):
                args.extend(["--author", arguments["author"]])
            if arguments.get("labels"):
                args.extend(["--labels", arguments["labels"]])
            if arguments.get("milestone"):
                args.extend(["--milestone", arguments["milestone"]])
            if arguments.get("limit"):
                args.extend(["--limit", str(arguments["limit"])])
            result = await run_glab_command(args)
            
        elif name == "glab_issue_create":
            args = ["issue", "create"]
            if arguments.get("repo"):
                args.extend(["-R", arguments["repo"]])
            args.extend(["--title", arguments["title"]])
            if arguments.get("description"):
                args.extend(["--description", arguments["description"]])
            if arguments.get("assignee"):
                args.extend(["--assignee", arguments["assignee"]])
            if arguments.get("labels"):
                args.extend(["--labels", arguments["labels"]])
            if arguments.get("milestone"):
                args.extend(["--milestone", arguments["milestone"]])
            result = await run_glab_command(args)
            
        elif name == "glab_mr_list":
            args = ["mr", "list", "--format", "json"]
            if arguments.get("repo"):
                args.extend(["-R", arguments["repo"]])
            if arguments.get("state"):
                args.extend(["--state", arguments["state"]])
            if arguments.get("author"):
                args.extend(["--author", arguments["author"]])
            if arguments.get("assignee"):
                args.extend(["--assignee", arguments["assignee"]])
            if arguments.get("reviewer"):
                args.extend(["--reviewer", arguments["reviewer"]])
            if arguments.get("labels"):
                args.extend(["--labels", arguments["labels"]])
            if arguments.get("target_branch"):
                args.extend(["--target-branch", arguments["target_branch"]])
            if arguments.get("source_branch"):
                args.extend(["--source-branch", arguments["source_branch"]])
            if arguments.get("limit"):
                args.extend(["--limit", str(arguments["limit"])])
            result = await run_glab_command(args)
            
        elif name == "glab_mr_create":
            args = ["mr", "create"]
            if arguments.get("repo"):
                args.extend(["-R", arguments["repo"]])
            args.extend(["--title", arguments["title"]])
            if arguments.get("description"):
                args.extend(["--description", arguments["description"]])
            if arguments.get("source_branch"):
                args.extend(["--source-branch", arguments["source_branch"]])
            if arguments.get("target_branch"):
                args.extend(["--target-branch", arguments["target_branch"]])
            if arguments.get("assignee"):
                args.extend(["--assignee", arguments["assignee"]])
            if arguments.get("reviewer"):
                args.extend(["--reviewer", arguments["reviewer"]])
            if arguments.get("labels"):
                args.extend(["--labels", arguments["labels"]])
            if arguments.get("milestone"):
                args.extend(["--milestone", arguments["milestone"]])
            if arguments.get("draft"):
                args.append("--draft")
            result = await run_glab_command(args)
            
        elif name == "glab_pipeline_list":
            args = ["pipeline", "list", "--format", "json"]
            if arguments.get("repo"):
                args.extend(["-R", arguments["repo"]])
            if arguments.get("status"):
                args.extend(["--status", arguments["status"]])
            if arguments.get("ref"):
                args.extend(["--ref", arguments["ref"]])
            if arguments.get("limit"):
                args.extend(["--limit", str(arguments["limit"])])
            result = await run_glab_command(args)
            
        elif name == "glab_project_info":
            args = ["repo", "view", "--format", "json"]
            if arguments.get("repo"):
                args.append(arguments["repo"])
            result = await run_glab_command(args)
            
        elif name == "glab_raw_command":
            result = await run_glab_command(
                arguments["args"], 
                arguments.get("cwd")
            )
            
        else:
            raise ValueError(f"Unknown tool: {name}")
        
        # Format the response
        if result["success"]:
            if "data" in result:
                # JSON data available
                response = f"Command executed successfully:\n\n"
                response += f"JSON Output:\n{json.dumps(result['data'], indent=2)}"
                if result["stderr"]:
                    response += f"\n\nWarnings/Info:\n{result['stderr']}"
            else:
                # Plain text output
                response = f"Command executed successfully:\n\n{result['stdout']}"
                if result["stderr"]:
                    response += f"\n\nWarnings/Info:\n{result['stderr']}"
        else:
            response = f"Command failed (exit code {result['returncode']}):\n\n"
            if result["stderr"]:
                response += f"Error: {result['stderr']}\n"
            if result["stdout"]:
                response += f"Output: {result['stdout']}\n"
            if "error" in result:
                response += f"Exception: {result['error']}"
        
        return [types.TextContent(type="text", text=response)]
        
    except Exception as e:
        logger.error(f"Error in tool {name}: {e}")
        return [types.TextContent(
            type="text", 
            text=f"Error executing {name}: {str(e)}"
        )]

def main():
    """Main entry point for the GitLab MCP server."""
    import os
    
    # Set up logging based on environment
    if os.getenv("GLAB_MCP_DEBUG"):
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        asyncio.run(run_server())
    except KeyboardInterrupt:
        logger.info("Server shutdown requested")
    except Exception as e:
        logger.error(f"Server error: {e}")
        sys.exit(1)

async def run_server():
    """Run the MCP server."""
    async with mcp.server.stdio.stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            NotificationOptions(),
        )

if __name__ == "__main__":
    main()