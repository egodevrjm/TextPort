import AppKit
import Foundation

enum ProjectFileScanner {
    static func scan(rootURL: URL) -> [ProjectFileNode] {
        children(in: rootURL, rootURL: rootURL)
    }

    private static func children(in directoryURL: URL, rootURL: URL) -> [ProjectFileNode] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants]
        )) ?? []

        return contents
            .filter { shouldInclude(url: $0) }
            .compactMap { url -> ProjectFileNode? in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                let isDirectory = values?.isDirectory == true
                let relativePath = relativePath(for: url, rootURL: rootURL)
                let childNodes = isDirectory ? children(in: url, rootURL: rootURL) : []

                return ProjectFileNode(
                    url: url,
                    relativePath: relativePath,
                    name: url.lastPathComponent,
                    kind: isDirectory ? .directory : .file,
                    children: childNodes
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory
                }

                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    static func shouldInclude(url: URL) -> Bool {
        let name = url.lastPathComponent
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true

        if isDirectory, name.hasPrefix(".") {
            return false
        }

        if isDirectory, excludedDirectoryNames.contains(name) {
            return false
        }

        if name == ".DS_Store" {
            return false
        }

        return true
    }

    static func relativePath(for url: URL, rootURL: URL) -> String {
        let rootPath = rootURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path

        guard path.hasPrefix(rootPath) else {
            return url.lastPathComponent
        }

        let start = path.index(path.startIndex, offsetBy: rootPath.count)
        return path[start...].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static let excludedDirectoryNames = Set([
        ".build",
        ".git",
        ".swiftpm",
        "Carthage",
        "DerivedData",
        "Pods",
        "node_modules",
        "Package.resolved"
    ])
}

enum ProjectSearchService {
    static let maxFileSize = 1_000_000
    static let maxResults = 300

    static func search(query rawQuery: String, in rootURL: URL) -> [ProjectSearchResult] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        let lowercasedQuery = query.lowercased()
        var results: [ProjectSearchResult] = []

        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        for case let url as URL in enumerator {
            guard ProjectFileScanner.shouldInclude(url: url) else {
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            if values?.isDirectory == true {
                continue
            }

            guard !OfficeImportService.isSpreadsheet(url), !OfficeImportService.isLegacyExcel(url) else {
                continue
            }

            guard (values?.fileSize ?? 0) <= maxFileSize else {
                continue
            }

            guard let loadedFile = try? TextFileLoader.load(url: url) else {
                continue
            }

            appendMatches(
                in: loadedFile.text,
                query: lowercasedQuery,
                fileURL: url,
                rootURL: rootURL,
                results: &results
            )

            if results.count >= maxResults {
                return results
            }
        }

        return results
    }

    private static func appendMatches(
        in text: String,
        query: String,
        fileURL: URL,
        rootURL: URL,
        results: inout [ProjectSearchResult]
    ) {
        let normalizedText = TextLineEnding.lf.normalized(text)
        let lines = normalizedText.components(separatedBy: "\n")
        let relativePath = ProjectFileScanner.relativePath(for: fileURL, rootURL: rootURL)

        for (index, line) in lines.enumerated() {
            let lowercasedLine = line.lowercased()
            guard let matchRange = lowercasedLine.range(of: query) else { continue }

            let matchStart = lowercasedLine.distance(from: lowercasedLine.startIndex, to: matchRange.lowerBound)
            let preview = line.trimmingCharacters(in: .whitespacesAndNewlines)

            results.append(ProjectSearchResult(
                fileURL: fileURL,
                relativePath: relativePath,
                lineNumber: index + 1,
                preview: preview.isEmpty ? line : preview,
                matchStart: matchStart,
                matchLength: query.count
            ))

            if results.count >= maxResults {
                return
            }
        }
    }
}

@MainActor
final class TaskRunner {
    private var process: Process?

    var isRunning: Bool {
        process != nil
    }

    func run(
        task: RunTask,
        projectRootURL: URL,
        output: @escaping @MainActor (String) -> Void,
        completion: @escaping @MainActor (Int32) -> Void,
        failure: @escaping @MainActor (String) -> Void
    ) {
        guard process == nil else {
            failure("A task is already running.")
            return
        }

        let process = Process()
        let pipe = Pipe()
        let workingDirectoryURL = workingDirectory(for: task, rootURL: projectRootURL)

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", task.command]
        process.currentDirectoryURL = workingDirectoryURL
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)

            Task { @MainActor in
                output(text)
            }
        }

        process.terminationHandler = { [weak self] terminatedProcess in
            pipe.fileHandleForReading.readabilityHandler = nil

            Task { @MainActor in
                self?.process = nil
                completion(terminatedProcess.terminationStatus)
            }
        }

        do {
            try process.run()
            self.process = process
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            failure(error.localizedDescription)
        }
    }

    func stop() {
        process?.terminate()
    }

    private func workingDirectory(for task: RunTask, rootURL: URL) -> URL {
        let trimmed = task.workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "." else {
            return rootURL
        }

        return rootURL.appendingPathComponent(trimmed, isDirectory: true)
    }
}

enum ProjectPersistenceStore {
    static func loadSession() -> ProjectAppSession {
        guard let data = try? Data(contentsOf: sessionURL),
              let session = try? JSONDecoder().decode(ProjectAppSession.self, from: data)
        else {
            return ProjectAppSession(openProjectPath: nil, recentProjects: [])
        }

        return session
    }

    static func saveSession(_ session: ProjectAppSession) {
        do {
            try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            let data = try JSONEncoder.pretty.encode(session)
            try data.write(to: sessionURL, options: .atomic)
        } catch {
            // Project restore should never interrupt editing.
        }
    }

    static func loadState(for rootURL: URL) -> ProjectWorkspaceState? {
        guard let data = try? Data(contentsOf: stateURL(for: rootURL)) else { return nil }
        return try? JSONDecoder().decode(ProjectWorkspaceState.self, from: data)
    }

    static func saveState(_ state: ProjectWorkspaceState, for rootURL: URL) {
        do {
            let statesDirectory = appSupportURL.appendingPathComponent("Projects", isDirectory: true)
            try FileManager.default.createDirectory(at: statesDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder.pretty.encode(state)
            try data.write(to: stateURL(for: rootURL), options: .atomic)
        } catch {
            // Project restore should never interrupt editing.
        }
    }

    private static var sessionURL: URL {
        appSupportURL.appendingPathComponent("project-session.json")
    }

    private static func stateURL(for rootURL: URL) -> URL {
        let encodedPath = Data(rootURL.standardizedFileURL.path.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
        return appSupportURL
            .appendingPathComponent("Projects", isDirectory: true)
            .appendingPathComponent(encodedPath)
            .appendingPathExtension("json")
    }

    private static var appSupportURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("TextPort", isDirectory: true)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
