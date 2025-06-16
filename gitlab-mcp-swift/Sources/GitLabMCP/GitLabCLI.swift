import Foundation
import Logging

actor GitLabCLI {
    private let logger: Logger
    private var commandCache: [String: GitLabCommand]?
    private var cacheTimestamp: Date?
    private let cacheTTL: TimeInterval = 300 // 5 minutes
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func runCommand(args: [String], cwd: String? = nil) async throws -> CommandResult {
        let cmd = ["glab"] + args
        logger.info("Running command: \(cmd.joined(separator: " "))")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = cmd
        
        if let cwd = cwd {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            
            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            let returnCode = Int(process.terminationStatus)
            let success = returnCode == 0
            
            var dataString: String? = nil
            
            // Try to parse JSON output if it looks like JSON
            if success && !stdout.isEmpty {
                let trimmedStdout = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedStdout.hasPrefix("[") || trimmedStdout.hasPrefix("{") {
                    if let jsonData = trimmedStdout.data(using: .utf8),
                       let _ = try? JSONSerialization.jsonObject(with: jsonData) {
                        dataString = trimmedStdout
                    }
                }
            }
            
            return CommandResult(
                returnCode: returnCode,
                stdout: stdout,
                stderr: stderr,
                success: success,
                dataString: dataString
            )
        } catch {
            logger.error("Error running glab command: \(error)")
            return CommandResult(
                returnCode: -1,
                stdout: "",
                stderr: error.localizedDescription,
                success: false,
                dataString: nil
            )
        }
    }
    
    func discoverCommands() async throws -> [String: GitLabCommand] {
        // Check cache
        if let cache = commandCache,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheTTL {
            return cache
        }
        
        logger.info("Discovering glab commands...")
        
        let helpResult = try await runCommand(args: ["--help"])
        guard helpResult.success else {
            logger.error("Failed to get glab help")
            return [:]
        }
        
        var commands: [String: GitLabCommand] = [:]
        let helpText = helpResult.stdout
        let lines = helpText.split(separator: "\n").map(String.init)
        
        var inCommandsSection = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.contains("Available Commands:") || 
               trimmedLine.contains("Commands:") || 
               trimmedLine.contains("CORE COMMANDS") {
                inCommandsSection = true
                continue
            }
            
            if inCommandsSection && trimmedLine.isEmpty {
                continue
            }
            
            if inCommandsSection && (trimmedLine.hasPrefix("FLAGS") || trimmedLine.hasPrefix("LEARN MORE")) {
                break
            }
            
            if inCommandsSection && !trimmedLine.isEmpty {
                if let colonIndex = trimmedLine.firstIndex(of: ":") {
                    let command = String(trimmedLine[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    if !command.isEmpty && !command.hasPrefix("-") {
                        let commandHelp = try await getCommandHelp(command)
                        commands[command] = commandHelp
                    }
                }
            }
        }
        
        // Cache the results
        commandCache = commands
        cacheTimestamp = Date()
        
        logger.info("Discovered \(commands.count) glab commands")
        return commands
    }
    
    private func getCommandHelp(_ command: String) async throws -> GitLabCommand {
        let helpResult = try await runCommand(args: [command, "--help"])
        
        guard helpResult.success else {
            return GitLabCommand(
                name: command,
                description: "Execute glab \(command) command",
                usage: "glab \(command)",
                flags: [],
                subcommands: []
            )
        }
        
        let helpText = helpResult.stdout
        var description = ""
        var usage = ""
        var flags: [GitLabCommand.Flag] = []
        var subcommands: [GitLabCommand.Subcommand] = []
        
        let lines = helpText.split(separator: "\n").map(String.init)
        var currentSection: String?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Extract description
            if description.isEmpty && !trimmedLine.isEmpty && !trimmedLine.hasPrefix("Usage:") {
                if trimmedLine.lowercased().contains(command) || trimmedLine.lowercased().contains("command") {
                    description = trimmedLine
                }
            }
            
            // Extract usage
            if trimmedLine.hasPrefix("Usage:") {
                usage = trimmedLine.replacingOccurrences(of: "Usage:", with: "").trimmingCharacters(in: .whitespaces)
            }
            
            // Identify sections
            if ["Flags:", "Options:", "Global Flags:"].contains(trimmedLine) {
                currentSection = "flags"
                continue
            } else if ["Available Commands:", "Commands:"].contains(trimmedLine) {
                currentSection = "subcommands"
                continue
            } else if trimmedLine.hasPrefix("Examples:") || trimmedLine.hasPrefix("Use \"") {
                currentSection = nil
                continue
            }
            
            // Parse flags
            if currentSection == "flags" && line.hasPrefix("  ") {
                let regex = try NSRegularExpression(pattern: #"^\s*(-\w|--[\w-]+)"#)
                if let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                    let flagName = String(line[Range(match.range(at: 1), in: line)!])
                    var flagDesc = String(line[line.index(line.startIndex, offsetBy: match.range.upperBound)...])
                        .trimmingCharacters(in: .whitespaces)
                    
                    // Remove type hints like [string] or [int]
                    flagDesc = flagDesc.replacingOccurrences(of: #"\s*\[[\w\s,]+\]"#, with: "", options: .regularExpression)
                    
                    flags.append(GitLabCommand.Flag(name: flagName, description: flagDesc, type: nil))
                }
            }
            
            // Parse subcommands
            else if currentSection == "subcommands" && line.hasPrefix("  ") {
                let parts = trimmedLine.split(separator: " ", maxSplits: 1).map(String.init)
                if !parts.isEmpty {
                    let subcommandName = parts[0]
                    let subcommandDesc = parts.count > 1 ? parts[1] : ""
                    subcommands.append(GitLabCommand.Subcommand(name: subcommandName, description: subcommandDesc))
                }
            }
        }
        
        return GitLabCommand(
            name: command,
            description: description.isEmpty ? "Execute glab \(command) command" : description,
            usage: usage.isEmpty ? "glab \(command)" : usage,
            flags: flags,
            subcommands: subcommands
        )
    }
    
    func clearCache() {
        commandCache = nil
        cacheTimestamp = nil
    }
}