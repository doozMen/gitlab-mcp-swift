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
            name: "gitlab-mcp-swift",
            version: "0.3.0",
            capabilities: .init(
                prompts: .init(listChanged: false),
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
            
            return await self.getStaticTools()
        }
        
        // Call Tool Handler
        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self = self else {
                throw MCPError.internalError("Server unavailable")
            }
            
            return try await self.handleToolCall(name: params.name, arguments: params.arguments)
        }
        
        // List Prompts Handler
        await server.withMethodHandler(ListPrompts.self) { [weak self] _ in
            guard let self = self else {
                throw MCPError.internalError("Server unavailable")
            }
            
            return await self.getPrompts()
        }
        
        // Get Prompt Handler
        await server.withMethodHandler(GetPrompt.self) { [weak self] params in
            guard let self = self else {
                throw MCPError.internalError("Server unavailable")
            }
            
            return try await self.getPrompt(name: params.name, arguments: params.arguments)
        }
    }
    
    private func getStaticTools() -> ListTools.Result {
        let tools: [Tool] = [
            // Merge Request operations
            Tool(
                name: "glab_mr",
                description: """
                Work with GitLab merge requests at Mediahuis (authenticated as stijn.willems).
                Examples:
                - List your MRs: subcommand="list", args=["--assignee=@me"]
                - View MR #123: subcommand="view", args=["123"]
                - Create MR: subcommand="create", args=["--title", "Fix: Memory leak", "--source-branch", "fix/memory"]
                - List MRs for repo: subcommand="list", args=["--repo", "team/project"]
                """,
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "subcommand": .object([
                            "type": .string("string"),
                            "enum": .array([.string("list"), .string("create"), .string("view"), .string("merge"), .string("close"), .string("reopen"), .string("update"), .string("approve"), .string("revoke"), .string("diff"), .string("checkout")]),
                            "description": .string("The merge request operation to perform")
                        ]),
                        "args": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Additional arguments like MR number, flags, etc. Example: ['123'] for MR #123, or ['--assignee=@me', '--state=opened'] for filters")
                        ]),
                        "repo": .object([
                            "type": .string("string"),
                            "description": .string("Repository in OWNER/REPO format (optional, uses current repo if not specified)")
                        ])
                    ]),
                    "required": .array([.string("subcommand")])
                ]),
                annotations: .init(
                    title: "GitLab Merge Requests",
                    readOnlyHint: false,
                    destructiveHint: false,
                    idempotentHint: false
                )
            ),
            
            // Issue operations
            Tool(
                name: "glab_issue",
                description: "Work with GitLab issues. Common operations: list (list issues), create (create new issue), view (view issue details), close (close an issue)",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "subcommand": .object([
                            "type": .string("string"),
                            "enum": .array([.string("list"), .string("create"), .string("view"), .string("close"), .string("reopen"), .string("update"), .string("delete"), .string("subscribe"), .string("unsubscribe"), .string("note")]),
                            "description": .string("The issue operation to perform")
                        ]),
                        "args": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Additional arguments like issue number, flags, etc.")
                        ]),
                        "repo": .object([
                            "type": .string("string"),
                            "description": .string("Repository in OWNER/REPO format (optional)")
                        ])
                    ]),
                    "required": .array([.string("subcommand")])
                ])
            ),
            
            // CI/CD operations
            Tool(
                name: "glab_ci",
                description: "Work with GitLab CI/CD pipelines and jobs. Common operations: view (view pipeline status), list (list pipelines), run (trigger pipeline), retry (retry failed pipeline)",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "subcommand": .object([
                            "type": .string("string"),
                            "enum": .array([.string("view"), .string("list"), .string("run"), .string("retry"), .string("delete"), .string("cancel"), .string("trace"), .string("artifact")]),
                            "description": .string("The CI/CD operation to perform")
                        ]),
                        "args": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Additional arguments like pipeline ID, job ID, flags, etc.")
                        ]),
                        "repo": .object([
                            "type": .string("string"),
                            "description": .string("Repository in OWNER/REPO format (optional)")
                        ])
                    ]),
                    "required": .array([.string("subcommand")])
                ])
            ),
            
            // Repository operations
            Tool(
                name: "glab_repo",
                description: "Work with GitLab repositories. Common operations: clone (clone a repo), fork (fork a repo), view (view repo details), archive (archive a repo)",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "subcommand": .object([
                            "type": .string("string"),
                            "enum": .array([.string("clone"), .string("fork"), .string("view"), .string("archive"), .string("unarchive"), .string("delete"), .string("create"), .string("list"), .string("mirror"), .string("contributors")]),
                            "description": .string("The repository operation to perform")
                        ]),
                        "args": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Additional arguments like repo name, flags, etc.")
                        ])
                    ]),
                    "required": .array([.string("subcommand")])
                ])
            ),
            
            // API operations
            Tool(
                name: "glab_api",
                description: "Make authenticated requests to the GitLab API. Supports GET, POST, PUT, PATCH, DELETE methods.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "method": .object([
                            "type": .string("string"),
                            "enum": .array([.string("GET"), .string("POST"), .string("PUT"), .string("PATCH"), .string("DELETE")]),
                            "description": .string("HTTP method to use")
                        ]),
                        "endpoint": .object([
                            "type": .string("string"),
                            "description": .string("API endpoint path, e.g., '/projects/:id/merge_requests'")
                        ]),
                        "data": .object([
                            "type": .string("string"),
                            "description": .string("JSON data for POST/PUT/PATCH requests (optional)")
                        ]),
                        "headers": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Additional headers in 'key:value' format (optional)")
                        ])
                    ]),
                    "required": .array([.string("method"), .string("endpoint")])
                ])
            ),
            
            // Authentication
            Tool(
                name: "glab_auth",
                description: "Manage GitLab authentication. Operations: login (authenticate), status (check auth status), logout (remove authentication)",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "subcommand": .object([
                            "type": .string("string"),
                            "enum": .array([.string("login"), .string("status"), .string("logout")]),
                            "description": .string("The authentication operation to perform")
                        ]),
                        "args": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Additional arguments like --hostname, --token, etc.")
                        ])
                    ]),
                    "required": .array([.string("subcommand")])
                ])
            ),
            
            // Version information
            Tool(
                name: "glab_version",
                description: """
                Show version information for both the GitLab MCP server and glab CLI.
                Current authentication: stijn.willems@gitlab.mediahuisgroup.com
                Always use this first to verify the server is working correctly.
                """,
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:]),
                    "required": .array([])
                ])
            ),
            
            // Raw command execution
            Tool(
                name: "glab_raw",
                description: "Execute any glab command directly. Use this for commands not covered by other tools.",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "args": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Complete command arguments (without 'glab'). Example: ['config', 'get', 'editor']")
                        ])
                    ]),
                    "required": .array([.string("args")])
                ])
            )
        ]
        
        logger.info("Providing \(tools.count) static tools")
        return ListTools.Result(tools: tools)
    }
    
    private func handleToolCall(name: String, arguments: [String: Value]?) async throws -> CallTool.Result {
        let args = arguments ?? [:]
        
        logger.debug("Tool call: \(name)")
        logger.debug("Arguments: \(args)")
        
        switch name {
        case "glab_mr":
            return try await handleMergeRequest(args: args)
            
        case "glab_issue":
            return try await handleIssue(args: args)
            
        case "glab_ci":
            return try await handleCI(args: args)
            
        case "glab_repo":
            return try await handleRepo(args: args)
            
        case "glab_api":
            return try await handleAPI(args: args)
            
        case "glab_auth":
            return try await handleAuth(args: args)
            
        case "glab_version":
            return try await handleVersion()
            
        case "glab_raw":
            guard case .array(let argsArray) = args["args"],
                  let cmdArgs = argsArray.compactMap({ $0.stringValue }) as? [String] else {
                throw MCPError.invalidParams("args array is required")
            }
            let result = try await gitlabCLI.runCommand(args: cmdArgs)
            return formatResult(result)
            
        default:
            throw MCPError.methodNotFound("Unknown tool: \(name)")
        }
    }
    
    // MARK: - Tool Handlers
    
    private func handleMergeRequest(args: [String: Value]) async throws -> CallTool.Result {
        guard case .string(let subcommand) = args["subcommand"] else {
            throw MCPError.invalidParams("subcommand is required for glab_mr")
        }
        
        var cmdArgs = ["mr", subcommand]
        
        // Add repository if specified
        if case .string(let repo) = args["repo"] {
            cmdArgs.append(contentsOf: ["-R", repo])
        }
        
        // Add additional arguments
        if case .array(let argsArray) = args["args"],
           let additionalArgs = argsArray.compactMap({ $0.stringValue }) as? [String] {
            cmdArgs.append(contentsOf: additionalArgs)
        }
        
        let result = try await gitlabCLI.runCommand(args: cmdArgs)
        return formatResult(result)
    }
    
    private func handleIssue(args: [String: Value]) async throws -> CallTool.Result {
        guard case .string(let subcommand) = args["subcommand"] else {
            throw MCPError.invalidParams("subcommand is required for glab_issue")
        }
        
        var cmdArgs = ["issue", subcommand]
        
        // Add repository if specified
        if case .string(let repo) = args["repo"] {
            cmdArgs.append(contentsOf: ["-R", repo])
        }
        
        // Add additional arguments
        if case .array(let argsArray) = args["args"],
           let additionalArgs = argsArray.compactMap({ $0.stringValue }) as? [String] {
            cmdArgs.append(contentsOf: additionalArgs)
        }
        
        let result = try await gitlabCLI.runCommand(args: cmdArgs)
        return formatResult(result)
    }
    
    private func handleCI(args: [String: Value]) async throws -> CallTool.Result {
        guard case .string(let subcommand) = args["subcommand"] else {
            throw MCPError.invalidParams("subcommand is required for glab_ci")
        }
        
        var cmdArgs = ["ci", subcommand]
        
        // Add repository if specified
        if case .string(let repo) = args["repo"] {
            cmdArgs.append(contentsOf: ["-R", repo])
        }
        
        // Add additional arguments
        if case .array(let argsArray) = args["args"],
           let additionalArgs = argsArray.compactMap({ $0.stringValue }) as? [String] {
            cmdArgs.append(contentsOf: additionalArgs)
        }
        
        let result = try await gitlabCLI.runCommand(args: cmdArgs)
        return formatResult(result)
    }
    
    private func handleRepo(args: [String: Value]) async throws -> CallTool.Result {
        guard case .string(let subcommand) = args["subcommand"] else {
            throw MCPError.invalidParams("subcommand is required for glab_repo")
        }
        
        var cmdArgs = ["repo", subcommand]
        
        // Add additional arguments
        if case .array(let argsArray) = args["args"],
           let additionalArgs = argsArray.compactMap({ $0.stringValue }) as? [String] {
            cmdArgs.append(contentsOf: additionalArgs)
        }
        
        let result = try await gitlabCLI.runCommand(args: cmdArgs)
        return formatResult(result)
    }
    
    private func handleAPI(args: [String: Value]) async throws -> CallTool.Result {
        guard case .string(let method) = args["method"],
              case .string(let endpoint) = args["endpoint"] else {
            throw MCPError.invalidParams("method and endpoint are required for glab_api")
        }
        
        var cmdArgs = ["api", method, endpoint]
        
        // Add data if provided
        if case .string(let data) = args["data"] {
            cmdArgs.append(contentsOf: ["--raw-field", data])
        }
        
        // Add headers if provided
        if case .array(let headersArray) = args["headers"],
           let headers = headersArray.compactMap({ $0.stringValue }) as? [String] {
            for header in headers {
                cmdArgs.append(contentsOf: ["--header", header])
            }
        }
        
        let result = try await gitlabCLI.runCommand(args: cmdArgs)
        return formatResult(result)
    }
    
    private func handleAuth(args: [String: Value]) async throws -> CallTool.Result {
        guard case .string(let subcommand) = args["subcommand"] else {
            throw MCPError.invalidParams("subcommand is required for glab_auth")
        }
        
        var cmdArgs = ["auth", subcommand]
        
        // Add additional arguments
        if case .array(let argsArray) = args["args"],
           let additionalArgs = argsArray.compactMap({ $0.stringValue }) as? [String] {
            cmdArgs.append(contentsOf: additionalArgs)
        }
        
        let result = try await gitlabCLI.runCommand(args: cmdArgs)
        return formatResult(result)
    }
    
    private func handleVersion() async throws -> CallTool.Result {
        var versionInfo = "GitLab MCP Server (Swift)\n"
        versionInfo += "========================\n"
        versionInfo += "MCP Server Version: 0.3.0\n"
        versionInfo += "Build Date: \(Date().formatted(date: .abbreviated, time: .shortened))\n\n"
        
        // Get glab version
        let result = try await gitlabCLI.runCommand(args: ["version"])
        if result.success {
            versionInfo += "GLab CLI Version:\n"
            versionInfo += result.stdout
        } else {
            versionInfo += "GLab CLI: Unable to determine version"
        }
        
        return CallTool.Result(
            content: [.text(versionInfo)],
            isError: false
        )
    }
    
    // MARK: - Helper Methods
    
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
                    response += "\n\n💡 **Tip**: Make sure you're in a Git repository or specify the repository with the 'repo' parameter."
                }
            }
            
            if !result.stdout.isEmpty {
                response += "\n\nOutput:\n```\n\(result.stdout)\n```"
            }
        }
        
        return CallTool.Result(
            content: [.text(response)],
            isError: !result.success
        )
    }
    
    // MARK: - Prompts
    
    private func getPrompts() -> ListPrompts.Result {
        let prompts = [
            Prompt(
                name: "mediahuis-mr-check",
                description: "Check your Mediahuis merge requests. Authenticated as stijn.willems@gitlab.mediahuisgroup.com",
                arguments: [
                    .init(name: "repo", description: "Repository path (e.g., 'team/project')", required: false),
                    .init(name: "state", description: "Filter by state: opened, closed, merged, all", required: false)
                ]
            ),
            Prompt(
                name: "create-mr",
                description: "Create a new merge request with proper title and description",
                arguments: [
                    .init(name: "title", description: "MR title", required: true),
                    .init(name: "source_branch", description: "Source branch name", required: true),
                    .init(name: "target_branch", description: "Target branch (default: main)", required: false),
                    .init(name: "description", description: "MR description", required: false)
                ]
            ),
            Prompt(
                name: "daily-standup",
                description: "Get a summary of your GitLab activity for daily standup",
                arguments: [
                    .init(name: "days", description: "Number of days to look back (default: 1)", required: false)
                ]
            ),
            Prompt(
                name: "review-pipeline",
                description: "Check CI/CD pipeline status and failures",
                arguments: [
                    .init(name: "repo", description: "Repository path", required: false)
                ]
            )
        ]
        
        return ListPrompts.Result(prompts: prompts)
    }
    
    private func getPrompt(name: String, arguments: [String: Value]?) async throws -> GetPrompt.Result {
        switch name {
        case "mediahuis-mr-check":
            let repo = arguments?["repo"]?.stringValue ?? ""
            let state = arguments?["state"]?.stringValue ?? "opened"
            
            return GetPrompt.Result(
                description: "Check Mediahuis merge requests",
                messages: [
                    .user(.text(text: "Check my merge requests at Mediahuis")),
                    .assistant(.text(text: """
                    I'll check your Mediahuis GitLab merge requests. You're authenticated as stijn.willems@gitlab.mediahuisgroup.com.
                    
                    Let me fetch your \(state) merge requests\(repo.isEmpty ? "" : " for repository \(repo)").
                    
                    Using: glab_mr with subcommand "list" and filters for your assigned MRs.
                    """))
                ]
            )
            
        case "create-mr":
            let title = arguments?["title"]?.stringValue ?? "New Feature"
            let sourceBranch = arguments?["source_branch"]?.stringValue ?? "feature/new"
            let targetBranch = arguments?["target_branch"]?.stringValue ?? "main"
            let description = arguments?["description"]?.stringValue ?? ""
            
            return GetPrompt.Result(
                description: "Create a new merge request",
                messages: [
                    .user(.text(text: "Create a merge request: \(title)")),
                    .assistant(.text(text: """
                    I'll create a new merge request for you:
                    - Title: \(title)
                    - Source: \(sourceBranch) → Target: \(targetBranch)
                    \(description.isEmpty ? "" : "- Description: \(description)")
                    
                    Using: glab_mr with subcommand "create" and the provided details.
                    """))
                ]
            )
            
        case "daily-standup":
            let days = arguments?["days"]?.stringValue ?? "1"
            
            return GetPrompt.Result(
                description: "Gather GitLab activity for daily standup",
                messages: [
                    .user(.text(text: "What did I work on for standup?")),
                    .assistant(.text(text: """
                    I'll gather your GitLab activity for the daily standup from the last \(days) day(s):
                    
                    1. First, I'll check your recent merge requests (created, updated, merged)
                    2. Then, I'll look at issues you've worked on
                    3. Finally, I'll check any CI/CD pipeline activities
                    
                    This will give you a complete picture of your contributions.
                    """))
                ]
            )
            
        case "review-pipeline":
            let repo = arguments?["repo"]?.stringValue ?? "current repository"
            
            return GetPrompt.Result(
                description: "Review CI/CD pipeline status",
                messages: [
                    .user(.text(text: "Check the CI/CD pipeline status")),
                    .assistant(.text(text: """
                    I'll review the CI/CD pipeline status for \(repo):
                    
                    1. Check the latest pipeline status
                    2. Identify any failed jobs
                    3. Look for common failure patterns
                    4. Suggest fixes if applicable
                    
                    Using: glab_ci with subcommand "view" to get detailed pipeline information.
                    """))
                ]
            )
            
        default:
            throw MCPError.invalidParams("Unknown prompt: \(name)")
        }
    }
}

// MARK: - Value Extensions for convenience
extension Value {
    var stringValue: String? {
        if case .string(let str) = self {
            return str
        }
        return nil
    }
}