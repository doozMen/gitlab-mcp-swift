import MCP
import Logging
import Foundation

actor GitLabMCPServer {
    private let server: Server
    private let gitlabCLI: GitLabCLI
    private let logger: Logger
    
    init(logger: Logger) throws {
        self.logger = logger
        self.gitlabCLI = GitLabCLI(logger: logger)
        
        self.server = Server(
            name: "glab-mcp-dynamic",
            version: "0.1.1",
            capabilities: .init(
                prompts: nil,
                resources: nil,
                tools: .init(listChanged: false)
            )
        )
        
        Task {
            await setupHandlers()
        }
    }
    
    func start() async throws {
        let transport = StdioTransport(logger: logger)
        try await server.start(transport: transport)
        logger.info("GitLab MCP Server started")
        
        // Keep the server running
        await server.waitUntilCompleted()
    }
    
    private func setupHandlers() async {
        // List Tools Handler
        await server.withMethodHandler(ListTools.self) { [weak self] _ in
            guard let self = self else {
                throw MCPError.internalError("Server unavailable")
            }
            
            return try await self.generateTools()
        }
        
        // Call Tool Handler
        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self = self else {
                throw MCPError.internalError("Server unavailable")
            }
            
            return try await self.handleToolCall(name: params.name, arguments: params.arguments)
        }
    }
    
    private func generateTools() async throws -> ListTools.Result {
        var tools: [Tool] = []
        
        // Add the raw command tool
        tools.append(Tool(
            name: "glab_raw",
            description: "Execute any glab command with full argument control. Use when you need precise control over command arguments. Example: args=['mr', 'list', '--assignee=@me', '--state=opened']",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "args": .object([
                        "type": .string("array"),
                        "items": .object(["type": .string("string")]),
                        "description": .string("Complete command arguments (without 'glab'). Example: ['mr', 'list', '--assignee=@me']")
                    ]),
                    "cwd": .object([
                        "type": .string("string"),
                        "description": .string("Working directory (optional)")
                    ])
                ]),
                "required": .array([.string("args")])
            ])
        ))
        
        // Discover and add dynamic tools
        do {
            let commands = try await gitlabCLI.discoverCommands()
            
            for (cmdName, cmdInfo) in commands {
                let toolName = "glab_\(cmdName.replacingOccurrences(of: "-", with: "_"))"
                var description = cmdInfo.description
                
                // Add command-specific examples
                switch cmdName {
                case "mr":
                    description += ". Examples: List MRs with subcommand='list', Create MR with subcommand='create', View MR #123 with subcommand='view' args=['123']"
                case "issue":
                    description += ". Examples: List issues with subcommand='list', Create issue with subcommand='create', Close issue #45 with subcommand='close' args=['45']"
                case "repo":
                    description += ". Examples: Clone repo with subcommand='clone' args=['owner/repo'], Fork with subcommand='fork'"
                case "ci":
                    description += ". Examples: View pipelines with subcommand='view', List CI jobs with subcommand='list'"
                case "api":
                    description += ". Example: args=['GET', '/projects/:id/merge_requests'] to list MRs via API"
                default:
                    break
                }
                
                if !cmdInfo.subcommands.isEmpty {
                    let subcommandNames = cmdInfo.subcommands.prefix(5).map { $0.name }
                    description += ". Available: \(subcommandNames.joined(separator: ", "))"
                    if cmdInfo.subcommands.count > 5 {
                        description += "..."
                    }
                }
                
                let schema = createDynamicToolSchema(for: cmdInfo)
                tools.append(Tool(
                    name: toolName,
                    description: description,
                    inputSchema: try convertToValue(schema)
                ))
            }
        } catch {
            logger.error("Failed to discover commands: \(error)")
        }
        
        // Add help and discovery tools
        tools.append(Tool(
            name: "glab_help",
            description: "Get detailed help for any glab command or subcommand. Shows available options, flags, and usage examples. Examples: command='mr' for merge request help, command='mr create' for creating MRs",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "command": .object([
                        "type": .string("string"),
                        "description": .string("Command to get help for. Examples: 'mr', 'issue', 'mr create'")
                    ])
                ]),
                "required": .array([.string("command")])
            ])
        ))
        
        tools.append(Tool(
            name: "glab_discover",
            description: "Force re-discovery of available glab commands (clears cache). Use this if you've updated glab or if commands seem outdated",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
                "required": .array([])
            ])
        ))
        
        tools.append(Tool(
            name: "glab_examples",
            description: "Get common usage examples for GitLab operations. Shows practical examples of frequent tasks",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "topic": .object([
                        "type": .string("string"),
                        "enum": .array([.string("mr"), .string("issue"), .string("ci"), .string("repo"), .string("api"), .string("general")]),
                        "description": .string("Topic to get examples for. 'general' shows overview of common tasks")
                    ])
                ]),
                "required": .array([])
            ])
        ))
        
        logger.info("Generated \(tools.count) dynamic tools")
        return ListTools.Result(tools: tools)
    }
    
    private func convertToValue(_ object: Any) throws -> Value {
        if let dict = object as? [String: Any] {
            var result: [String: Value] = [:]
            for (key, value) in dict {
                result[key] = try convertToValue(value)
            }
            return .object(result)
        } else if let array = object as? [Any] {
            return .array(try array.map { try convertToValue($0) })
        } else if let string = object as? String {
            return .string(string)
        } else if let number = object as? Int {
            return .int(number)
        } else if let number = object as? Double {
            return .double(number)
        } else if let bool = object as? Bool {
            return .bool(bool)
        } else if object is NSNull {
            return .null
        } else {
            throw MCPError.internalError("Cannot convert value: \(object)")
        }
    }
    
    private func createDynamicToolSchema(for command: GitLabCommand) -> [String: Any] {
        var properties: [String: Any] = [
            "args": [
                "type": "array",
                "items": ["type": "string"],
                "description": "Additional arguments for 'glab \(command.name)'. Examples: ['123'] for MR number, ['--assignee=@me'] for filters"
            ]
        ]
        
        // Add common flags
        if !command.flags.isEmpty {
            var flagProperties: [String: Any] = [:]
            
            for flag in command.flags {
                let flagName = flag.name
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
                    .replacingOccurrences(of: "-", with: "_")
                
                flagProperties[flagName] = [
                    "type": "string",
                    "description": flag.description
                ]
            }
            
            properties["common_flags"] = [
                "type": "object",
                "description": "Common flags (will be converted to CLI arguments). Example: {'assignee': '@me', 'label': 'bug'}",
                "properties": flagProperties
            ]
        }
        
        // Add subcommand selection
        if !command.subcommands.isEmpty {
            var subcommandDesc = "Subcommand to execute. Examples: "
            let examples = command.subcommands.prefix(3).map { "'\($0.name)' - \($0.description)" }
            subcommandDesc += examples.joined(separator: ", ")
            
            properties["subcommand"] = [
                "type": "string",
                "enum": command.subcommands.map { $0.name },
                "description": subcommandDesc
            ]
        }
        
        properties["cwd"] = [
            "type": "string",
            "description": "Working directory (optional). Uses current directory if not specified"
        ]
        
        properties["format"] = [
            "type": "string",
            "enum": ["json", "table", "text"],
            "description": "Output format (if supported). 'json' for structured data"
        ]
        
        return [
            "type": "object",
            "properties": properties,
            "required": []
        ]
    }
    
    private func handleToolCall(name: String, arguments: [String: Any]?) async throws -> CallTool.Result {
        let args = arguments ?? [:]
        
        // Debug logging
        logger.debug("Tool call: \(name)")
        logger.debug("Arguments: \(args)")
        
        switch name {
        case "glab_raw":
            guard let cmdArgs = args["args"] as? [String] else {
                logger.error("Failed to get args array from: \(args)")
                throw MCPError.invalidParams("args array is required")
            }
            let result = try await gitlabCLI.runCommand(args: cmdArgs, cwd: args["cwd"] as? String)
            return formatResult(result)
            
        case "glab_help":
            guard let command = args["command"] as? String else {
                throw MCPError.invalidParams("command is required")
            }
            let cmdParts = command.split(separator: " ").map(String.init)
            let helpArgs = cmdParts + ["--help"]
            let result = try await gitlabCLI.runCommand(args: helpArgs)
            return formatResult(result)
            
        case "glab_discover":
            await gitlabCLI.clearCache()
            _ = try await gitlabCLI.discoverCommands()
            return CallTool.Result(
                content: [.text("✅ Glab commands re-discovered. Use glab_help to see available commands.")],
                isError: false
            )
            
        case "glab_examples":
            let topic = args["topic"] as? String ?? "general"
            let examples = getUsageExamples(for: topic)
            return CallTool.Result(
                content: [.text(examples)],
                isError: false
            )
            
        default:
            if name.hasPrefix("glab_") {
                // Extract command name from tool name
                let command = String(name.dropFirst(5)).replacingOccurrences(of: "_", with: "-")
                let cmdArgs = buildCommandArgs(command: command, arguments: args)
                logger.debug("Final command args: \(cmdArgs)")
                let result = try await gitlabCLI.runCommand(args: cmdArgs, cwd: args["cwd"] as? String)
                return formatResult(result)
            } else {
                throw MCPError.methodNotFound("Unknown tool: \(name)")
            }
        }
    }
    
    private func buildCommandArgs(command: String, arguments: [String: Any]) -> [String] {
        var args = [command]
        
        // Add subcommand if specified
        if let subcommand = arguments["subcommand"] as? String {
            args.append(subcommand)
        }
        
        // Add custom args
        if let customArgs = arguments["args"] as? [String] {
            // Commands that don't have subcommands (they just take arguments directly)
            let noSubcommandCommands = ["version", "help", "check-update", "changelog", "completion", "alias", "duo"]
            
            // For most commands, if no explicit subcommand was provided and args has elements,
            // check if the first arg looks like a subcommand (not starting with -)
            if arguments["subcommand"] == nil && 
               !customArgs.isEmpty && 
               !customArgs[0].hasPrefix("-") &&
               !noSubcommandCommands.contains(command) {
                // First arg is likely a subcommand
                args.append(customArgs[0])
                args.append(contentsOf: Array(customArgs.dropFirst()))
            } else {
                args.append(contentsOf: customArgs)
            }
        }
        
        // Convert common flags
        if let commonFlags = arguments["common_flags"] as? [String: Any] {
            for (flagName, flagValue) in commonFlags {
                if let value = flagValue as? String, !value.isEmpty {
                    let cliFlag = "--" + flagName.replacingOccurrences(of: "_", with: "-")
                    args.append(contentsOf: [cliFlag, value])
                }
            }
        }
        
        // Add format flag if specified and not already present
        if let format = arguments["format"] as? String,
           !args.contains(where: { $0.hasPrefix("--format") }) {
            args.append(contentsOf: ["--format", format])
        }
        
        return args
    }
    
    private func formatResult(_ result: CommandResult) -> CallTool.Result {
        var response = ""
        
        if result.success {
            if let dataString = result.dataString {
                response += "✅ Command executed successfully\n\n"
                response += "JSON Output:\n```json\n\(dataString)\n```"
            } else if !result.stdout.isEmpty {
                response += "✅ Command executed successfully\n\n"
                response += "Output:\n```\n\(result.stdout)\n```"
            } else {
                response += "✅ Command executed successfully (no output)"
            }
            
            if !result.stderr.isEmpty {
                response += "\n\nWarnings/Info:\n```\n\(result.stderr)\n```"
            }
        } else {
            response += "❌ Command failed (exit code \(result.returnCode))"
            
            if !result.stderr.isEmpty {
                response += "\n\nError:\n```\n\(result.stderr)\n```"
                
                // Add helpful suggestions based on common errors
                let stderrLower = result.stderr.lowercased()
                if stderrLower.contains("authentication") || stderrLower.contains("401") {
                    response += "\n\n💡 **Tip**: This looks like an authentication issue. Try running `glab auth login` in your terminal."
                } else if stderrLower.contains("not found") || stderrLower.contains("404") {
                    response += "\n\n💡 **Tip**: The resource was not found. Check if the MR/issue number or repository name is correct."
                } else if stderrLower.contains("permission") || stderrLower.contains("403") {
                    response += "\n\n💡 **Tip**: You don't have permission to perform this action. Check your access rights."
                } else if stderrLower.contains("no repository") {
                    response += "\n\n💡 **Tip**: Make sure you're in a Git repository or specify the repository with -R flag."
                }
            }
            
            if !result.stdout.isEmpty {
                response += "\n\nOutput:\n```\n\(result.stdout)\n```"
            }
            
            response += "\n\n📚 Use `glab_help` with the command name for usage details, or `glab_examples` for practical examples."
        }
        
        return CallTool.Result(
            content: [.text(response)],
            isError: !result.success
        )
    }
    
    private func getUsageExamples(for topic: String) -> String {
        switch topic {
        case "general":
            return """
# GitLab MCP Tool Usage Examples

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
"""
            
        case "mr":
            return """
# Merge Request Examples

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

## Update MR Description
```
Tool: glab_mr
Parameters: {
  "subcommand": "update",
  "args": ["123", "--description", "Updated description here"]
}
```
"""
            
        case "issue":
            return """
# Issue Examples

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

## Close an Issue
```
Tool: glab_issue
Parameters: {
  "subcommand": "close",
  "args": ["45"]
}
```
"""
            
        default:
            return "Topic '\(topic)' not found. Available topics: general, mr, issue, ci, repo, api"
        }
    }
}