# GitLab MCP Integration with Swift SDK - Setup Guide for Claude Code

## Overview
This guide sets up a GitLab MCP server using the Swift SDK that can work from any git repository and integrate with your time tracking system. The server will provide GitLab API access through MCP protocol without requiring you to be in a specific GitLab repository.

## Project Structure

```
gitlab-mcp-swift/
├── Package.swift
├── Sources/
│   └── GitLabMCP/
│       ├── main.swift
│       ├── GitLabMCPServer.swift
│       ├── GitLabAPI.swift
│       └── Models/
│           ├── GitLabModels.swift
│           └── MCPResponses.swift
├── .env.example
├── README.md
└── .gitignore
```

## Step 1: Package.swift Configuration

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "gitlab-mcp-swift",
    platforms: [
        .macOS(.v15),
        .linux(.ubuntu2404)
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "GitLabMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
```

## Step 2: GitLab API Models

Create `Sources/GitLabMCP/Models/GitLabModels.swift`:

```swift
import Foundation

// MARK: - GitLab API Models

struct GitLabProject: Codable {
    let id: Int
    let name: String
    let nameWithNamespace: String
    let description: String?
    let webUrl: String
    let defaultBranch: String
    let createdAt: String
    let lastActivityAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case nameWithNamespace = "name_with_namespace"
        case webUrl = "web_url"
        case defaultBranch = "default_branch"
        case createdAt = "created_at"
        case lastActivityAt = "last_activity_at"
    }
}

struct GitLabIssue: Codable {
    let id: Int
    let iid: Int
    let title: String
    let description: String?
    let state: String
    let createdAt: String
    let updatedAt: String
    let webUrl: String
    let assignee: GitLabUser?
    let author: GitLabUser
    let labels: [String]
    let milestone: GitLabMilestone?
    let timeStats: GitLabTimeStats?
    
    enum CodingKeys: String, CodingKey {
        case id, iid, title, description, state, assignee, author, labels, milestone
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case webUrl = "web_url"
        case timeStats = "time_stats"
    }
}

struct GitLabMergeRequest: Codable {
    let id: Int
    let iid: Int
    let title: String
    let description: String?
    let state: String
    let createdAt: String
    let updatedAt: String
    let webUrl: String
    let sourceBranch: String
    let targetBranch: String
    let author: GitLabUser
    let assignee: GitLabUser?
    let reviewer: GitLabUser?
    
    enum CodingKeys: String, CodingKey {
        case id, iid, title, description, state, author, assignee, reviewer
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case webUrl = "web_url"
        case sourceBranch = "source_branch"
        case targetBranch = "target_branch"
    }
}

struct GitLabUser: Codable {
    let id: Int
    let name: String
    let username: String
    let email: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, username, email
        case avatarUrl = "avatar_url"
    }
}

struct GitLabMilestone: Codable {
    let id: Int
    let title: String
    let description: String?
    let state: String
    let dueDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, state
        case dueDate = "due_date"
    }
}

struct GitLabTimeStats: Codable {
    let timeEstimate: Int
    let totalTimeSpent: Int
    let humanTimeEstimate: String?
    let humanTotalTimeSpent: String?
    
    enum CodingKeys: String, CodingKey {
        case timeEstimate = "time_estimate"
        case totalTimeSpent = "total_time_spent"
        case humanTimeEstimate = "human_time_estimate"
        case humanTotalTimeSpent = "human_total_time_spent"
    }
}

struct GitLabCommit: Codable {
    let id: String
    let shortId: String
    let title: String
    let message: String
    let authorName: String
    let authorEmail: String
    let createdAt: String
    let webUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, message
        case shortId = "short_id"
        case authorName = "author_name"
        case authorEmail = "author_email"
        case createdAt = "created_at"
        case webUrl = "web_url"
    }
}

struct GitLabPipeline: Codable {
    let id: Int
    let sha: String
    let ref: String
    let status: String
    let createdAt: String
    let updatedAt: String
    let webUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id, sha, ref, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case webUrl = "web_url"
    }
}
```

## Step 3: GitLab API Client

Create `Sources/GitLabMCP/GitLabAPI.swift`:

```swift
import Foundation
import AsyncHTTPClient
import Logging

