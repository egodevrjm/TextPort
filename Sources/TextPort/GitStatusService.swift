import Foundation

enum GitStatusService {
    static func statuses(rootURL: URL) -> [String: String] {
        guard FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(".git").path) else { return [:] }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["status", "--porcelain"]
        process.currentDirectoryURL = rootURL
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return [:]
        }

        guard process.terminationStatus == 0 else { return [:] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        var statuses: [String: String] = [:]

        for line in output.components(separatedBy: "\n") where line.count >= 4 {
            let status = String(line.prefix(2)).trimmingCharacters(in: .whitespaces)
            let pathStart = line.index(line.startIndex, offsetBy: 3)
            let relativePath = String(line[pathStart...])
            let cleanPath = relativePath.components(separatedBy: " -> ").last ?? relativePath
            let url = rootURL.appendingPathComponent(cleanPath)
            statuses[url.standardizedFileURL.path] = status.isEmpty ? "M" : status
        }

        return statuses
    }
}
