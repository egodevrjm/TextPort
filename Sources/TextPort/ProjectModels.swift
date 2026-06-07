import Foundation

struct Project: Identifiable, Codable, Equatable {
    var rootURL: URL
    var displayName: String
    var lastOpened: Date

    var id: String {
        rootURL.path
    }
}

struct ProjectFileNode: Identifiable, Equatable {
    let url: URL
    let relativePath: String
    let name: String
    let kind: ProjectFileKind
    var children: [ProjectFileNode]

    var id: String {
        url.path
    }

    var isDirectory: Bool {
        kind == .directory
    }
}

enum ProjectFileKind: String, Codable {
    case directory
    case file
}

struct ProjectSearchResult: Identifiable, Equatable {
    let fileURL: URL
    let relativePath: String
    let lineNumber: Int
    let preview: String
    let matchStart: Int
    let matchLength: Int

    var id: String {
        "\(fileURL.path):\(lineNumber):\(matchStart)"
    }
}

struct RunTask: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var command: String
    var workingDirectory: String

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        workingDirectory: String = "."
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
    }
}

enum TaskRunState: Equatable {
    case idle
    case running(RunTask)
    case completed(exitCode: Int32)
    case failed(message: String)

    var isRunning: Bool {
        if case .running = self {
            return true
        }

        return false
    }

    var label: String {
        switch self {
        case .idle:
            "Idle"
        case .running(let task):
            "Running \(task.name)"
        case .completed(let exitCode):
            "Exited \(exitCode)"
        case .failed(let message):
            message
        }
    }
}

enum ProjectPanelMode: String, CaseIterable, Identifiable {
    case search
    case output

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .search:
            "Search"
        case .output:
            "Output"
        }
    }
}

struct ProjectFileChange {
    let oldURL: URL
    let newURL: URL
}

struct ProjectWorkspaceState: Codable {
    var rootPath: String
    var expandedDirectoryPaths: [String]
    var selectedFilePath: String?
    var openTabPaths: [String]
    var tasks: [RunTask]
}

struct ProjectAppSession: Codable {
    var openProjectPath: String?
    var recentProjects: [Project]
}
