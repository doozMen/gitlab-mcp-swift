import Foundation

struct GitLabCommand {
    let name: String
    let description: String
    let usage: String
    let flags: [Flag]
    let subcommands: [Subcommand]
    
    struct Flag {
        let name: String
        let description: String
        let type: String?
    }
    
    struct Subcommand {
        let name: String
        let description: String
    }
}

struct CommandResult: Sendable {
    let returnCode: Int
    let stdout: String
    let stderr: String
    let success: Bool
    let dataString: String? // JSON string representation instead of Any
    
    var error: String? {
        return success ? nil : stderr
    }
    
    var parsedData: Any? {
        guard let dataString = dataString,
              let data = dataString.data(using: .utf8) else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data)
    }
}