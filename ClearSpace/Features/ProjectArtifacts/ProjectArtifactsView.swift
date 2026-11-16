import SwiftUI

struct ProjectArtifactsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let viewModel = appModel.projects

        Group {
            if viewModel.root == nil {
                ContentUnavailableView {
                    Label("Choose Your Projects Folder", systemImage: "hammer")
                } description: {
                    Text("ClearSpace finds dependency and build folders such as node_modules, Pods and build that their tools can recreate. Your source code is never touched.")
                } actions: {
                    Button("Choose Folder…") { chooseFolder(viewModel) }
                        .buttonStyle(.borderedProminent)
                }
            } else if viewModel.phase == .scanning {
                ScanProgressView(
                    title: "Scanning projects…",
                    message: "Looking for dependency and build folders in \(viewModel.root?.lastPathComponent ?? "your projects").",
                    onCancel: { viewModel.cancel() }
                )
            } else if viewModel.items.isEmpty {
                ContentUnavailableView {
                    Label(viewModel.phase == .idle ? "Ready to Scan" : "No Project Junk", systemImage: "checkmark.seal")
                } description: {
                    Text(viewModel.phase == .idle
                         ? "Scan \(viewModel.root?.lastPathComponent ?? "the folder") for dependency and build folders."
                         : "No dependency or build folders were found.")
                } actions: {
                    Button("Scan") { viewModel.scan() }
                }
            } else {
                List {
                    Section {
                        ForEach(viewModel.items) { item in
                            ArtifactRow(
                                item: item,
                                isSelected: Binding(
                                    get: { viewModel.isSelected(item) },
                                    set: { viewModel.setSelected($0, for: item) }
                                )
                            )
                            .contextMenu {
                                Button("Reveal in Finder") {
                                    SystemActions.revealInFinder([item.url])
                                }
                            }
                        }
                    } header: {
                        Text("These folders are recreated by their tools. The next build or install will take longer.")
                            .textCase(nil)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Project Junk")
        .navigationSubtitle(subtitle(viewModel))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    chooseFolder(viewModel)
                } label: {
                    Label(viewModel.root?.lastPathComponent ?? "Choose Folder", systemImage: "folder")
                        .labelStyle(.titleAndIcon)
                }
                .help("Choose the folder that holds your projects")

                Button(viewModel.allSelected ? "Deselect All" : "Select All") {
                    viewModel.toggleSelectAll()
                }
                .disabled(viewModel.items.isEmpty)

                Button {
                    viewModel.scan()
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .help("Scan again")
                .disabled(viewModel.root == nil || viewModel.phase == .scanning)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SelectionBar(count: viewModel.selection.count, size: viewModel.selectedSize) {
                appModel.requestDeletion(
                    title: "Clean Project Folders",
                    entries: viewModel.selectedItems.map(\.deletionEntry)
                ) { report in
                    viewModel.apply(report)
                }
            }
        }
    }

    private func subtitle(_ viewModel: ProjectArtifactsViewModel) -> String {
        guard viewModel.phase == .finished, !viewModel.items.isEmpty else { return "" }
        return "\(Pluralize.items(viewModel.items.count)), \(viewModel.totalSize.formattedBytes)"
    }

    private func chooseFolder(_ viewModel: ProjectArtifactsViewModel) {
        guard let url = SystemActions.chooseFolder(
            startingAt: viewModel.root,
            message: "Choose the folder that holds your projects."
        ) else { return }
        viewModel.setRoot(url)
    }
}

private struct ArtifactRow: View {
    let item: ArtifactItem
    @Binding var isSelected: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            Toggle(isOn: $isSelected) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .accessibilityLabel("Select \(item.project) \(item.kind.title)")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Theme.Spacing.small) {
                    Text(item.project)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text(item.kind.title)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .foregroundStyle(item.kind.tint)
                        .background(item.kind.tint.opacity(0.14), in: Capsule())
                        .help(item.kind.restoreHint)
                }
                Text(item.displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: Theme.Spacing.medium)

            Text(item.size.formattedBytes)
                .font(.body.weight(.medium))
                .monospacedDigit()
        }
        .padding(.vertical, Theme.Spacing.xSmall)
        .contentShape(Rectangle())
        .onTapGesture {
            isSelected.toggle()
        }
    }
}
