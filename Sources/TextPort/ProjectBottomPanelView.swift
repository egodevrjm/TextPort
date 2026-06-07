import SwiftUI

struct ProjectBottomPanelView: View {
    @EnvironmentObject private var document: TextDocumentStore
    @EnvironmentObject private var project: ProjectStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            switch project.bottomPanelMode {
            case .search:
                searchPanel
            case .output:
                outputPanel
            }
        }
        .frame(minHeight: 170)
    }

    private var header: some View {
        HStack {
            Picker("Panel", selection: $project.bottomPanelMode) {
                ForEach(ProjectPanelMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            Spacer()

            Text(project.taskRunState.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button {
                project.isBottomPanelVisible = false
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .help("Close Panel")
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(.bar)
    }

    private var searchPanel: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Find in project", text: $project.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        project.performProjectSearch()
                    }

                Button {
                    project.performProjectSearch()
                } label: {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .keyboardShortcut(.return, modifiers: .command)
            }

            if project.searchResults.isEmpty {
                Spacer()
                Text(project.searchQuery.isEmpty ? "Enter a search term" : "No matches")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(project.searchResults) { result in
                    Button {
                        project.select(result.fileURL)
                        document.openFile(at: result.fileURL)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.relativePath)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Text(result.preview)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }

                            Spacer()

                            Text(":\(result.lineNumber)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
    }

    private var outputPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Task", selection: Binding(
                    get: { project.selectedTaskID },
                    set: { project.selectedTaskID = $0 }
                )) {
                    if project.tasks.isEmpty {
                        Text("No Tasks").tag(Optional<UUID>.none)
                    } else {
                        ForEach(project.tasks) { task in
                            Text(task.name).tag(Optional(task.id))
                        }
                    }
                }
                .frame(maxWidth: 240)

                Button {
                    project.runSelectedTask()
                } label: {
                    Image(systemName: "play.fill")
                        .frame(width: 22, height: 22)
                }
                .disabled(project.tasks.isEmpty || project.taskRunState.isRunning)
                .help("Run Task")

                Button {
                    project.stopTask()
                } label: {
                    Image(systemName: "stop.fill")
                        .frame(width: 22, height: 22)
                }
                .disabled(!project.taskRunState.isRunning)
                .help("Stop Task")

                Spacer()

                Button {
                    project.openTaskManager()
                } label: {
                    Label("Tasks", systemImage: "slider.horizontal.3")
                }
                .help("Manage Tasks")
            }

            ScrollView {
                Text(project.taskOutput.isEmpty ? "Task output appears here." : project.taskOutput)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(project.taskOutput.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .padding(10)
    }
}
