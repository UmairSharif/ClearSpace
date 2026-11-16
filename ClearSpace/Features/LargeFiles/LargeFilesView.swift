import SwiftUI

struct LargeFilesView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var viewModel = appModel.largeFiles

        Group {
            switch viewModel.phase {
            case .idle:
                ContentUnavailableView {
                    Label("Find Large Files", systemImage: "doc.badge.ellipsis")
                } description: {
                    Text("Scan \(viewModel.rootName) for files larger than \(viewModel.threshold.title).")
                } actions: {
                    Button("Scan") { viewModel.scan() }
                        .buttonStyle(.borderedProminent)
                }

            case .scanning:
                ScanProgressView(
                    title: "Looking for large files…",
                    message: "Scanning \(viewModel.rootName). This can take a few minutes for big folders.",
                    onCancel: { viewModel.cancel() }
                )

            case .finished:
                if viewModel.files.isEmpty {
                    ContentUnavailableView(
                        "No Large Files",
                        systemImage: "checkmark.seal",
                        description: Text("Nothing larger than \(viewModel.threshold.title) was found in \(viewModel.rootName).")
                    )
                } else {
                    fileTable(viewModel)
                }
            }
        }
        .navigationTitle("Large Files")
        .navigationSubtitle(subtitle(viewModel))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    chooseFolder(viewModel)
                } label: {
                    Label(viewModel.rootName, systemImage: "folder")
                        .labelStyle(.titleAndIcon)
                }
                .help("Choose the folder to scan")

                Picker("Minimum Size", selection: $viewModel.threshold) {
                    ForEach(LargeFilesViewModel.SizeThreshold.allCases) { threshold in
                        Text("Over \(threshold.title)").tag(threshold)
                    }
                }
                .help("Smallest file size to include")

                Toggle(isOn: $viewModel.includeLibrary) {
                    Label("Include Library", systemImage: "building.columns")
                }
                .help("Also scan the Library folder, where apps keep their data")

                Button {
                    viewModel.scan()
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .help("Scan again")
                .disabled(viewModel.phase == .scanning)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SelectionBar(
                count: viewModel.selection.count,
                size: viewModel.selectedSize,
                actionTitle: "Remove…"
            ) {
                appModel.requestDeletion(
                    title: "Remove Selected Files",
                    entries: viewModel.selectedFiles.map(\.deletionEntry)
                ) { report in
                    viewModel.apply(report)
                }
            }
        }
    }

    private func subtitle(_ viewModel: LargeFilesViewModel) -> String {
        guard viewModel.phase == .finished, !viewModel.files.isEmpty else { return "" }
        return "\(Pluralize.items(viewModel.files.count)), \(viewModel.totalSize.formattedBytes)"
    }

    private func chooseFolder(_ viewModel: LargeFilesViewModel) {
        guard let url = SystemActions.chooseFolder(
            startingAt: viewModel.root,
            message: "Choose a folder to scan for large files."
        ) else { return }
        viewModel.root = url
        viewModel.scan()
    }

    private func fileTable(_ model: LargeFilesViewModel) -> some View {
        @Bindable var viewModel = model

        return Table(viewModel.files, selection: $viewModel.selection, sortOrder: $viewModel.sortOrder) {
            TableColumn("Name", value: \.name) { file in
                FileNameCell(file: file)
            }
            .width(min: 180, ideal: 280)

            TableColumn("Size", value: \.size) { file in
                Text(file.size.formattedBytes)
                    .monospacedDigit()
            }
            .width(min: 70, ideal: 90, max: 120)

            TableColumn("Modified", value: \.modified) { file in
                Text(file.modified, format: .dateTime.day().month().year())
                    .foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: 110, max: 140)

            TableColumn("Location", value: \.location) { file in
                Text(file.location)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .help(file.location)
            }
        }
        .contextMenu(forSelectionType: FileEntry.ID.self) { ids in
            Button("Reveal in Finder") {
                SystemActions.revealInFinder(ids.map { URL(fileURLWithPath: $0) })
            }
            .disabled(ids.isEmpty)
        } primaryAction: { ids in
            SystemActions.revealInFinder(ids.map { URL(fileURLWithPath: $0) })
        }
        .onChange(of: viewModel.sortOrder) { _, _ in
            viewModel.sort()
        }
    }
}

private struct FileNameCell: View {
    let file: FileEntry

    var body: some View {
        HStack(spacing: Theme.Spacing.small) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                .resizable()
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            Text(file.name)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
