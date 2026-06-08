import AppKit
import Foundation

struct GitHubRepository: Equatable {
    let owner: String
    let name: String
    let branch: String

    var webURL: URL {
        URL(string: "https://github.com/\(owner)/\(name)")!
    }

    func fileURL(relativePath: String) -> URL {
        URL(string: "https://github.com/\(owner)/\(name)/blob/\(branch)/\(relativePath.githubPathEscaped)")!
    }
}

enum GitHubService {
    static func repository(rootURL: URL) throws -> GitHubRepository {
        let remote = try runGit(arguments: ["remote", "get-url", "origin"], rootURL: rootURL)
        let branch = (try? runGit(arguments: ["branch", "--show-current"], rootURL: rootURL))
            .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            ?? "HEAD"

        guard let match = parseGitHubRemote(remote.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw GitHubError.noGitHubRemote
        }

        return GitHubRepository(owner: match.owner, name: match.name, branch: branch)
    }

    @MainActor
    static func openRepository(rootURL: URL) throws {
        NSWorkspace.shared.open(try repository(rootURL: rootURL).webURL)
    }

    @MainActor
    static func copyRepositoryURL(rootURL: URL) throws {
        copyToPasteboard(try repository(rootURL: rootURL).webURL.absoluteString)
    }

    @MainActor
    static func copyFileLink(fileURL: URL, rootURL: URL, markdown: Bool) throws {
        let repo = try repository(rootURL: rootURL)
        let relativePath = ProjectFileScanner.relativePath(for: fileURL, rootURL: rootURL)
        let url = repo.fileURL(relativePath: relativePath)
        let value = markdown ? "[\(fileURL.lastPathComponent)](\(url.absoluteString))" : url.absoluteString
        copyToPasteboard(value)
    }

    static func createSecretGist(fileURL: URL, fileName: String) throws -> URL {
        let result = try runProcess(
            executable: "/usr/bin/env",
            arguments: ["gh", "gist", "create", fileURL.path, "--filename", fileName, "--desc", "Shared from TextPort"]
        )

        guard result.exitCode == 0,
              let firstLine = result.output.components(separatedBy: .newlines).first(where: { !$0.isEmpty }),
              let url = URL(string: firstLine.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            throw GitHubError.gistFailed(result.errorOutput.nilIfEmpty ?? result.output.nilIfEmpty ?? "GitHub CLI did not return a Gist URL.")
        }

        return url
    }

    @MainActor
    static func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private static func parseGitHubRemote(_ remote: String) -> (owner: String, name: String)? {
        let patterns = [
            #"^git@github\.com:([^/]+)/(.+?)(?:\.git)?$"#,
            #"^https://github\.com/([^/]+)/(.+?)(?:\.git)?$"#,
            #"^ssh://git@github\.com/([^/]+)/(.+?)(?:\.git)?$"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: remote, range: NSRange(location: 0, length: (remote as NSString).length)),
                  match.numberOfRanges >= 3
            else {
                continue
            }

            let owner = (remote as NSString).substring(with: match.range(at: 1))
            let name = (remote as NSString).substring(with: match.range(at: 2))
            return (owner, name)
        }

        return nil
    }

    private static func runGit(arguments: [String], rootURL: URL) throws -> String {
        let result = try runProcess(executable: "/usr/bin/git", arguments: arguments, currentDirectoryURL: rootURL)
        guard result.exitCode == 0 else {
            throw GitHubError.gitFailed(result.errorOutput.nilIfEmpty ?? result.output.nilIfEmpty ?? "git exited with code \(result.exitCode).")
        }
        return result.output
    }

    private static func runProcess(
        executable: String,
        arguments: [String],
        currentDirectoryURL: URL? = nil
    ) throws -> ProcessResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        return ProcessResult(
            exitCode: process.terminationStatus,
            output: String(data: outputData, encoding: .utf8) ?? String(decoding: outputData, as: UTF8.self),
            errorOutput: String(data: errorData, encoding: .utf8) ?? String(decoding: errorData, as: UTF8.self)
        )
    }
}

private struct ProcessResult {
    let exitCode: Int32
    let output: String
    let errorOutput: String
}

enum GitHubError: LocalizedError {
    case gitFailed(String)
    case gistFailed(String)
    case noGitHubRemote

    var errorDescription: String? {
        switch self {
        case .gitFailed(let message):
            "Git could not read this project. \(message)"
        case .gistFailed(let message):
            "GitHub could not create the Gist. \(message)"
        case .noGitHubRemote:
            "This project does not have a GitHub origin remote."
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var githubPathEscaped: String {
        split(separator: "/")
            .map { component in
                String(component).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(component)
            }
            .joined(separator: "/")
    }
}