actor GitLabAPI {
    private let httpClient: HTTPClient
    private let baseURL: String
    private let token: String
    private let logger: Logger
    
    init(baseURL: String, token: String, logger: Logger) {
        self.baseURL = baseURL.trimmingSuffix("/")
        self.token = token
        self.logger = logger
        self.httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
    }
    
    deinit {
        try? httpClient.syncShutdown()
    }
    
    // MARK: - Projects
    
    func getProjects(owned: Bool = false, membership: Bool = true) async throws -> [GitLabProject] {
        var queryItems = [
            URLQueryItem(name: "membership", value: membership ? "true" : "false"),
            URLQueryItem(name: "per_page", value: "100")
        ]
        
        if owned {
            queryItems.append(URLQueryItem(name: "owned", value: "true"))
        }
        
        return try await performRequest(endpoint: "/projects", queryItems: queryItems)
    }
    
    func getProject(projectId: String) async throws -> GitLabProject {
        let encodedId = projectId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectId
        return try await performRequest(endpoint: "/projects/\(encodedId)")
    }
    
    // MARK: - Issues
    
    func getIssues(projectId: String? = nil, assigneeId: String? = nil, state: String = "opened") async throws -> [GitLabIssue] {
        let endpoint = projectId != nil ? "/projects/\(projectId!)/issues" : "/issues"
        
        var queryItems = [
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "per_page", value: "100")
        ]
        
        if let assigneeId = assigneeId {
            queryItems.append(URLQueryItem(name: "assignee_id", value: assigneeId))
        }
        
        return try await performRequest(endpoint: endpoint, queryItems: queryItems)
    }
    
    func getIssue(projectId: String, issueIid: Int) async throws -> GitLabIssue {
        let encodedId = projectId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectId
        return try await performRequest(endpoint: "/projects/\(encodedId)/issues/\(issueIid)")
    }
    
    // MARK: - Merge Requests
    
    func getMergeRequests(projectId: String? = nil, assigneeId: String? = nil, state: String = "opened") async throws -> [GitLabMergeRequest] {
        let endpoint = projectId != nil ? "/projects/\(projectId!)/merge_requests" : "/merge_requests"
        
        var queryItems = [
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "per_page", value: "100")
        ]
        
        if let assigneeId = assigneeId {
            queryItems.append(URLQueryItem(name: "assignee_id", value: assigneeId))
        }
        
        return try await performRequest(endpoint: endpoint, queryItems: queryItems)
    }
    
    func getMergeRequest(projectId: String, mergeRequestIid: Int) async throws -> GitLabMergeRequest {
        let encodedId = projectId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectId
        return try await performRequest(endpoint: "/projects/\(encodedId)/merge_requests/\(mergeRequestIid)")
    }
    
    // MARK: - Commits
    
    func getCommits(projectId: String, since: String? = nil, until: String? = nil) async throws -> [GitLabCommit] {
        let encodedId = projectId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectId
        
        var queryItems = [URLQueryItem(name: "per_page", value: "100")]
        
        if let since = since {
            queryItems.append(URLQueryItem(name: "since", value: since))
        }
        
        if let until = until {
            queryItems.append(URLQueryItem(name: "until", value: until))
        }
        
        return try await performRequest(endpoint: "/projects/\(encodedId)/repository/commits", queryItems: queryItems)
    }
    
    // MARK: - Pipelines
    
    func getPipelines(projectId: String) async throws -> [GitLabPipeline] {
        let encodedId = projectId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectId
        return try await performRequest(endpoint: "/projects/\(encodedId)/pipelines", queryItems: [
            URLQueryItem(name: "per_page", value: "50")
        ])
    }
    
    // MARK: - User Info
    
    func getCurrentUser() async throws -> GitLabUser {
        return try await performRequest(endpoint: "/user")
    }
    
    // MARK: - Generic Request Handler
    
    private func performRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> T {
        
        var urlComponents = URLComponents(string: "\(baseURL)/api/v4\(endpoint)")!
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw GitLabAPIError.invalidURL
        }
        
        var request = HTTPClientRequest(url: url.absoluteString)
        request.method = method
        request.headers.add(name: "Authorization", value: "Bearer \(token)")
        request.headers.add(name: "Content-Type", value: "application/json")
        
        if let body = body {
            request.body = .bytes(body)
        }
        
        logger.debug("GitLab API request: \(method) \(url)")
        
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        
        guard 200...299 ~= response.status.code else {
            let bodyString = try await response.body.collect(upTo: 1024 * 1024).getString(at: 0, length: response.body.readableBytes) ?? "No body"
            logger.error("GitLab API error: \(response.status.code) - \(bodyString)")
            throw GitLabAPIError.httpError(response.status.code, bodyString)
        }
        
        let data = try await response.body.collect(upTo: 10 * 1024 * 1024) // 10MB limit
        let responseData = Data(buffer: data)
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: responseData)
        } catch {
            logger.error("Failed to decode GitLab API response: \(error)")
            throw GitLabAPIError.decodingError(error)
        }
    }
}

