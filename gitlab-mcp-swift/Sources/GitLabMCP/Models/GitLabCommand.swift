import Foundation

struct CommandResult: Sendable {
    let returnCode: Int
    let stdout: String
    let stderr: String
    let success: Bool
    let dataString: String? // JSON string representation
    
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