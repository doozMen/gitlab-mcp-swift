import ArgumentParser
import Logging
import Foundation

@main
struct GitLabMCPCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gitlab-mcp",
        abstract: "GitLab MCP Server using Swift SDK - Wraps glab CLI for AI assistants",
        version: "0.1.1"
    )
    
    @Option(name: .long, help: "Log level (trace, debug, info, notice, warning, error, critical)")
    var logLevel: String = "debug"
    
    func run() async throws {
        // Setup logging
        let level = Logger.Level(rawValue: logLevel) ?? .info
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = level
            return handler
        }
        
        let logger = Logger(label: "gitlab-mcp")
        
        let version = "0.1.1"
        let buildDate = Date().formatted(date: .abbreviated, time: .shortened)
        
        logger.info("Starting GitLab MCP Server (Swift) v\(version)")
        logger.info("Build: \(buildDate)")
        logger.info("Wrapping glab CLI for Model Context Protocol")
        
        // Pre-warm the command cache
        do {
            let cliLogger = Logger(label: "gitlab-cli")
            let cli = GitLabCLI(logger: cliLogger)
            _ = try await cli.discoverCommands()
            logger.info("✅ Glab command discovery completed")
        } catch {
            logger.warning("Initial command discovery failed: \(error)")
        }
        
        // Start the server
        do {
            let server = try GitLabMCPServer(logger: logger)
            try await server.start()
        } catch {
            logger.error("Failed to start server: \(error)")
            throw ExitCode.failure
        }
    }
}