enum GitLabAPIError: Error, LocalizedError {
    case invalidURL
    case httpError(Int, String)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitLab API URL"
        case .httpError(let code, let message):
            return "GitLab API HTTP error \(code): \(message)"
        case .decodingError(let error):
            return "Failed to decode GitLab API response: \(error.localizedDescription)"
        }
    }
}

extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        if hasSuffix(suffix) {
            return String(dropLast(suffix.count))
        }
        return self
    }
}
```

## Step 4: MCP Server Implementation

Create `Sources/GitLabMCP/GitLabMCPServer.swift`:

```swift
import MCP
import Logging
import Foundation

actor GitLabMCPServer {
    private let server: Server
    private let gitlabAPI: GitLabAPI
    private let logger: Logger
    
    init(gitlabURL: String, token: String, logger: Logger) throws {
        self.logger = logger
        self.gitlabAPI = GitLabAPI(baseURL: gitlabURL, token: token, logger: logger)
        
        self.server = Server(
            name: "GitLabMCP",
            version: "1.0.0",
            capabilities: .init(
                prompts: nil,
                resources: .init(subscribe: false, listChanged: false),
                tools: .init(listChanged: false)
            ),
            logger: logger
        )
        
        await setupHandlers()
    }
    
    func start() async throws {
        let transport = StdioTransport(logger: logger)
        try await server.start(transport: transport)
        logger.info("GitLab MCP Server started")
    }
    
    private func setupHandlers() async {
        // List Tools
        await server.withMethodHandler(ListTools.self) { _ in
            let tools = [
                Tool(
                    name: "gitlab_get_projects",
                    description: "Get GitLab projects accessible to the user",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "owned": .object([
                                "type": .string("boolean"),
                                "description": .string("Only return projects owned by the user")
                            ])
                        ])
                    ])
                ),
                Tool(
                    name: "gitlab_get_issues",
                    description: "Get GitLab issues for a project or user",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "project_id": .object([
                                "type": .string("string"),
                                "description": .string("Project ID or path (optional)")
                            ]),
                            "state": .object([
                                "type": .string("string"),
                                "description": .string("Issue state: opened, closed, all"),
                                "default": .string("opened")
                            ])
                        ])
                    ])
                ),
                Tool(
                    name: "gitlab_get_merge_requests",
                    description: "Get GitLab merge requests for a project or user",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "project_id": .object([
                                "type": .string("string"),
                                "description": .string("Project ID or path (optional)")
                            ]),
                            "state": .object([
                                "type": .string("string"),
                                "description": .string("MR state: opened, closed, merged, all"),
                                "default": .string("opened")
                            ])
                        ])
                    ])
                ),
                Tool(
                    name: "gitlab_get_commits",
                    description: "Get recent commits for a project",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "project_id": .object([
                                "type": .string("string"),
                                "description": .string("Project ID or path (required)")
                            ]),
                            "since": .object([
                                "type": .string("string"),
                                "description": .string("ISO date to get commits since")
                            ])
                        ]),
                        "required": .array([.string("project_id")])
                    ])
                ),
                Tool(
                    name: "gitlab_get_user_info",
                    description: "Get current GitLab user information",
                    inputSchema: .object([
                        "type": .string("object")
                    ])
                )
            ]
            
            return ListTools.Result(tools: tools)
        }
        
        // Call Tool Handler
        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self = self else {
                throw MCPError.internalError("Server unavailable")
            }
            
            return try await self.handleToolCall(name: params.name, arguments: params.arguments)
        }
        
        // List Resources
        await server.withMethodHandler(ListResources.self) { _ in
            let resources = [
                Resource(
                    uri: "gitlab://projects",
                    name: "GitLab Projects",
                    description: "List of accessible GitLab projects",
                    mimeType: "application/json"
                ),
                Resource(
                    uri: "gitlab://user",
                    name: "Current User",
                    description: "Current GitLab user information",
                    mimeType: "application/json"
                )
            ]
            
            return ListResources.Result(resources: resources)
        }
        
        // Read Resource Handler
        await server.withMethodHandler(ReadResource.self) { [weak self] params in
            guard let self = self else {
                throw MCPError.internalError("Server unavailable")
            }
            
            return try await self.handleResourceRead(uri: params.uri)
        }
    }
    
    private func handleToolCall(name: String, arguments: [String: Any]?) async throws -> CallTool.Result {
        switch name {
        case "gitlab_get_projects":
            let owned = arguments?["owned"] as? Bool ?? false
            let projects = try await gitlabAPI.getProjects(owned: owned)
            let json = try JSONEncoder().encode(projects)
            let jsonString = String(data: json, encoding: .utf8) ?? "[]"
            return CallTool.Result(content: [.text(jsonString)], isError: false)
            
        case "gitlab_get_issues":
            let projectId = arguments?["project_id"] as? String
            let state = arguments?["state"] as? String ?? "opened"
            let issues = try await gitlabAPI.getIssues(projectId: projectId, state: state)
            let json = try JSONEncoder().encode(issues)
            let jsonString = String(data: json, encoding: .utf8) ?? "[]"
            return CallTool.Result(content: [.text(jsonString)], isError: false)
            
        case "gitlab_get_merge_requests":
            let projectId = arguments?["project_id"] as? String
            let state = arguments?["state"] as? String ?? "opened"
            let mrs = try await gitlabAPI.getMergeRequests(projectId: projectId, state: state)
            let json = try JSONEncoder().encode(mrs)
            let jsonString = String(data: json, encoding: .utf8) ?? "[]"
            return CallTool.Result(content: [.text(jsonString)], isError: false)
            
        case "gitlab_get_commits":
            guard let projectId = arguments?["project_id"] as? String else {
                throw MCPError.invalidParams("project_id is required")
            }
            let since = arguments?["since"] as? String
            let commits = try await gitlabAPI.getCommits(projectId: projectId, since: since)
            let json = try JSONEncoder().encode(commits)
            let jsonString = String(data: json, encoding: .utf8) ?? "[]"
            return CallTool.Result(content: [.text(jsonString)], isError: false)
            
        case "gitlab_get_user_info":
            let user = try await gitlabAPI.getCurrentUser()
            let json = try JSONEncoder().encode(user)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return CallTool.Result(content: [.text(jsonString)], isError: false)
            
        default:
            throw MCPError.methodNotFound("Unknown tool: \(name)")
        }
    }
    
    private func handleResourceRead(uri: String) async throws -> ReadResource.Result {
        switch uri {
        case "gitlab://projects":
            let projects = try await gitlabAPI.getProjects()
            let json = try JSONEncoder().encode(projects)
            let jsonString = String(data: json, encoding: .utf8) ?? "[]"
            return ReadResource.Result(contents: [.text(jsonString)])
            
        case "gitlab://user":
            let user = try await gitlabAPI.getCurrentUser()
            let json = try JSONEncoder().encode(user)
            let jsonString = String(data: json, encoding: .utf8) ?? "{}"
            return ReadResource.Result(contents: [.text(jsonString)])
            
        default:
            throw MCPError.invalidParams("Unknown resource URI: \(uri)")
        }
    }
}
```

## Step 5: Main Application Entry Point

Create `Sources/GitLabMCP/main.swift`:

```swift
import ArgumentParser
import Logging
import Foundation

