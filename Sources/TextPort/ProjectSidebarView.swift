import SwiftUI

struct ProjectSidebarView: View {
    @EnvironmentObject private var document: TextDocumentStore
    @EnvironmentObject private var project: ProjectStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if !project.hasProject {
                noProjectState
            } else if project.rootNodes.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(project.rootNodes) { node in
                        ProjectFileTreeRow(node: node, depth: 0)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 220)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)

            Text(project.currentProject?.displayName ?? "Project")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button {
                project.refreshFileTree()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .help("Refresh Project")
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(.bar)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No files")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noProjectState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "folder")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)

            Text("No Project Open")
                .font(.headline)

            Button {
                project.openProjectPanel()
                document.openFiles(at: project.consumeRestoredOpenTabURLs())
            } label: {
                Label("Open Project", systemImage: "folder.badge.plus")
            }
            .controlSize(.small)

            if !project.recentProjects.isEmpty {
                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(project.recentProjects.prefix(5)) { recentProject in
                        Button {
                            project.openProject(at: recentProject.rootURL)
                            document.openFiles(at: project.consumeRestoredOpenTabURLs())
                        } label: {
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundStyle(.secondary)
                                Text(recentProject.displayName)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

private struct ProjectFileTreeRow: View {
    @EnvironmentObject private var document: TextDocumentStore
    @EnvironmentObject private var project: ProjectStore

    let node: ProjectFileNode
    let depth: Int

    var body: some View {
        VStack(spacing: 0) {
            rowContent

            if node.isDirectory, project.isExpanded(node.url) {
                ForEach(node.children) { child in
                    ProjectFileTreeRow(node: child, depth: depth + 1)
                }
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 6) {
            if node.isDirectory {
                Button {
                    project.toggleExpanded(node.url)
                } label: {
                    Image(systemName: project.isExpanded(node.url) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 14, height: 18)
                }
                .buttonStyle(.plain)
                .help(project.isExpanded(node.url) ? "Collapse" : "Expand")
            } else {
                Color.clear.frame(width: 14, height: 18)
            }

            Image(systemName: node.isDirectory ? "folder" : iconName(for: node.name))
                .foregroundStyle(node.isDirectory ? .secondary : .tertiary)
                .frame(width: 16)

            Text(node.name)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            if let status = project.gitStatus(for: node.url) {
                Text(status)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            }
        }
        .font(.callout)
        .padding(.leading, CGFloat(depth * 14))
        .padding(.trailing, 8)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .background(selectionBackground)
        .onTapGesture {
            project.select(node.url)
            if node.isDirectory {
                project.toggleExpanded(node.url)
            } else {
                document.openFile(at: node.url)
            }
        }
        .contextMenu {
            Button("Open") {
                project.select(node.url)
                if node.isDirectory {
                    project.toggleExpanded(node.url)
                } else {
                    document.openFile(at: node.url)
                }
            }

            Divider()

            Button("New File") {
                project.select(node.url)
                if let url = project.createFile() {
                    document.openFile(at: url)
                }
            }

            Button("New Folder") {
                project.select(node.url)
                project.createFolder()
            }

            Divider()

            Button("Rename") {
                project.select(node.url)
                if let change = project.renameSelectedItem() {
                    document.replaceFileReference(from: change.oldURL, to: change.newURL)
                }
            }

            Button("Move to Trash") {
                project.select(node.url)
                if let trashedURL = project.moveSelectedItemToTrash() {
                    document.detachFileReferences(inside: trashedURL)
                }
            }
        }
    }

    private var selectionBackground: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(project.selectedFileURL == node.url ? Color.accentColor.opacity(0.12) : Color.clear)
    }

    private func iconName(for name: String) -> String {
        switch name.fileExtension.lowercased() {
        case "swift", "js", "ts", "tsx", "jsx", "py", "sh", "css", "html", "json":
            return "curlybraces"
        case "md", "markdown", "txt", "log":
            return "doc.text"
        default:
            return "doc"
        }
    }
}
