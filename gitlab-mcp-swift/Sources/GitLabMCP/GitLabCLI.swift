import Foundation
import Logging

actor GitLabCLI {
    private let logger: Logger
    
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
}