@main
struct GitLabMCPCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gitlab-mcp",
        abstract: "GitLab MCP Server using Swift SDK"
    )
    
    @Option(name: .long, help: "GitLab instance URL")
    var gitlabUrl: String = "https://gitlab.com"
    
    @Option(name: .long, help: "GitLab personal access token")
    var token: String?
    
    @Option(name: .long, help: "Log level (trace, debug, info, notice, warning, error, critical)")
    var logLevel: String = "info"
    
    func run() async throws {
        // Setup logging
        let level = Logger.Level(rawValue: logLevel) ?? .info
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = level
            return handler
        }
        
        let logger = Logger(label: "gitlab-mcp")
        
        // Get token from environment or argument
        guard let accessToken = token ?? ProcessInfo.processInfo.environment["GITLAB_TOKEN"] else {
            logger.error("GitLab token required. Set GITLAB_TOKEN environment variable or use --token option")
            throw ExitCode.failure
        }
        
        logger.info("Starting GitLab MCP Server")
        logger.info("GitLab URL: \(gitlabUrl)")
        
        do {
            let server = try GitLabMCPServer(
                gitlabURL: gitlabUrl,
                token: accessToken,
                logger: logger
            )
            
            try await server.start()
        } catch {
            logger.error("Failed to start server: \(error)")
            throw ExitCode.failure
        }
    }
}
```

## Step 6: Environment Configuration

Create `.env.example`:

```bash
# GitLab Configuration
GITLAB_TOKEN=your_gitlab_personal_access_token_here
GITLAB_URL=https://gitlab.com

