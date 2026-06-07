import AppKit
import Foundation

@MainActor
final class ProjectStore: ObservableObject {
    @Published var currentProject: Project?
    @Published var rootNodes: [ProjectFileNode] = []
    @Published var recentProjects: [Project]
    @Published var selectedFileURL: URL?
    @Published var expandedDirectoryPaths: Set<String> = []
    @Published var searchQuery = ""
    @Published var searchResults: [ProjectSearchResult] = []
    @Published var bottomPanelMode: ProjectPanelMode = .search
    @Published var isBottomPanelVisible = false
    @Published var tasks: [RunTask] = []
    @Published var selectedTaskID: UUID?
    @Published var taskRunState: TaskRunState = .idle
    @Published var taskOutput = ""
    @Published var isSidebarVisible = false
    @Published var showingTaskManager = false
    @Published var showingError = false
    @Published var errorMessage = ""

    private let taskRunner = TaskRunner()
    private var restoredOpenTabURLs: [URL] = []

    init() {
        let session = ProjectPersistenceStore.loadSession()
        recentProjects = session.recentProjects

        if let path = session.openProjectPath {
            let url = URL(fileURLWithPath: path)
            if Self.isDirectory(url) {
                openProject(at: url, saveSession: false)
            }
        }
    }

    var hasProject: Bool {
        currentProject != nil
    }

    var selectedTask: RunTask? {
        guard let selectedTaskID else {
            return tasks.first
        }

        return tasks.first { $0.id == selectedTaskID } ?? tasks.first
    }

    var selectedContainerURL: URL? {
        guard let currentProject else { return nil }
        guard let selectedFileURL else { return currentProject.rootURL }

        if Self.isDirectory(selectedFileURL) {
            return selectedFileURL
        }

        return selectedFileURL.deletingLastPathComponent()
    }

    func windowTitle(fileTitle: String) -> String {
        guard let currentProject else { return fileTitle }
        return "\(fileTitle) - \(currentProject.displayName)"
    }

