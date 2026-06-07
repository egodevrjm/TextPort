import Foundation

struct RunFileCommand {
    let name: String
    let command: String
    let defaultWorkingDirectoryURL: URL

    static func make(for fileURL: URL) -> RunFileCommand? {
        let normalizedURL = fileURL.standardizedFileURL
        let fileName = normalizedURL.lastPathComponent
        let quotedPath = ShellCommandQuote.quote(normalizedURL.path)
        let workingDirectoryURL = normalizedURL.deletingLastPathComponent()

        switch normalizedURL.pathExtension.lowercased() {
        case "swift":
            return RunFileCommand(
                name: "Run \(fileName)",
                command: "swift \(quotedPath)",
                defaultWorkingDirectoryURL: workingDirectoryURL
            )
        case "py", "pyw":
            return RunFileCommand(
                name: "Run \(fileName)",
                command: "python3 \(quotedPath)",
                defaultWorkingDirectoryURL: workingDirectoryURL
            )
        case "js", "mjs", "cjs":
            return RunFileCommand(
                name: "Run \(fileName)",
                command: "node \(quotedPath)",
                defaultWorkingDirectoryURL: workingDirectoryURL
            )
        case "sh", "bash", "zsh", "command":
            return RunFileCommand(
                name: "Run \(fileName)",
                command: "/bin/zsh \(quotedPath)",
                defaultWorkingDirectoryURL: workingDirectoryURL
            )
        case "rb":
            return RunFileCommand(
                name: "Run \(fileName)",
                command: "ruby \(quotedPath)",
                defaultWorkingDirectoryURL: workingDirectoryURL
            )
        case "go":
            return RunFileCommand(
                name: "Run \(fileName)",
                command: "go run \(quotedPath)",
                defaultWorkingDirectoryURL: workingDirectoryURL
            )
        default:
            return nil
        }
    }
}

enum ShellCommandQuote {
    static func quote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