# Logging
LOG_LEVEL=info
```

## Step 7: Claude Desktop Configuration

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "gitlab-swift": {
      "type": "stdio", 
      "command": "/path/to/your/.build/release/GitLabMCP",
      "args": ["--gitlab-url", "https://gitlab.com"],
      "env": {
        "GITLAB_TOKEN": "your_token_here"
      }
    }
  }
}
```

## Step 8: Build and Test Instructions

```bash
# 1. Clone or create the project
mkdir gitlab-mcp-swift && cd gitlab-mcp-swift

# 2. Initialize with the Package.swift above
# Copy all the source files

# 3. Set your GitLab token
export GITLAB_TOKEN="your_gitlab_personal_access_token"

# 4. Build the project
swift build -c release

# 5. Test the server manually
./.build/release/GitLabMCP --gitlab-url "https://gitlab.com"

# 6. Test with Claude Desktop by adding the config above
```

## Step 9: Integration with Time Tracking

The server provides these tools that integrate with your time tracking:

1. **`gitlab_get_projects`** - Get accessible projects
2. **`gitlab_get_issues`** - Get issues (with time tracking data)
3. **`gitlab_get_merge_requests`** - Get MRs assigned to you
4. **`gitlab_get_commits`** - Get recent commits for correlation
5. **`gitlab_get_user_info`** - Get current user info

## Example Usage in Claude

```
@gitlab-swift gitlab_get_issues --state opened
@gitlab-swift gitlab_get_merge_requests --state opened  
@gitlab-swift gitlab_get_commits --project-id "your-project" --since "2025-06-15"
```

## Key Features

- ✅ **Works from any directory** - doesn't require being in a git repo
- ✅ **Uses Swift MCP SDK** - follows official patterns
- ✅ **Comprehensive GitLab API coverage** - issues, MRs, commits, projects
- ✅ **Time tracking integration** - includes GitLab time tracking data
- ✅ **Configurable** - supports different GitLab instances
- ✅ **Error handling** - proper error messages and logging
- ✅ **Type safe** - leverages Swift's type system

This setup will give you a robust GitLab MCP integration that works with your time tracking system and can be called from anywhere, not just git repositories.