    func openProjectPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open Project"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openProject(at: url)
    }

    func openProject(at url: URL, saveSession: Bool = true) {
        let rootURL = url.standardizedFileURL
        guard Self.isDirectory(rootURL) else {
            present(message: "\(url.lastPathComponent) is not a folder.")
            return
        }

        persistCurrentState()

        let savedState = ProjectPersistenceStore.loadState(for: rootURL)
        let project = Project(
            rootURL: rootURL,
            displayName: rootURL.lastPathComponent,
            lastOpened: Date()
        )

        currentProject = project
        expandedDirectoryPaths = Set(savedState?.expandedDirectoryPaths ?? [])
        selectedFileURL = savedState?.selectedFilePath.map { URL(fileURLWithPath: $0) }
        tasks = savedState?.tasks ?? defaultTasks(for: rootURL)
        selectedTaskID = tasks.first?.id
        searchResults = []
        searchQuery = ""
        taskOutput = ""
        taskRunState = .idle
        restoredOpenTabURLs = (savedState?.openTabPaths ?? []).map { URL(fileURLWithPath: $0) }

        refreshFileTree()
        addRecentProject(project)

        if saveSession {
            persistSession()
            persistCurrentState()
        }
    }

    func closeProject(openTabs: [TextDocumentTab]) {
        persistOpenTabs(openTabs)
        stopTask()

        currentProject = nil
        rootNodes = []
        selectedFileURL = nil
        expandedDirectoryPaths = []
        searchResults = []
        searchQuery = ""
        isBottomPanelVisible = false
        taskOutput = ""
        taskRunState = .idle
        tasks = []
        selectedTaskID = nil
        restoredOpenTabURLs = []
        persistSession()
    }

    func refreshFileTree() {
        guard let currentProject else {
            rootNodes = []
            return
        }

        rootNodes = ProjectFileScanner.scan(rootURL: currentProject.rootURL)
    }

    func consumeRestoredOpenTabURLs() -> [URL] {
        let urls = restoredOpenTabURLs
        restoredOpenTabURLs = []
        return urls
    }

    func persistOpenTabs(_ tabs: [TextDocumentTab]) {
        guard currentProject != nil else { return }
        let openTabPaths = tabs
            .compactMap(\.fileURL)
            .filter { isInsideProject($0) }
            .map(\.standardizedFileURL.path)

        saveState(openTabPaths: openTabPaths)
    }

    func persistCurrentState() {
        guard currentProject != nil else { return }
        saveState(openTabPaths: nil)
    }

    func select(_ url: URL) {
        selectedFileURL = url
        persistCurrentState()
    }

    func isExpanded(_ url: URL) -> Bool {
        expandedDirectoryPaths.contains(url.standardizedFileURL.path)
    }

    func toggleExpanded(_ url: URL) {
        let path = url.standardizedFileURL.path
        if expandedDirectoryPaths.contains(path) {
            expandedDirectoryPaths.remove(path)
        } else {
            expandedDirectoryPaths.insert(path)
        }
        persistCurrentState()
    }

    func showFindInProject() {
        bottomPanelMode = .search
        isBottomPanelVisible = true
    }

    func performProjectSearch() {
        guard let currentProject else { return }
        bottomPanelMode = .search
        isBottomPanelVisible = true
        searchResults = ProjectSearchService.search(query: searchQuery, in: currentProject.rootURL)
    }

    func showTaskOutput() {
        bottomPanelMode = .output
        isBottomPanelVisible = true
    }

    func toggleSidebar() {
        isSidebarVisible.toggle()
    }

    func openTaskManager() {
        showingTaskManager = true
    }

    func addTask() {
        let task = RunTask(name: "New Task", command: "")
        tasks.append(task)
        selectedTaskID = task.id
        persistCurrentState()
    }

    func removeSelectedTask() {
        guard let selectedTaskID else { return }
        tasks.removeAll { $0.id == selectedTaskID }
        self.selectedTaskID = tasks.first?.id
        persistCurrentState()
    }

    func updateTask(_ task: RunTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        persistCurrentState()
    }

    func runSelectedTask() {
        guard let currentProject else { return }
        guard let task = selectedTask else {
            openTaskManager()
            return
        }

        runTask(task, in: currentProject.rootURL)
    }

    func runTask(_ task: RunTask) {
        guard let currentProject else { return }
        runTask(task, in: currentProject.rootURL)
    }

    func stopTask() {
        guard taskRunState.isRunning else { return }
        taskRunner.stop()
        appendTaskOutput("\nStopped.\n")
    }

    func createFile() -> URL? {
        guard let containerURL = selectedContainerURL else { return nil }
        let panel = NSSavePanel()
        panel.title = "New File"
        panel.directoryURL = containerURL
        panel.nameFieldStringValue = "Untitled.txt"
        panel.canCreateDirectories = true
        panel.allowsOtherFileTypes = true

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard !FileManager.default.fileExists(atPath: url.path) else {
            present(message: "A file named \(url.lastPathComponent) already exists.")
            return nil
        }

        do {
            try Data().write(to: url, options: .atomic)
            refreshFileTree()
            selectedFileURL = url
            persistCurrentState()
            return url
        } catch {
            present(error, action: "create file")
            return nil
        }
    }

    func createFolder() {
        guard let containerURL = selectedContainerURL else { return }
        guard let name = promptForName(title: "New Folder", defaultValue: "New Folder") else { return }
        let folderURL = containerURL.appendingPathComponent(name, isDirectory: true)

        guard !FileManager.default.fileExists(atPath: folderURL.path) else {
            present(message: "A folder named \(name) already exists.")
            return
        }

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
            refreshFileTree()
            selectedFileURL = folderURL
            expandedDirectoryPaths.insert(containerURL.standardizedFileURL.path)
            persistCurrentState()
        } catch {
            present(error, action: "create folder")
        }
    }

    func renameSelectedItem() -> ProjectFileChange? {
        guard let selectedFileURL else { return nil }
        guard let newName = promptForName(title: "Rename", defaultValue: selectedFileURL.lastPathComponent) else { return nil }
        let newURL = selectedFileURL.deletingLastPathComponent().appendingPathComponent(newName)

        guard selectedFileURL != newURL else { return nil }
        guard !FileManager.default.fileExists(atPath: newURL.path) else {
            present(message: "An item named \(newName) already exists.")
            return nil
        }

        do {
            try FileManager.default.moveItem(at: selectedFileURL, to: newURL)
            self.selectedFileURL = newURL
            refreshFileTree()
            persistCurrentState()
            return ProjectFileChange(oldURL: selectedFileURL, newURL: newURL)
        } catch {
            present(error, action: "rename")
            return nil
        }
    }

    func moveSelectedItemToTrash() -> URL? {
        guard let selectedFileURL else { return nil }

        do {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: selectedFileURL, resultingItemURL: &resultingURL)
            self.selectedFileURL = nil
            refreshFileTree()
            persistCurrentState()
            return selectedFileURL
        } catch {
            present(error, action: "move to Trash")
            return nil
        }
    }

    func quickOpenItems(matching rawQuery: String) -> [QuickOpenItem] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let files = flattenedFiles()

        let matches = query.isEmpty
            ? files
            : files.filter { node in
                node.name.lowercased().contains(query) || node.relativePath.lowercased().contains(query)
            }

        return matches.prefix(40).map { node in
            QuickOpenItem(
                title: node.name,
                subtitle: node.relativePath,
                kind: .projectFile(node.url)
            )
        }
    }

    func isInsideProject(_ url: URL) -> Bool {
        guard let currentProject else { return false }
        let rootPath = currentProject.rootURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path == rootPath || path.hasPrefix(rootPath + "/")
    }

    private func runTask(_ task: RunTask, in projectRootURL: URL) {
        guard !task.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            present(message: "This task needs a command before it can run.")
            return
        }

        selectedTaskID = task.id
        bottomPanelMode = .output
        isBottomPanelVisible = true
        taskOutput = "$ \(task.command)\n"
        taskRunState = .running(task)

        taskRunner.run(
            task: task,
            projectRootURL: projectRootURL,
            output: { [weak self] text in
                self?.appendTaskOutput(text)
            },
            completion: { [weak self] exitCode in
                self?.taskRunState = .completed(exitCode: exitCode)
                self?.appendTaskOutput("\nExited with code \(exitCode).\n")
            },
            failure: { [weak self] message in
                self?.taskRunState = .failed(message: message)
                self?.appendTaskOutput("\n\(message)\n")
            }
        )
    }

    private func appendTaskOutput(_ text: String) {
        taskOutput += text
    }

    private func flattenedFiles() -> [ProjectFileNode] {
        func flatten(_ nodes: [ProjectFileNode]) -> [ProjectFileNode] {
            nodes.flatMap { node -> [ProjectFileNode] in
                node.isDirectory ? flatten(node.children) : [node]
            }
        }

        return flatten(rootNodes)
    }

    private func defaultTasks(for rootURL: URL) -> [RunTask] {
        if FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("Package.swift").path) {
            return [RunTask(name: "Swift Build", command: "swift build")]
        }

        if FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("package.json").path) {
            return [RunTask(name: "npm Test", command: "npm test")]
        }

        return []
    }

    private func addRecentProject(_ project: Project) {
        recentProjects.removeAll { $0.rootURL == project.rootURL }
        recentProjects.insert(project, at: 0)
        recentProjects = Array(recentProjects.prefix(12))
        persistSession()
    }

    private func persistSession() {
        ProjectPersistenceStore.saveSession(ProjectAppSession(
            openProjectPath: currentProject?.rootURL.standardizedFileURL.path,
            recentProjects: recentProjects
        ))
    }

    private func saveState(openTabPaths: [String]?) {
        guard let currentProject else { return }
        let existingOpenTabs = ProjectPersistenceStore.loadState(for: currentProject.rootURL)?.openTabPaths ?? []
        let selectedPath = selectedFileURL?.standardizedFileURL.path
        let state = ProjectWorkspaceState(
            rootPath: currentProject.rootURL.standardizedFileURL.path,
            expandedDirectoryPaths: Array(expandedDirectoryPaths).sorted(),
            selectedFilePath: selectedPath,
            openTabPaths: openTabPaths ?? existingOpenTabs,
            tasks: tasks
        )
        ProjectPersistenceStore.saveState(state, for: currentProject.rootURL)
    }

    private func promptForName(title: String, defaultValue: String) -> String? {
        let textField = NSTextField(string: defaultValue)
        textField.frame = NSRect(x: 0, y: 0, width: 280, height: 24)

        let alert = NSAlert()
        alert.messageText = title
        alert.accessoryView = textField
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        let name = textField.stringValue.trimmedFileName
        guard !name.isEmpty else {
            present(message: "Names cannot be empty.")
            return nil
        }

        guard name.isValidFileName else {
            present(message: "Names cannot contain / or : characters.")
            return nil
        }

        return name
    }

    private func present(_ error: Error, action: String) {
        present(message: "TextPort could not \(action) this project item. \(error.localizedDescription)")
    }

    private func present(message: String) {
        errorMessage = message
        showingError = true
    }

    static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}
