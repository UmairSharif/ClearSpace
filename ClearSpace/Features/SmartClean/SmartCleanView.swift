import SwiftUI

struct SmartCleanView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let viewModel = appModel.smartClean

        Group {
            if viewModel.phase == .idle {
                ContentUnavailableView {
                    Label("Find Reclaimable Space", systemImage: "sparkles")
                } description: {
                    Text("Smart Clean looks at caches, build products and other files that can be recreated.")
                } actions: {
                    Button("Scan") { Task { await viewModel.scan() } }
                        .buttonStyle(.borderedProminent)
                }
            } else if !viewModel.items.isEmpty {
                categoryList(viewModel)
            } else if viewModel.phase == .scanning {
                ScanProgressView(
                    title: "Analyzing your disk…",
                    message: "Measuring caches and build products. Large folders can take a minute.",
                    progress: viewModel.progress
                )
            } else {
                ContentUnavailableView(
                    "Nothing to Clean",
                    systemImage: "checkmark.seal",
                    description: Text("No reclaimable items were found.")
                )
            }
        }
        .navigationTitle("Smart Clean")
        .navigationSubtitle(subtitle(viewModel))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.selectAllSafe()
                } label: {
                    Label("Select Safe Items", systemImage: "checkmark.shield")
                }
                .help("Select everything that is rebuilt automatically")
                .disabled(viewModel.items.isEmpty)

                Button {
                    Task { await viewModel.scan() }
                } label: {
                    Label("Scan Again", systemImage: "arrow.clockwise")
                }
                .help("Analyze the disk again")
                .disabled(viewModel.phase == .scanning)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SmartCleanSelectionBar()
        }
    }

    private func subtitle(_ viewModel: SmartCleanViewModel) -> String {
        switch viewModel.phase {
        case .idle: ""
        case .scanning: "Scanning…"
        case .finished: "\(viewModel.reclaimableSize.formattedBytes) reclaimable"
        }
    }

    private func categoryList(_ viewModel: SmartCleanViewModel) -> some View {
        List {
            Section {
                ForEach(viewModel.categories) { category in
                    NavigationLink(value: Route.category(category)) {
                        CategoryRow(
                            category: category,
                            count: viewModel.items(in: category).count,
                            totalSize: viewModel.totalSize(in: category),
                            selectedSize: viewModel.selectedSize(in: category)
                        )
                    }
                }
            } footer: {
                Text("Choose a category to review its items. Nothing is removed until you confirm.")
            }
        }
        .listStyle(.inset)
    }
}

private struct CategoryRow: View {
    let category: CleanupCategory
    let count: Int
    let totalSize: Int64
    let selectedSize: Int64

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            IconTile(symbol: category.symbol, tint: category.tint, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(.headline)
                Text(category.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Theme.Spacing.medium)

            VStack(alignment: .trailing, spacing: 2) {
                Text(totalSize.formattedBytes)
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                Text(selectedSize > 0 ? "\(selectedSize.formattedBytes) selected" : Pluralize.items(count))
                    .font(.caption)
                    .foregroundStyle(selectedSize > 0 ? Color.accentColor : Color.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, Theme.Spacing.xSmall)
    }
}

/// Shared by the category list and the category detail so the selection total is always visible.
struct SmartCleanSelectionBar: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let viewModel = appModel.smartClean

        SelectionBar(count: viewModel.selection.count, size: viewModel.selectedSize) {
            appModel.requestDeletion(
                title: "Clean Selected Items",
                entries: viewModel.selectedItems.map(\.deletionEntry)
            ) { report in
                viewModel.apply(report)
            }
        }
    }
}
