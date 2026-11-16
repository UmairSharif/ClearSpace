import SwiftUI

struct CategoryDetailView: View {
    @Environment(AppModel.self) private var appModel
    let category: CleanupCategory

    var body: some View {
        let viewModel = appModel.smartClean
        let items = viewModel.items(in: category)

        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "Nothing Left Here",
                    systemImage: "checkmark.seal",
                    description: Text("This category has no reclaimable items.")
                )
            } else {
                List {
                    Section {
                        ForEach(items) { item in
                            CleanupItemRow(
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
                                Button("Copy Path") {
                                    SystemActions.copyToPasteboard(item.url.path)
                                }
                            }
                        }
                    } header: {
                        Text(category.summary)
                            .textCase(nil)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(category.title)
        .navigationSubtitle(viewModel.totalSize(in: category).formattedBytes)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Select All") {
                    viewModel.selectAll(in: category)
                }
                .disabled(items.allSatisfy { !$0.isSelectable })

                Button("Deselect All") {
                    viewModel.deselectAll(in: category)
                }
                .disabled(viewModel.selectedSize(in: category) == 0)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SmartCleanSelectionBar()
        }
    }
}

private struct CleanupItemRow: View {
    let item: CleanupItem
    @Binding var isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.medium) {
            if item.isSelectable {
                Toggle(isOn: $isSelected) {
                    EmptyView()
                }
                .toggleStyle(.checkbox)
                .labelsHidden()
                .accessibilityLabel("Select \(item.title)")
            } else {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Theme.Spacing.small) {
                    Text(item.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    SafetyBadge(level: item.safety)
                }

                Text(item.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let hint = item.hint {
                    HStack(spacing: 6) {
                        Text(hint)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                        Button {
                            SystemActions.copyToPasteboard(hint)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy command")
                        .accessibilityLabel("Copy command")
                    }
                }

                Text(item.displayPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
            if item.isSelectable {
                isSelected.toggle()
            }
        }
    }
}
