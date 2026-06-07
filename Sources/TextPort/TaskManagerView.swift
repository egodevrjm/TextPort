import SwiftUI

struct TaskManagerView: View {
    @EnvironmentObject private var project: ProjectStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                taskList
                Divider()
                taskEditor
            }
            .frame(minHeight: 280)

            HStack {
                Button {
                    project.addTask()
                } label: {
                    Label("Add", systemImage: "plus")
                }

                Button {
                    project.removeSelectedTask()
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .disabled(project.selectedTaskID == nil)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 620)
    }

    private var taskList: some View {
        List(selection: $project.selectedTaskID) {
            ForEach(project.tasks) { task in
                Text(task.name.isEmpty ? "Untitled Task" : task.name)
                    .tag(Optional(task.id))
            }
        }
        .frame(width: 190)
    }

    @ViewBuilder
    private var taskEditor: some View {
        if let binding = selectedTaskBinding {
            Form {
                TextField("Name", text: binding.name)
                TextField("Command", text: binding.command, axis: .vertical)
                    .lineLimit(3...5)
                TextField("Working Directory", text: binding.workingDirectory)

                Text("Working directory is relative to the project root. Use . for the root.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
        } else {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "play.square")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
                Text("Add a task")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var selectedTaskBinding: Binding<RunTask>? {
        guard let selectedTaskID = project.selectedTaskID else { return nil }

        return Binding(
            get: {
                project.tasks.first(where: { $0.id == selectedTaskID }) ?? RunTask(name: "", command: "")
            },
            set: { updatedTask in
                project.updateTask(updatedTask)
            }
        )
    }
}

private extension Binding where Value == RunTask {
    var name: Binding<String> {
        Binding<String>(
            get: { wrappedValue.name },
            set: { wrappedValue.name = $0 }
        )
    }

    var command: Binding<String> {
        Binding<String>(
            get: { wrappedValue.command },
            set: { wrappedValue.command = $0 }
        )
    }

    var workingDirectory: Binding<String> {
        Binding<String>(
            get: { wrappedValue.workingDirectory },
            set: { wrappedValue.workingDirectory = $0 }
        )
    }
}
